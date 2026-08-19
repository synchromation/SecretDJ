import SecretDJAPI
import SecretDJDomain

/// The like/unlike call ``OptimisticLikeModel`` needs, thinned from
/// ``SecretDJAPI/APIClient`` to this exact surface (ios-architecture: a
/// protocol seam per real dependency) — deliberately item-generic (`itemId`
/// + `type`), since this same seam serves songs (S6.3) and people (S6.6) as
/// well as venues (S6.2).
protocol LikeToggling: Sendable {
	/// `venueId` is the venue context the like happened in — sent even when
	/// `type` is itself `.venue` (legacy always attaches the current venue,
	/// `secretdjv3/VenueFeedViewController.swift`'s
	/// `likeAPI.updateLikeStatus(..., venueId: venue.venueId, item: venue.venueId, type: .venue, ...)`)
	/// — `nil` only where no venue context exists.
	func like(itemId: String, venueId: String?, type: ItemType) async throws(LikeError) -> LikeResult
	func unlike(itemId: String, venueId: String?, type: ItemType) async throws(LikeError) -> LikeResult
}

/// Every way a ``LikeToggling`` call can fail — same shape as
/// ``AccountError``/``AuthenticationError``, kept as its own type since each
/// feature's seam is deliberately separate.
enum LikeError: Error, Equatable {
	case server(message: String?)
	case connection
	/// No session was signed in at the moment the call fired — mirrors
	/// ``NotSignedInFeedLoadingError``'s doc comment: a screen only exists
	/// while signed in, so this defends against a pending call outliving a
	/// sign-out rather than a state the UI needs to distinguish from
	/// ``connection``.
	case notSignedIn

	init(_ apiError: APIError) {
		if case .server(let message) = apiError {
			self = .server(message: message)
		} else {
			self = .connection
		}
	}
}
