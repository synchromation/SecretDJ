import SecretDJAPI
import SecretDJDomain
import SharedFeatures

/// The production ``SharedFeatures/LikeToggling``: calls straight through to
/// ``SecretDJAPI/APIClient``'s `like`/`unlike` endpoints, reading the
/// signed-in user/credential fresh on every call — never captured once at
/// construction time, matching ``APIClientFeedLoading/sessionFeed(sessionStore:locationService:endpoint:)``'s
/// doc comment (a long-lived, auto-refreshing screen can outlive one
/// token's lifetime) — and rotating the session's token when the response
/// carries one. Kept consumer-side (unlike ``SharedFeatures/OptimisticLikeModel``
/// itself, relocated for S6.3b): this adapter depends on `SecretDJAPI`/
/// `SessionStore`, which SharedFeatures never imports (ios-architecture),
/// so it maps ``SecretDJAPI/APIError`` to ``SharedFeatures/LikeError``
/// inline rather than through a shared initializer (mirrors
/// `APIClientAtmosphereChanging`'s own inline mapping).
struct APIClientLikeToggling: LikeToggling {
	private let client: APIClient
	private let sessionStore: SessionStore

	init(client: APIClient, sessionStore: SessionStore) {
		self.client = client
		self.sessionStore = sessionStore
	}

	func like(itemId: String, venueId: String?, type: ItemType) async throws(LikeError) -> LikeResult {
		try await call { (userId: String, credential: APICredential) async throws(APIError) -> APIResponse<
			LikeResult,
		> in
			try await client.like(userId: userId, venueId: venueId, item: itemId, type: type, credential: credential)
		}
	}

	func unlike(itemId: String, venueId: String?, type: ItemType) async throws(LikeError) -> LikeResult {
		try await call { (userId: String, credential: APICredential) async throws(APIError) -> APIResponse<
			LikeResult,
		> in
			try await client.unlike(userId: userId, venueId: venueId, item: itemId, type: type, credential: credential)
		}
	}

	private func call(
		endpoint: (_ userId: String, _ credential: APICredential) async throws(APIError) -> APIResponse<LikeResult>,
	) async throws(LikeError) -> LikeResult {
		let session = await MainActor.run { (sessionStore.user?.personId, sessionStore.credential) }
		guard let userId = session.0, let credential = session.1 else {
			throw .notSignedIn
		}

		do {
			let response = try await endpoint(userId, credential)
			if let rotatedToken = response.rotatedToken {
				await MainActor.run { sessionStore.rotateToken(rotatedToken) }
			}
			return response.payload
		} catch {
			if case .server(let message) = error {
				throw .server(message: message)
			}
			throw .connection
		}
	}
}
