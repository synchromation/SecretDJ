import SecretDJAPI
import SharedFeatures

/// The kiosk's own production ``SharedFeatures/AtmosphereChanging`` — calls
/// straight through to ``SecretDJAPI/APIClient``'s `machinecontrol` endpoint,
/// same shape as the consumer's own `APIClientAtmosphereChanging`
/// (`SecretDJ/Support/MusicSelection/APIClientAtmosphereChanging.swift`).
/// Duplicated rather than shared: unlike the feed-loading adapter, this type
/// has no app-specific dependency at all (just ``SecretDJAPI/APIClient``/
/// ``SecretDJAPI/SessionStore``, both already shared), but the two apps'
/// composition roots each own their own thin adapters over the shared
/// package types throughout this codebase (every S6/S7 screen's own
/// `APIClient*` wiring lives in its app target, never in a package) — this
/// follows that existing convention rather than introducing a new shared
/// "adapters" package for a handful of ~20-line structs.
struct KioskAtmosphereChanging: AtmosphereChanging {
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
