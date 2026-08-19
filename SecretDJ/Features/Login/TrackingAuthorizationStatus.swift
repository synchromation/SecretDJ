/// The system App Tracking Transparency authorization state
/// (`ATTrackingManager.AuthorizationStatus`, thinned to what the Login
/// feature acts on), gating Facebook sign-in per LEGACY.md
/// "Privacy/tracking" — the ATT prompt exists solely to gate Facebook SDK
/// features.
enum TrackingAuthorizationStatus: Equatable {
	/// The user hasn't been asked yet — a sign-in attempt should request
	/// authorization before proceeding.
	case notDetermined
	/// Tracking is allowed; Facebook sign-in may proceed.
	case authorized
	/// The user explicitly declined tracking. Legacy disables the Facebook
	/// button for this case (LEGACY.md "Privacy/tracking": "the button is
	/// disabled if tracking was rejected").
	case denied
	/// Tracking is unavailable for a reason outside the user's control
	/// (e.g. a device restriction) — treated the same as ``denied`` for
	/// gating purposes.
	case restricted
}
