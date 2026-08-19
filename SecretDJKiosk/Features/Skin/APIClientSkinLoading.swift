import SecretDJAPI

/// The production ``SkinLoading``: calls straight through to
/// ``SecretDJAPI/APIClient``'s `skinresources`, reading the signed-in
/// user/venue/credential fresh on every call — never captured once at
/// construction time (matches ``APIClientAtmosphereChanging``'s own doc
/// comment in the consumer app) — and rotating the session's token when the
/// response carries one.
struct APIClientSkinLoading: SkinLoading {
	private let client: APIClient
	private let sessionStore: SessionStore

	init(client: APIClient, sessionStore: SessionStore) {
		self.client = client
		self.sessionStore = sessionStore
	}

	func fetchManifest() async throws(SkinLoadingError) -> SkinManifest {
		let session = await MainActor.run {
			(sessionStore.user?.personId, sessionStore.venue?.venueId, sessionStore.credential)
		}
		guard let userId = session.0, let venueId = session.1, let credential = session.2 else {
			throw .notSignedIn
		}

		do {
			let response = try await client.skinResources(userId: userId, venueId: venueId, credential: credential)
			if let rotatedToken = response.rotatedToken {
				await MainActor.run { sessionStore.rotateToken(rotatedToken) }
			}
			return response.payload
		} catch {
			throw SkinLoadingError(error)
		}
	}
}
