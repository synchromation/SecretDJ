import SecretDJDomain

/// The like/unlike call ``OptimisticLikeModel`` needs, thinned to this exact
/// surface (ios-architecture: a protocol seam per real dependency) so
/// SharedFeatures never depends on SecretDJAPI (PLAN.md's architecture
/// target) — deliberately item-generic (`itemId` + `type`), since this same
/// seam serves venues (S6.2), songs (S6.3), and people (S6.6). An app
/// implements this over `APIClient.like`/`unlike`, mapping its own
/// `APIError` inline rather than through a shared initializer (mirrors
/// ``AtmosphereChanging``'s adapter, `APIClientAtmosphereChanging`).
public protocol LikeToggling: Sendable {
	/// `venueId` is the venue context the like happened in — sent even when
	/// `type` is itself `.venue` (legacy always attaches the current venue,
	/// `secretdjv3/VenueFeedViewController.swift`'s
	/// `likeAPI.updateLikeStatus(..., venueId: venue.venueId, item: venue.venueId, type: .venue, ...)`)
	/// — `nil` only where no venue context exists.
	func like(itemId: String, venueId: String?, type: ItemType) async throws(LikeError) -> LikeResult
	func unlike(itemId: String, venueId: String?, type: ItemType) async throws(LikeError) -> LikeResult
}

/// Every way a ``LikeToggling`` call can fail — same shape as
/// ``AtmosphereChangeError``, kept as its own type since each feature's seam
/// is deliberately separate.
public enum LikeError: Error, Equatable, Sendable {
	case server(message: String?)
	case connection
	/// No session was signed in at the moment the call fired — mirrors
	/// ``AtmosphereChangeError/notSignedIn``'s doc comment: a screen only
	/// exists while signed in, so this defends against a pending call
	/// outliving a sign-out rather than a state the UI needs to distinguish
	/// from ``connection``.
	case notSignedIn
}
