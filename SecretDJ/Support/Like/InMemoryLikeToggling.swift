import SecretDJDomain

/// A scriptable ``LikeToggling`` fake for tests and previews — never
/// touches the network, mirrors ``InMemoryAccountService``'s shape. Beyond
/// the usual immediate ``result``, ``hang()``/``resume(with:)`` let a test
/// suspend a call mid-flight to observe ``OptimisticLikeModel``'s optimistic
/// state before the server "answers" (the double-tap race coverage needs
/// this; a plain immediate-resolution fake can't exercise it).
@MainActor
final class InMemoryLikeToggling: LikeToggling {
	enum Call: Equatable {
		case like(itemId: String, venueId: String?, type: ItemType)
		case unlike(itemId: String, venueId: String?, type: ItemType)
	}

	private(set) var calls: [Call] = []
	var result: Result<LikeResult, LikeError>

	private var isHanging = false
	private var continuation: CheckedContinuation<Void, Never>?

	init(result: Result<LikeResult, LikeError> = .success(LikeResult(message: "", url: "", isLikedByYou: true))) {
		self.result = result
	}

	/// Makes the next call suspend until ``resume(with:)`` releases it.
	func hang() {
		isHanging = true
	}

	/// Releases a hung call with `result`, which also becomes the outcome
	/// for any later call made without hanging again.
	func resume(with result: Result<LikeResult, LikeError>) {
		self.result = result
		isHanging = false
		continuation?.resume()
		continuation = nil
	}

	func like(itemId: String, venueId: String?, type: ItemType) async throws(LikeError) -> LikeResult {
		try await resolve(.like(itemId: itemId, venueId: venueId, type: type))
	}

	func unlike(itemId: String, venueId: String?, type: ItemType) async throws(LikeError) -> LikeResult {
		try await resolve(.unlike(itemId: itemId, venueId: venueId, type: type))
	}

	private func resolve(_ call: Call) async throws(LikeError) -> LikeResult {
		calls.append(call)

		if isHanging {
			await withCheckedContinuation { continuation = $0 }
		}

		switch result {
		case .success(let value): return value
		case .failure(let error): throw error
		}
	}
}
