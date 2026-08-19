import FeedUI
import Observability
import SecretDJAPI
import SecretDJDomain
import Testing

@testable import SecretDJ

/// ``ExtraContentModel`` — the extra-content ticker's state (PLAN.md S6.9):
/// per-screen fetch, ten-second rotation on an injected clock (never a real
/// timer here), pause-on-hide, and tap-route derivation. Mirrors
/// `secretdjv3/ExtraContentManager.swift`'s behavior — see doc comments on
/// individual tests for the specific legacy method each one pins.
@MainActor
enum ExtraContentModelTests {
	struct Fetching {
		@Test func `fetches with no venue id on the Places Nearby screen`() async {
			let loading = InMemoryExtraContentLoading()
			let model = makeModel(screen: .placesNearby, hostVenueId: nil, loading: loading)

			await model.fetch()

			#expect(loading.calls == [.init(venueId: nil, screen: .placesNearby)])
		}

		@Test func `fetches with the host venue id on the venue screen`() async {
			let loading = InMemoryExtraContentLoading()
			let model = makeModel(screen: .venueDetails, hostVenueId: "v1", loading: loading)

			await model.fetch()

			#expect(loading.calls == [.init(venueId: "v1", screen: .venueDetails)])
		}

		@Test func `maps song and person items into entries, dropping every other kind`() async {
			let loading = InMemoryExtraContentLoading(result: .success([
				.song(makeSong(songId: "1", text: "A")),
				.person(makePerson(personId: "2", text: "A\nB\nC")),
				.unsupported(.checkIn),
			]))
			let model = makeModel(loading: loading)

			await model.fetch()

			#expect(model.entries.map(\.id) == ["song-1", "person-2"])
		}

		@Test func `starts with no current entry`() {
			let model = makeModel()

			#expect(model.currentEntry == nil)
		}

		@Test func `an empty response leaves entries empty and currentEntry nil`() async {
			let model = makeModel(loading: InMemoryExtraContentLoading(result: .success([])))

			await model.fetch()

			#expect(model.entries.isEmpty)
			#expect(model.currentEntry == nil)
		}

		/// Legacy's `bounceInContainer()`: the first content the ticker ever
		/// shows bounces into view unconditionally.
		@Test func `the first successful non-empty fetch makes the ticker visible`() async {
			let model = makeModel(loading: InMemoryExtraContentLoading(result: .success([.song(makeSong(text: "A"))])))

			await model.fetch()

			#expect(model.isVisible)
		}

		@Test func `a later fetch does not force the ticker visible again once it's been hidden`() async {
			let loading = InMemoryExtraContentLoading(result: .success([.song(makeSong(text: "A"))]))
			let model = makeModel(loading: loading)
			await model.fetch()
			model.handleScrollDirectionChange(.towardEnd)

			await model.fetch()

			#expect(!model.isVisible)
		}

		/// Legacy's `FeedInteractor.fetchExtraContent` has no failure branch
		/// at all — a failed fetch simply never calls
		/// `viewController.show(extraContent:)`, leaving whatever was already
		/// on screen. This rewrite reports the error for diagnostics but
		/// otherwise matches: it never surfaces to the UI.
		@Test func `a fetch failure is swallowed silently and leaves prior entries untouched`() async {
			let loading = InMemoryExtraContentLoading(result: .success([.song(makeSong(text: "A"))]))
			let model = makeModel(loading: loading)
			await model.fetch()
			loading.result = .failure(FakeExtraContentLoadingError())

			await model.fetch()

			#expect(model.entries.map(\.id) == ["song-1"])
		}

		@Test func `a fetch failure with no prior entries leaves entries empty`() async {
			let model =
				makeModel(loading: InMemoryExtraContentLoading(result: .failure(FakeExtraContentLoadingError())))

			await model.fetch()

			#expect(model.entries.isEmpty)
			#expect(!model.isVisible)
		}
	}

	struct `Scroll direction` {
		@Test func `towardStart makes the ticker visible`() {
			let model = makeModel()

			model.handleScrollDirectionChange(.towardStart)

			#expect(model.isVisible)
		}

		@Test func `towardEnd hides the ticker`() {
			let model = makeModel()
			model.handleScrollDirectionChange(.towardStart)

			model.handleScrollDirectionChange(.towardEnd)

			#expect(!model.isVisible)
		}
	}

	struct Rotation {
		@Test func `becoming visible with entries schedules a ten-second rotation`() async {
			let clock = ManualExtraContentClock()
			let model = makeModel(
				loading: InMemoryExtraContentLoading(result: .success([.song(makeSong(text: "A"))])),
				clock: clock,
			)

			await model.fetch()

			#expect(clock.pendingCount == 1)
			#expect(clock.scheduledDurations.last == .seconds(10))
		}

		@Test func `advancing the clock moves to the next entry`() async {
			let clock = ManualExtraContentClock()
			let model = makeModel(
				loading: InMemoryExtraContentLoading(result: .success([
					.song(makeSong(songId: "1", text: "A")),
					.song(makeSong(songId: "2", text: "B")),
				])),
				clock: clock,
			)
			await model.fetch()

			clock.advance()

			#expect(model.currentIndex == 1)
			#expect(model.currentEntry?.id == "song-2")
		}

		@Test func `wraps back to the first entry past the last`() async {
			let clock = ManualExtraContentClock()
			let model = makeModel(
				loading: InMemoryExtraContentLoading(result: .success([
					.song(makeSong(songId: "1", text: "A")),
					.song(makeSong(songId: "2", text: "B")),
				])),
				clock: clock,
			)
			await model.fetch()
			clock.advance()

			clock.advance()

			#expect(model.currentIndex == 0)
		}

