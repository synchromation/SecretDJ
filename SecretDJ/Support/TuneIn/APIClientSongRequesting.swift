import SecretDJAPI
import SecretDJDomain
import SharedFeatures

/// The production ``SharedFeatures/SongRequesting``: calls straight through
/// to ``SecretDJAPI/APIClient``'s `requestsong` endpoint
/// (``SecretDJAPI/APIClient/requestSong(userId:venueId:songId:credential:)``,
/// which already classifies the response into
/// ``SecretDJDomain/SongRequestResult`` per LEGACY.md business rule 5),
/// reading the signed-in user/credential fresh on every call — never
/// captured once at construction time, matching
/// `APIClientAtmosphereChanging`'s own doc comment — and rotating the
/// session's token when the response carries one.
struct APIClientSongRequesting: SongRequesting {
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
