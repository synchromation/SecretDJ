import Testing

@testable import SharedFeatures

import SecretDJDomain

/// ``OptimisticLikeModel`` — the reusable like/unlike toggle S6.2 builds for
/// the venue screen and S6.3 (songs)/S6.6 (people) reuse unmodified: an
/// immediate optimistic flip, a rollback on failure, and the server's own
/// like-summary copy adopted on success (D11 — server copy renders
/// as-delivered). Relocated from the consumer app's `SecretDJTests` for
/// S6.3b, alongside the model itself.
enum OptimisticLikeModelTests {
	@MainActor
	struct `Starting up` {
		@Test func `starts with the initial likeInfo it was given`() {
			let model = makeModel(likeInfo: LikeInfo(likedByYou: false, info: "Be the first to like this"))

			#expect(model.likeInfo == LikeInfo(likedByYou: false, info: "Be the first to like this"))
		}
	}

	@MainActor
	struct `Toggling on success` {
		@Test func `flips likedByYou immediately, before the call resolves`() async {
			let toggling = InMemoryLikeToggling()
			toggling.hang()
			let model = makeModel(likeInfo: LikeInfo(likedByYou: false, info: ""), likeToggling: toggling)

			async let toggle: Void = model.toggle()
			await waitUntil { !toggling.calls.isEmpty }

			#expect(model.likeInfo.likedByYou)
			toggling.resume(with: .success(LikeResult(message: "1 person buzzed this", url: "", isLikedByYou: true)))
			await toggle
		}

		@Test func `calls like when going from not liked to liked`() async throws {
			let toggling = InMemoryLikeToggling(result: .success(LikeResult(message: "", url: "", isLikedByYou: true)))
			let model = makeModel(
				itemId: "v1",
				venueId: "v1",
				type: .venue,
				likeInfo: LikeInfo(likedByYou: false, info: ""),
				likeToggling: toggling,
			)

			await model.toggle()

			let call = try #require(toggling.calls.last)
			#expect(call == .like(itemId: "v1", venueId: "v1", type: .venue))
		}

		@Test func `calls unlike when going from liked to not liked`() async throws {
			let toggling = InMemoryLikeToggling(result: .success(LikeResult(message: "", url: "", isLikedByYou: false)))
			let model = makeModel(
				likeInfo: LikeInfo(likedByYou: true, info: "1 person buzzed this"),
				likeToggling: toggling,
			)

			await model.toggle()

			let call = try #require(toggling.calls.last)
			#expect(call == .unlike(itemId: "v1", venueId: "v1", type: .venue))
		}

		@Test func `adopts the server's likeInfo copy once the call succeeds`() async {
			let toggling = InMemoryLikeToggling(
				result: .success(LikeResult(message: "12 people buzzed this", url: "", isLikedByYou: true)),
			)
			let model = makeModel(likeInfo: LikeInfo(likedByYou: false, info: ""), likeToggling: toggling)

			await model.toggle()

			#expect(model.likeInfo == LikeInfo(likedByYou: true, info: "12 people buzzed this"))
		}
	}

	@MainActor
	struct `Toggling on failure` {
		@Test func `rolls back to the previous likeInfo`() async {
			let toggling = InMemoryLikeToggling(result: .failure(.connection))
			let model = makeModel(likeInfo: LikeInfo(likedByYou: false, info: "Be the first"), likeToggling: toggling)

			await model.toggle()

			#expect(model.likeInfo == LikeInfo(likedByYou: false, info: "Be the first"))
		}

		@Test func `surfaces the server's error message as a failure event`() async {
			let toggling = InMemoryLikeToggling(
				result: .failure(.server(message: "Sorry, that venue doesn't want to be liked")),
			)
			let model = makeModel(likeToggling: toggling)

			await model.toggle()

			#expect(model.failureEvent?.message == "Sorry, that venue doesn't want to be liked")
		}

		@Test func `leaves the failure event's message nil when the server sends none, for the caller's own fallback`(
		) async {
			let toggling = InMemoryLikeToggling(result: .failure(.server(message: nil)))
			let model = makeModel(likeToggling: toggling)

			await model.toggle()

			#expect(model.failureEvent?.message == nil)
		}

		@Test func `leaves the failure event's message nil on a connection failure`() async {
			let toggling = InMemoryLikeToggling(result: .failure(.connection))
			let model = makeModel(likeToggling: toggling)

			await model.toggle()

			#expect(model.failureEvent?.message == nil)
		}

