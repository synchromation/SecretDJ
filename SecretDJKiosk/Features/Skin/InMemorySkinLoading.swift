import SecretDJAPI

/// A scriptable ``SkinLoading`` fake for tests and previews — never touches
/// the network (mirrors ``InMemorySessionSnapshotStore``'s shape: a
/// `@MainActor` class, since it's only ever driven from `SkinModel`'s own
/// main-actor context).
@MainActor
final class InMemorySkinLoading: SkinLoading {
	private(set) var fetchCount = 0
	var result: Result<SkinManifest, SkinLoadingError>

	init(result: Result<SkinManifest, SkinLoadingError>) {
		self.result = result
	}

	func fetchManifest() async throws(SkinLoadingError) -> SkinManifest {
		fetchCount += 1
		switch result {
		case .success(let manifest):
			return manifest
		case .failure(let error):
			throw error
		}
	}
}
