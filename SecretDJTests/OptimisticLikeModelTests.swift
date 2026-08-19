import Observability
import SecretDJDomain
import Testing

@testable import SecretDJ

/// ``OptimisticLikeModel`` — the reusable like/unlike toggle S6.2 builds for
/// the venue screen and S6.3 (songs)/S6.6 (people) reuse unmodified: an
/// immediate optimistic flip, a rollback on failure, and the server's own
/// like-summary copy adopted on success (D11 — server copy renders
/// as-delivered).
@MainActor
enum OptimisticLikeModelTests {
	struct `Starting up` {
		@Test func `starts with the initial likeInfo it was given`() {
			let model = makeModel(likeInfo: LikeInfo(likedByYou: false, info: "Be the first to like this"))

			#expect(model.likeInfo == LikeInfo(likedByYou: false, info: "Be the first to like this"))
		}
	}

	struct `Toggling on success` {
		@Test func `flips likedByYou immediately, before the call resolves`() async {
			let toggling = InMemoryLikeToggling()
			toggling.hang()
			let model = makeModel(likeInfo: LikeInfo(likedByYou: false, info: ""), likeToggling: toggling)

			async let toggle: Void = model.toggle()
			await Task.yield()

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

		@Test func `falls back to a generic message when the server sends none`() async {
			let toggling = InMemoryLikeToggling(result: .failure(.server(message: nil)))
			let model = makeModel(likeToggling: toggling)

			await model.toggle()

			#expect(model.failureEvent?.message == OptimisticLikeModel.fallbackFailureMessage)
		}

		@Test func `falls back to a generic message on a connection failure`() async {
			let toggling = InMemoryLikeToggling(result: .failure(.connection))
			let model = makeModel(likeToggling: toggling)

			await model.toggle()

			#expect(model.failureEvent?.message == OptimisticLikeModel.fallbackFailureMessage)
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
			await Task.yield()

			#expect(model.isToggling)
			toggling.resume(with: .success(LikeResult(message: "", url: "", isLikedByYou: true)))
			await toggle
			#expect(!model.isToggling)
		}
	}

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
			await Task.yield()
			model.reconcile(with: LikeInfo(likedByYou: false, info: "A stale refresh snapshot"))

			#expect(model.likeInfo.likedByYou)
			toggling.resume(with: .success(LikeResult(message: "1 person buzzed this", url: "", isLikedByYou: true)))
			await toggleTask
		}
	}
}

// MARK: - Fixtures

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
