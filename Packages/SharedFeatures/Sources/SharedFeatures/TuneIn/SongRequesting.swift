import SecretDJDomain

/// The `requestsong` write ``TuneInScreenModel`` needs (LEGACY.md "Song
/// screen and the request flow (TuneIn)") — thinned to this exact surface
/// (ios-architecture: a protocol seam per real dependency) so SharedFeatures
/// never depends on SecretDJAPI (PLAN.md's architecture target). An app
/// implements this over `APIClient.requestSong(userId:venueId:songId:credential:)`,
/// which already classifies the response into ``SecretDJDomain/SongRequestResult``
/// — this seam only adds the signed-in-session guard other SharedFeatures
/// seams share (``AtmosphereChanging``/``LikeToggling``).
public protocol SongRequesting: Sendable {
	/// Requests `songId` on `venueId`'s jukebox. Never throws for a
	/// server-worded outcome — success, out-of-credits, or a named failure
	/// are all ordinary ``SecretDJDomain/SongRequestResult`` cases (LEGACY.md
	/// business rule 5); this only throws for a transport-level failure.
	func requestSong(songId: String, venueId: String) async throws(SongRequestError) -> SongRequestResult
}

/// Every way a ``SongRequesting`` call can fail before the server even gets
/// to word an outcome — same shape as ``AtmosphereChangeError`` minus
/// `.server`, since a server-level failure is already a
/// ``SecretDJDomain/SongRequestResult/failure(message:)`` case rather than a
/// thrown error.
public enum SongRequestError: Error, Equatable, Sendable {
	case connection
	/// No session was signed in at the moment the call fired — mirrors
	/// ``AtmosphereChangeError/notSignedIn``'s doc comment: a screen only
	/// exists while signed in, so this defends against a pending call
	/// outliving a sign-out rather than a state the UI needs to distinguish
	/// from ``connection``.
	case notSignedIn
}
