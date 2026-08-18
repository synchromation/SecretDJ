import Foundation
import SecretDJDomain

/// `musicsearch`/`artistsavailable` — the music-search endpoints
/// (LEGACY.md "Backend API and Spotify integration" → endpoint catalog),
/// typed over ``APIClient``. Ported from `secretdjv3/SearchAPIAccess.swift`.
/// Neither appears in the legacy sig-exclusion list, so both require an
/// ``APICredential``.
extension APIClient {
	/// `musicsearch` — free-text song/artist search
	/// (`secretdjv3/SearchAPIAccess.swift`'s `search`).
	public func musicSearch(
		userId: String,
		venueId: String,
		query: String,
		type: MusicSearchType,
		mask: MusicSearchMask,
		credential: APICredential,
	) async throws(APIError) -> APIResponse<SectionList> {
		try await executeFeed(
			endpoint: "musicsearch",
			parameters: [
				"user": userId,
				"venue": venueId,
				"q": query,
				"type": String(type.rawValue),
				"searchmask": String(mask.rawValue),
			],
			signed: true,
			credential: credential,
		)
	}

	/// The "songs by this artist" flow: the same `musicsearch` wire call,
	/// but with `type: .artists` and the artist's own name as the query
	/// (`secretdjv3/ArtistSearchFeedInteractor.swift`'s
	/// `SongsForVariableArtistFeedDataProvider.songsForArtist`) — a legacy
	/// quirk (the `type` value doesn't describe what's actually returned)
	/// preserved rather than "fixed", since there's no dedicated
	/// songs-for-artist endpoint to call instead.
	public func songsForArtist(
		_ artist: Artist,
		userId: String,
		venueId: String,
		credential: APICredential,
	) async throws(APIError) -> APIResponse<SectionList> {
		try await musicSearch(
			userId: userId,
			venueId: venueId,
			query: artist.name,
			type: .artists,
			mask: .computeLikes,
			credential: credential,
		)
	}

	/// `artistsavailable` — the venue's full artist catalogue, flat rather
	/// than a `SectionList` (`secretdjv3/SearchAPIAccess.swift`'s
	/// `artists`); `hash` pages/change-detects the same way
	/// `musicselection`/`styleinfo` do. Client-side alphabetical bucketing
	/// (`secretdjv3/SearchAPIAccess.swift`'s `characterGroup`) is a display
	/// concern that stays with the caller, not this package.
	public func artistsAvailable(
		userId: String,
		venueId: String,
		hash: FeedHash?,
		credential: APICredential,
	) async throws(APIError) -> APIResponse<ArtistsAvailablePayload> {
		var parameters = ["user": userId, "venue": venueId]
		if let hash {
			parameters["hash"] = hash.rawValue
		}
		return try await execute(
			endpoint: "artistsavailable",
			parameters: parameters,
			signed: true,
			credential: credential,
			decodingPayloadAs: ArtistsAvailablePayload.self,
		)
	}
}

/// `musicsearch`'s `type` parameter — 2 searches songs, 8 searches artists
/// (`secretdjv3/SearchAPIAccess.swift`'s `MusicSearchType`).
public enum MusicSearchType: Int, Sendable {
	case songs = 2
	case artists = 8
}

/// `musicsearch`'s `searchmask` parameter
/// (`secretdjv3/SearchAPIAccess.swift`'s `MusicSearchMask`).
public enum MusicSearchMask: Int, Sendable {
	case none = 0
	case computeLikes = 1
}

/// `artistsavailable`'s wire shape: a flat `Artists` array plus
/// `TopupAllowed` and a change-detection `Hash` (LEGACY.md's catalog: "flat
/// `Artists` array + `TopupAllowed`"; `secretdjv3/SearchAPIAccess.swift`'s
/// `artists`).
public struct ArtistsAvailablePayload: Sendable, Hashable, Decodable {
	public let artists: [Artist]
	public let topUpAllowed: Bool
	public let hash: FeedHash

	private enum CodingKeys: String, CodingKey {
		case artists = "Artists"
		case topUpAllowed = "TopupAllowed"
		case hash = "Hash"
	}

	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		artists = try container.decodeIfPresent([Artist].self, forKey: .artists) ?? []
		topUpAllowed = try container.decodeIfPresent(Bool.self, forKey: .topUpAllowed) ?? false
		hash = try FeedHash(rawValue: container.decodeIfPresent(String.self, forKey: .hash) ?? "")
	}
}
