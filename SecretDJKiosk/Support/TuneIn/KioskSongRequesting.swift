import SecretDJAPI
import SecretDJDomain
import SharedFeatures

/// The kiosk's own production ``SharedFeatures/SongRequesting`` — calls
/// straight through to ``SecretDJAPI/APIClient``'s `requestsong` endpoint,
/// same shape as the consumer's own `APIClientSongRequesting`
/// (`SecretDJ/Support/TuneIn/APIClientSongRequesting.swift`; see
/// ``KioskAtmosphereChanging``'s doc comment on why this is a kiosk-local
/// copy rather than a shared type). LEGACY.md's "the kiosk's whole write
/// path": tapping a song anywhere on the kiosk (the digest, a jukebox's own
/// song grid) opens TuneIn and can request it here — unmetered, per legacy's
/// own "In kiosk mode they will never run out of credits" comment
/// (`secretdjv3/KioskTuneInViewController.swift`) — this adapter itself
/// doesn't special-case that: it classifies whatever
/// ``SecretDJDomain/SongRequestResult`` the server sends back exactly like
/// the consumer's copy does, since the server is the one place that actually
/// knows a venue account never runs low.
struct KioskSongRequesting: SongRequesting {
	private let client: APIClient
	private let sessionStore: SessionStore

	init(client: APIClient, sessionStore: SessionStore) {
		self.client = client
		self.sessionStore = sessionStore
	}

	func requestSong(songId: String, venueId: String) async throws(SongRequestError) -> SongRequestResult {
		let session = await MainActor.run { (sessionStore.user?.personId, sessionStore.credential) }
		guard let userId = session.0, let credential = session.1 else {
			throw .notSignedIn
		}

		do {
			let response = try await client.requestSong(
				userId: userId,
				venueId: venueId,
				songId: songId,
				credential: credential,
			)
			if let rotatedToken = response.rotatedToken {
				await MainActor.run { sessionStore.rotateToken(rotatedToken) }
			}
			return response.payload
		} catch {
			throw .connection
		}
	}
}
