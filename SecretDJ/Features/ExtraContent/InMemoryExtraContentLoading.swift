import SecretDJAPI
import SecretDJDomain

/// A scriptable ``ExtraContentLoading`` fake for tests and previews — never
/// touches the network, mirrors ``InMemoryLikeToggling``'s shape.
@MainActor
final class InMemoryExtraContentLoading: ExtraContentLoading {
	struct Call: Equatable {
		let venueId: String?
		let screen: ExtraContentScreen
	}

	/// Every call this fake received, in order — a test's way to confirm
	/// which `screen`/`venueId` ``ExtraContentModel`` requested.
	private(set) var calls: [Call] = []
	var result: Result<[Item], FakeExtraContentLoadingError>

	init(result: Result<[Item], FakeExtraContentLoadingError> = .success([])) {
		self.result = result
	}

	func loadExtraContent(venueId: String?, screen: ExtraContentScreen) async throws -> [Item] {
		calls.append(Call(venueId: venueId, screen: screen))
		return try result.get()
	}
}

/// A generic failure for ``InMemoryExtraContentLoading``'s ``InMemoryExtraContentLoading/result``
/// — the ticker swallows every fetch failure identically
/// (``ExtraContentModel/fetch()``'s doc comment), so tests never need to
/// distinguish failure kinds the way ``APIClientExtraContentLoading``'s
/// production error does.
struct FakeExtraContentLoadingError: Error, Equatable {}
