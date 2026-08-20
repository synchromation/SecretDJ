import Testing

@testable import FeedUI

import Foundation
import Observability
import SecretDJDomain

/// Unattended error recovery (PLAN.md S7.7) — `FeedConfiguration/errorRecovery`'s
/// opt-in backoff retry over an errored ``FeedScreenModel``. Split out of
/// `FeedScreenModelTests` to keep that file under the project's file-length
/// limit; both files share the fixtures there (`makeScreenModel`,
/// `makeLoadedSectionList`, ...).
enum FeedScreenModelRecoveryTests {
	@MainActor
	struct `Arming and disarming` {
		@Test func `no recovery policy schedules no retry after an error`() async {
			let model = makeScreenModel(loader: InMemoryFeedLoading(), errorRecovery: nil)

			await model.start()

			#expect(model.phase == .error(offline: false))
		}

		@Test func `a recovery policy schedules the first retry at the initial interval`() async {
			let clock = ManualFeedRefreshClock()
			let model = makeScreenModel(
				loader: InMemoryFeedLoading(),
				errorRecovery: FeedConfiguration.ErrorRecovery(
					initialInterval: .seconds(5),
					maximumInterval: .seconds(300),
				),
				clock: clock,
			)

			await model.start()

			#expect(clock.scheduledDurations == [.seconds(5)])
		}

		@Test func `a successful load schedules no retry`() async {
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(
				.success(makeLoadedSectionList(hash: "v1", items: [makeFeedSong()])),
				forPage: nil,
			)
			let clock = ManualFeedRefreshClock()
			let model = makeScreenModel(
				loader: loader,
				errorRecovery: FeedConfiguration.ErrorRecovery(),
				clock: clock,
			)

			await model.start()

			#expect(clock.pendingCount == 0)
		}

		@Test func `stop cancels a pending recovery retry`() async {
			let clock = ManualFeedRefreshClock()
			let model = makeScreenModel(
				loader: InMemoryFeedLoading(),
				errorRecovery: FeedConfiguration.ErrorRecovery(),
				clock: clock,
			)
			await model.start()

			model.stop()

			#expect(clock.pendingCount == 0)
		}

		@Test func `a background refresh failing while content is already showing does not arm recovery`() async {
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(
				.success(makeLoadedSectionList(hash: "v1", items: [makeFeedSong()])),
				forPage: nil,
			)
			let clock = ManualFeedRefreshClock()
			let model = makeScreenModel(loader: loader, errorRecovery: FeedConfiguration.ErrorRecovery(), clock: clock)
			await model.start()

			await loader.setOutcome(.failure(URLError(.notConnectedToInternet)), forPage: nil)
			await model.refresh()

			#expect(model.phase == .loaded)
			#expect(clock.pendingCount == 0)
		}
	}

	@MainActor
	struct Retrying {
		@Test func `advancing the clock retries the load and heals once it succeeds`() async {
			let loader = InMemoryFeedLoading()
			let clock = ManualFeedRefreshClock()
			let model = makeScreenModel(loader: loader, errorRecovery: FeedConfiguration.ErrorRecovery(), clock: clock)
			await model.start()

			await loader.setOutcome(
				.success(makeLoadedSectionList(hash: "v1", items: [makeFeedSong(songId: "1")])),
				forPage: nil,
			)
			await clock.advance()

			#expect(model.phase == .loaded)
			#expect(model.visibleSections[0].items.map(\.id) == ["song-1"])
		}

		@Test func `each further failure backs off to double the previous wait`() async {
			let loader = InMemoryFeedLoading()
			let clock = ManualFeedRefreshClock()
			let model = makeScreenModel(
				loader: loader,
				errorRecovery: FeedConfiguration.ErrorRecovery(
					initialInterval: .seconds(5),
					maximumInterval: .seconds(300),
				),
				clock: clock,
			)
			await model.start()
			#expect(clock.scheduledDurations == [.seconds(5)])

			await clock.advance()
			#expect(clock.scheduledDurations == [.seconds(5), .seconds(10)])

			await clock.advance()
			#expect(clock.scheduledDurations == [.seconds(5), .seconds(10), .seconds(20)])
		}

		@Test func `backoff holds at the maximum interval instead of growing without bound`() async {
			let loader = InMemoryFeedLoading()
			let clock = ManualFeedRefreshClock()
			let model = makeScreenModel(
				loader: loader,
				errorRecovery: FeedConfiguration.ErrorRecovery(
					initialInterval: .seconds(5),
					maximumInterval: .seconds(20),
				),
				clock: clock,
			)
			await model.start()

			await clock.advance() // attempt 2: 10s
			await clock.advance() // attempt 3: 20s (capped)
			await clock.advance() // attempt 4: still capped at 20s

			#expect(clock.scheduledDurations.suffix(2) == [.seconds(20), .seconds(20)])
		}