		@Test func `advancing reschedules another rotation while still visible`() async {
			let clock = ManualExtraContentClock()
			let model = makeModel(
				loading: InMemoryExtraContentLoading(result: .success([
					.song(makeSong(songId: "1", text: "A")),
					.song(makeSong(songId: "2", text: "B")),
				])),
				clock: clock,
			)
			await model.fetch()

			clock.advance()

			#expect(clock.pendingCount == 1)
		}

		@Test func `hiding the ticker cancels the pending rotation`() async {
			let clock = ManualExtraContentClock()
			let model = makeModel(
				loading: InMemoryExtraContentLoading(result: .success([.song(makeSong(text: "A"))])),
				clock: clock,
			)
			await model.fetch()

			model.handleScrollDirectionChange(.towardEnd)

			#expect(clock.pendingCount == 0)
		}

		@Test func `showing the ticker again reschedules rotation`() async {
			let clock = ManualExtraContentClock()
			let model = makeModel(
				loading: InMemoryExtraContentLoading(result: .success([.song(makeSong(text: "A"))])),
				clock: clock,
			)
			await model.fetch()
			model.handleScrollDirectionChange(.towardEnd)

			model.handleScrollDirectionChange(.towardStart)

			#expect(clock.pendingCount == 1)
		}

		@Test func `no rotation is scheduled while there are no entries`() async {
			let clock = ManualExtraContentClock()
			let model = makeModel(loading: InMemoryExtraContentLoading(result: .success([])), clock: clock)

			await model.fetch()
			model.handleScrollDirectionChange(.towardStart)

			#expect(clock.pendingCount == 0)
		}

		@Test func `stop cancels any pending rotation`() async {
			let clock = ManualExtraContentClock()
			let model = makeModel(
				loading: InMemoryExtraContentLoading(result: .success([.song(makeSong(text: "A"))])),
				clock: clock,
			)
			await model.fetch()

			model.stop()

			#expect(clock.pendingCount == 0)
		}
	}

	struct Tapping {
		@Test func `returns nil when there is no current entry`() {
			let model = makeModel()

			#expect(model.tapCurrentEntry() == nil)
		}

		@Test func `returns nowPlaying for a song entry when the host has a venue`() async {
			let model = makeModel(
				hostVenueId: "v1",
				loading: InMemoryExtraContentLoading(result: .success([.song(makeSong(text: "A"))])),
			)
			await model.fetch()

			#expect(model.tapCurrentEntry() == .nowPlaying(venueId: "v1"))
		}

		@Test func `returns nil for a song entry when the host has no venue`() async {
			let model = makeModel(
				hostVenueId: nil,
				loading: InMemoryExtraContentLoading(result: .success([.song(makeSong(text: "A"))])),
			)
			await model.fetch()

			#expect(model.tapCurrentEntry() == nil)
		}

		@Test func `returns activity for a person entry`() async {
			let model = makeModel(
				loading: InMemoryExtraContentLoading(result: .success([.person(makePerson(text: "A\nB\nC"))])),
			)
			await model.fetch()

			#expect(model.tapCurrentEntry() == .activity)
		}
	}

	struct Instrumentation {
		@Test func `breadcrumbs the tap interaction`() async {
			let recorder = RecordingDestination()
			let model = makeModel(
				loading: InMemoryExtraContentLoading(result: .success([.person(makePerson(text: "A\nB\nC"))])),
				observability: ObservabilityPipeline(destinations: [recorder]),
			)
			await model.fetch()

			_ = model.tapCurrentEntry()

			#expect(recorder.breadcrumbs.contains(.interaction(description: "tapExtraContent")))
		}

		@Test func `reports a fetch failure`() async {
			let recorder = RecordingDestination()
			let model = makeModel(
				loading: InMemoryExtraContentLoading(result: .failure(FakeExtraContentLoadingError())),
				observability: ObservabilityPipeline(destinations: [recorder]),
			)

			await model.fetch()

			let diagnostics = recorder.events.compactMap { event -> Diagnostic? in
				guard case .diagnostic(let diagnostic) = event else { return nil }
				return diagnostic
			}
			#expect(diagnostics.contains { $0.category == "ExtraContent" && $0.level == .error })
		}
	}
}

// MARK: - Fixtures

@MainActor
private func makeModel(
	screen: ExtraContentScreen = .placesNearby,
	hostVenueId: String? = nil,
	loading: any ExtraContentLoading = InMemoryExtraContentLoading(),
	clock: any ExtraContentClock = ManualExtraContentClock(),
	observability: ObservabilityPipeline = .disabled,
) -> ExtraContentModel {
	ExtraContentModel(
		screen: screen,
		hostVenueId: hostVenueId,
		loading: loading,
		clock: clock,
		observability: observability,
	)
}

private func makeSong(songId: String = "1", text: String) -> Song {
	Song(
		songId: songId,
		title: "",
		artist: "",
		previewURL: nil,
		likeInfo: LikeInfo(likedByYou: false, info: ""),
		text: text,
		sortIndex: 0,
		action: nil,
		actions: [],
	)
}

private func makePerson(personId: String = "1", text: String) -> Person {
	Person(
		personId: personId,
		screenName: "dj",
		gender: .unisex,
		likeInfo: LikeInfo(likedByYou: false, info: ""),
		email: nil,
		firstName: nil,
		lastName: nil,
		text: text,
		sortIndex: 0,
		action: nil,
		actions: [],
	)
}
