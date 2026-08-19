import SecretDJAPI
import SecretDJDomain
import SharedFeatures

/// The production ``MusicSearching``: calls straight through to
/// ``SecretDJAPI/APIClient``'s `musicSearch`/`artistsAvailable`/
/// `songsForArtist`, reading the signed-in user/credential fresh on every
/// call — never captured once at construction time, matching
/// ``APIClientFeedLoading/sessionFeed(sessionStore:locationService:endpoint:)``'s
/// doc comment. `venueId` is fixed at construction (one search screen is
/// always scoped to one venue, unlike the per-call `venueId` on
/// ``LikeToggling``, which serves items that aren't always in a venue
/// context).
struct APIClientMusicSearching: MusicSearching {
	private let client: APIClient
	private let sessionStore: SessionStore
	private let venueId: String

	init(client: APIClient, sessionStore: SessionStore, venueId: String) {
		self.client = client
		self.sessionStore = sessionStore
		self.venueId = venueId
	}

	func search(query: String, mode: MusicSearchMode) async throws(MusicSearchError) -> SectionList {
		try await call { (userId: String, credential: APICredential) async throws(APIError) -> APIResponse<
			SectionList,
		> in
			try await client.musicSearch(
				userId: userId,
				venueId: venueId,
				query: query,
				type: mode.wireType,
				mask: .computeLikes,
				credential: credential,
			)
		}
	}

	func artistsAvailable() async throws(MusicSearchError) -> [Artist] {
		try await call { (userId: String, credential: APICredential) async throws(APIError) -> APIResponse<
			ArtistsAvailablePayload,
		> in
			try await client.artistsAvailable(userId: userId, venueId: venueId, hash: nil, credential: credential)
		}.artists
	}

	func songs(forArtist artistName: String) async throws(MusicSearchError) -> SectionList {
		let artist = Artist(name: artistName, artist: artistName, numSongs: 0, sortIndex: 0, action: nil, actions: [])
		return try await call { (userId: String, credential: APICredential) async throws(APIError) -> APIResponse<
			SectionList,
		> in
			try await client.songsForArtist(artist, userId: userId, venueId: venueId, credential: credential)
		}
	}

	private func call<Payload>(
		endpoint: (_ userId: String, _ credential: APICredential) async throws(APIError) -> APIResponse<Payload>,
	) async throws(MusicSearchError) -> Payload {
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

extension MusicSearchMode {
	/// This mode's `musicsearch` `type` parameter
	/// (`secretdjv3/SearchAPIAccess.swift`'s `MusicSearchType`). `.artist`
	/// is unused by ``SearchModel`` today — artist mode reads
	/// ``MusicSearching/artistsAvailable()`` instead (LEGACY.md "Artist
	/// search": the whole index, not a per-keystroke server search) — kept
	/// here for a complete, exhaustive mapping rather than a partial one.
	fileprivate var wireType: MusicSearchType {
		switch self {
		case .artist: .artists
		case .track: .songs
		}
	}
}
