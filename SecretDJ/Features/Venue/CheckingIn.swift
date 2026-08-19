import Foundation

/// The `checkin` call ``CheckInModel`` needs, thinned from
/// ``SecretDJAPI/APIClient`` to this feature's exact surface
/// (ios-architecture: a protocol seam per real dependency) — mirrors
/// ``SharedFeatures/LikeToggling``'s shape: no `userId`/credential
/// parameters, since the production adapter (``APIClientCheckingIn``) reads
/// the signed-in session live at call time rather than the model touching
/// session concerns at all.
protocol CheckingIn: Sendable {
	/// Checks the signed-in user into `venueId`. Always sent with
	/// scope `everyone` (LEGACY.md business rule 12: "Check-ins always sent
	/// with `scope=everyone`" — the only value the legacy client ever sent,
	/// and the wire default `SecretDJAPI/APIClient.checkIn` already applies)
	/// — this seam has no parameter for it, so a caller can't accidentally
	/// send anything else.
	func checkIn(venueId: String) async throws(CheckInError) -> CheckInOutcome
}

/// Every way a ``CheckingIn`` call can fail — same shape as
/// ``SharedFeatures/LikeError``, kept as its own type since the two seams
/// are deliberately separate.
enum CheckInError: Error, Equatable {
	case server(message: String?)
	case connection
	/// No session was signed in at the moment the call fired — mirrors
	/// ``SharedFeatures/LikeError/notSignedIn``'s doc comment: a screen only
	/// exists while signed in, so this defends against a pending call
	/// outliving a sign-out rather than a state the UI needs to distinguish
	/// from ``connection``.
	case notSignedIn
}

/// ``CheckingIn/checkIn(venueId:)``'s outcome — the server's own
/// confirmation copy and an optional hand-off URL
/// (`secretdjv3/CheckInAPIAccess.swift`'s `CheckInInfo`). LEGACY.md's
/// `ToastHandler`: "if the server response carries a URL, an in-app web
/// view is pushed *instead of* the toast" — so `url`, when present, takes
/// priority over `message` at the call site rather than both showing.
struct CheckInOutcome: Equatable {
	let message: String?
	let url: URL?
}