		@Test func `a second failure produces a distinct failure event id`() async {
			let toggling = InMemoryLikeToggling(result: .failure(.connection))
			let model = makeModel(likeToggling: toggling)

			await model.toggle()
			let first = model.failureEvent
			await model.toggle()
			let second = model.failureEvent

			#expect(first?.id != second?.id)
		}
	}

	@MainActor
	struct `Double-tap races` {
		@Test func `a second toggle while one is in flight makes no extra call`() async {
			let toggling = InMemoryLikeToggling()
			toggling.hang()
			let model = makeModel(likeToggling: toggling)

			async let first: Void = model.toggle()
			async let second: Void = model.toggle()
			await Task.yield()
			toggling.resume(with: .success(LikeResult(message: "", url: "", isLikedByYou: true)))
			_ = await (first, second)

			#expect(toggling.calls.count == 1)
		}

		@Test func `a toggle after a prior one completes is not blocked`() async {
			let toggling = InMemoryLikeToggling(result: .success(LikeResult(message: "", url: "", isLikedByYou: true)))
			let model = makeModel(likeInfo: LikeInfo(likedByYou: false, info: ""), likeToggling: toggling)

			await model.toggle()
			toggling.result = .success(LikeResult(message: "", url: "", isLikedByYou: false))
			await model.toggle()

			#expect(toggling.calls.count == 2)
		}

		@Test func `isToggling reports the in-flight state`() async {
			let toggling = InMemoryLikeToggling()
			toggling.hang()
			let model = makeModel(likeToggling: toggling)

			async let toggle: Void = model.toggle()
			await waitUntil { !toggling.calls.isEmpty }

			#expect(model.isToggling)
			toggling.resume(with: .success(LikeResult(message: "", url: "", isLikedByYou: true)))
			await toggle
			#expect(!model.isToggling)
		}
	}

	@MainActor
	struct `Reconciling with a fresh server snapshot` {
		@Test func `adopts a fresh server likeInfo when idle`() {
			let model = makeModel(likeInfo: LikeInfo(likedByYou: false, info: "Be the first"))

			model.reconcile(with: LikeInfo(likedByYou: true, info: "Someone else liked this first"))

			#expect(model.likeInfo == LikeInfo(likedByYou: true, info: "Someone else liked this first"))
		}

		@Test func `is ignored while a toggle is in flight, so it can't stomp an optimistic flip`() async {
			let toggling = InMemoryLikeToggling()
			toggling.hang()
			let model = makeModel(likeInfo: LikeInfo(likedByYou: false, info: "Be the first"), likeToggling: toggling)

			async let toggleTask: Void = model.toggle()
			await waitUntil { !toggling.calls.isEmpty }
			model.reconcile(with: LikeInfo(likedByYou: false, info: "A stale refresh snapshot"))

			#expect(model.likeInfo.likedByYou)
			toggling.resume(with: .success(LikeResult(message: "1 person buzzed this", url: "", isLikedByYou: true)))
			await toggleTask
		}
	}
}

// MARK: - Fixtures

/// Polls until `condition` holds, yielding the MainActor between checks —
/// a deterministic replacement for a single bare `await Task.yield()`
/// before asserting on an in-flight `async let`'s side effects. A single
/// yield only *suggests* the scheduler give another ready job a turn; it
/// doesn't guarantee the specific `async let` child task actually ran
/// before the caller resumes, so an assertion placed right after it is
/// flaky under heavy system load (observed: passes in isolation, fails
/// intermittently inside the full `Scripts/verify.sh test` run, where many
/// other processes contend for the same cooperative thread pool). Capped
/// so a genuine regression still fails fast rather than hanging.
@MainActor
private func waitUntil(_ condition: () -> Bool) async {
	for _ in 0 ..< 10000 where !condition() {
		await Task.yield()
	}
}

@MainActor
private func makeModel(
	itemId: String = "v1",
	venueId: String? = "v1",
	type: ItemType = .venue,
	likeInfo: LikeInfo = LikeInfo(likedByYou: false, info: ""),
	likeToggling: any LikeToggling = InMemoryLikeToggling(),
) -> OptimisticLikeModel {
	OptimisticLikeModel(itemId: itemId, venueId: venueId, type: type, likeInfo: likeInfo, likeToggling: likeToggling)
}
