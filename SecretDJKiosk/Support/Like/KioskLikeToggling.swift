import SecretDJAPI
import SecretDJDomain
import SharedFeatures

/// The kiosk's own production ``SharedFeatures/LikeToggling`` — calls
/// straight through to ``SecretDJAPI/APIClient``'s `like`/`unlike` endpoints,
/// same shape as the consumer's own `APIClientLikeToggling`
/// (`SecretDJ/Support/Like/APIClientLikeToggling.swift`; see
/// ``KioskAtmosphereChanging``'s doc comment on the kiosk-local-copy
/// convention). Required because ``SharedFeatures/TuneInScreen`` is reused
/// wholesale on the kiosk (PLAN.md S7.4/S7.5's own reuse instruction) and its
/// buzz control needs one regardless of app — legacy's own bespoke
/// `KioskTuneInViewController` never showed a buzz toggle, but building a
/// second, kiosk-only TuneIn screen just to drop one control is more scope
/// than this task calls for; showing it is a deliberate, minor divergence
/// from pixel-for-pixel legacy parity, not a functional gap.
struct KioskLikeToggling: LikeToggling {
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
