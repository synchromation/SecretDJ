import SecretDJAPI
import SharedFeatures

/// The production ``AtmosphereChanging``: calls straight through to
/// ``SecretDJAPI/APIClient``'s `machinecontrol` endpoint
/// (``SecretDJAPI/APIClient/machineControl(userId:venueId:action:item:value:credential:)``),
/// reading the signed-in user/credential fresh on every call — never
/// captured once at construction time, matching
/// ``APIClientFeedLoading/sessionFeed(sessionStore:locationService:endpoint:)``'s
/// doc comment — and rotating the session's token when the response carries
/// one.
struct APIClientAtmosphereChanging: AtmosphereChanging {
	private let client: APIClient
	private let sessionStore: SessionStore

	init(client: APIClient, sessionStore: SessionStore) {
		self.client = client
		self.sessionStore = sessionStore
	}

	func changeAtmosphere(
		itemId: Int,
		venueId: String,
		minutes: Int,
	) async throws(AtmosphereChangeError) -> AtmosphereChangeResult {
		let session = await MainActor.run { (sessionStore.user?.personId, sessionStore.credential) }
		guard let userId = session.0, let credential = session.1 else {
			throw .notSignedIn
		}

		do {
			let response = try await client.machineControl(
				userId: userId,
				venueId: venueId,
				action: .changeAtmosphere,
				item: String(itemId),
				value: minutes,
				credential: credential,
			)
			if let rotatedToken = response.rotatedToken {
				await MainActor.run { sessionStore.rotateToken(rotatedToken) }
			}
			return AtmosphereChangeResult(message: response.payload.text)
		} catch {
			if case .server(let message) = error {
				throw .server(message: message)
			}
			throw .connection
		}
	}
}