		@Test func `a retry that fails again re-arms the next wait rather than giving up`() async {
			let loader = InMemoryFeedLoading()
			let clock = ManualFeedRefreshClock()
			let model = makeScreenModel(loader: loader, errorRecovery: FeedConfiguration.ErrorRecovery(), clock: clock)
			await model.start()

			await clock.advance()
			await clock.advance()

			#expect(model.phase == .error(offline: false))
			#expect(clock.pendingCount == 1)
		}
	}

	@MainActor
	struct Instrumentation {
		@Test func `the first retry leaves a coarse breadcrumb`() async {
			let recorder = RecordingDestination()
			let loader = InMemoryFeedLoading()
			let clock = ManualFeedRefreshClock()
			let model = makeScreenModel(
				loader: loader,
				errorRecovery: FeedConfiguration.ErrorRecovery(),
				clock: clock,
				observability: ObservabilityPipeline(destinations: [recorder]),
			)
			await model.start()

			await clock.advance()

			#expect(recorder.breadcrumbs.contains(.interaction(description: "feedErrorRecoveryRetry")))
		}

		@Test func `intermediate retries between the coarse stride stay silent`() async {
			let recorder = RecordingDestination()
			let loader = InMemoryFeedLoading()
			let clock = ManualFeedRefreshClock()
			let model = makeScreenModel(
				loader: loader,
				errorRecovery: FeedConfiguration.ErrorRecovery(),
				clock: clock,
				observability: ObservabilityPipeline(destinations: [recorder]),
			)
			await model.start() // schedules attempt 1
			await clock.advance() // fires attempt 1 (breadcrumbed) and schedules attempt 2
			await clock.advance() // fires attempt 2 — not a stride multiple, no breadcrumb
			await clock.advance() // fires attempt 3 — not a stride multiple, no breadcrumb

			let retryBreadcrumbs = recorder.breadcrumbs
				.filter { $0 == .interaction(description: "feedErrorRecoveryRetry") }
			#expect(retryBreadcrumbs.count == 1)
		}

		@Test func `a successful recovery leaves a recovered breadcrumb exactly once`() async {
			let recorder = RecordingDestination()
			let loader = InMemoryFeedLoading()
			let clock = ManualFeedRefreshClock()
			let model = makeScreenModel(
				loader: loader,
				errorRecovery: FeedConfiguration.ErrorRecovery(),
				clock: clock,
				observability: ObservabilityPipeline(destinations: [recorder]),
			)
			await model.start()

			await loader.setOutcome(
				.success(makeLoadedSectionList(hash: "v1", items: [makeFeedSong()])),
				forPage: nil,
			)
			await clock.advance()

			#expect(recorder.breadcrumbs
				.count(where: { $0 == .interaction(description: "feedErrorRecoveryRecovered") }) == 1)
		}

		@Test func `a load that never failed stays silent about recovery`() async {
			let recorder = RecordingDestination()
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(
				.success(makeLoadedSectionList(hash: "v1", items: [makeFeedSong()])),
				forPage: nil,
			)
			let model = makeScreenModel(
				loader: loader,
				errorRecovery: FeedConfiguration.ErrorRecovery(),
				observability: ObservabilityPipeline(destinations: [recorder]),
			)

			await model.start()

			#expect(recorder.breadcrumbs.isEmpty)
		}
	}

	struct `Backoff math` {
		@Test func `the first attempt waits the initial interval`() {
			let interval = FeedScreenModel.recoveryInterval(forAttempt: 1, initial: .seconds(5), maximum: .seconds(300))

			#expect(interval == .seconds(5))
		}

		@Test func `each further attempt doubles the previous wait`() {
			#expect(FeedScreenModel
				.recoveryInterval(forAttempt: 2, initial: .seconds(5), maximum: .seconds(300)) == .seconds(10))
			#expect(FeedScreenModel
				.recoveryInterval(forAttempt: 3, initial: .seconds(5), maximum: .seconds(300)) == .seconds(20))
			#expect(FeedScreenModel
				.recoveryInterval(forAttempt: 4, initial: .seconds(5), maximum: .seconds(300)) == .seconds(40))
		}

		@Test func `growth holds at the maximum once reached`() {
			#expect(FeedScreenModel
				.recoveryInterval(forAttempt: 7, initial: .seconds(5), maximum: .seconds(300)) == .seconds(300))
			#expect(FeedScreenModel
				.recoveryInterval(forAttempt: 100, initial: .seconds(5), maximum: .seconds(300)) == .seconds(300))
		}
	}
}
