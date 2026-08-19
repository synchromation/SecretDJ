import SecretDJDomain

/// The music-search reads ``SearchModel`` needs (LEGACY.md "Choosing music:
/// digest → jukebox pages → search") — thinned to this exact surface
/// (ios-architecture: a protocol seam per real dependency) so SharedFeatures
/// never depends on SecretDJAPI (PLAN.md's architecture target). An app
/// implements this over `APIClient.musicSearch`/`artistsAvailable`/
/// `songsForArtist`.
public protocol MusicSearching: Sendable {
	/// A free-text search in `mode`, server round-tripped per keystroke
	/// (`musicsearch` — LEGACY.md "Song search"). Results arrive as a
	/// ready-to-render ``SecretDJDomain/SectionList``, same as any other
	/// feed.
	func search(query: String, mode: MusicSearchMode) async throws(MusicSearchError) -> SectionList

	/// The venue's entire available-artist index, fetched once
	/// (`artistsavailable` — LEGACY.md "Artist search"); client-side
	/// bucketing into the A–Z index is ``SearchModel``'s job, not this
	/// seam's.
	func artistsAvailable() async throws(MusicSearchError) -> [Artist]

	/// The songs-for-artist drill-in for a multi-song artist row
	/// (`musicsearch` with `type: .artists` and the artist's own name as
	/// the query — a legacy quirk `SecretDJAPI.songsForArtist(_:...)`
	/// preserves rather than "fixes"). Takes the bare name rather than a
	/// full ``SecretDJDomain/Artist`` value because that's all
	/// ``FeedUI/FeedActionOutcome/showSongsForArtist(artist:)`` ever carries
	/// (no song id — or artist id — is known at that point, per its own
	/// doc comment).
	func songs(forArtist artistName: String) async throws(MusicSearchError) -> SectionList
}

/// Which catalogue ``MusicSearching/search(query:mode:)`` searches — the
/// `musicsearch` endpoint's `type` mask (LEGACY.md: "type=2 songs, type=8
/// artists"), named for what the caller is choosing between rather than the
/// wire value.
public enum MusicSearchMode: Sendable, Hashable {
	case artist
	case track
}

/// Every way a ``MusicSearching`` call can fail — same shape as
/// `LikeError`/``AtmosphereChangeError``'s sibling seams, kept as its own
/// type since each feature's seam is deliberately separate.
public enum MusicSearchError: Error, Equatable, Sendable {
	case server(message: String?)
	case connection
	/// No session was signed in at the moment the call fired — mirrors
	/// `NotSignedInFeedLoadingError`'s doc comment: the search screen only
	/// exists while signed in, so this defends against a pending call
	/// outliving a sign-out rather than a state the UI needs to
	/// distinguish from ``connection``.
	case notSignedIn
}
