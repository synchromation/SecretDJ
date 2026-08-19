/// The App Tracking Transparency flow ``FacebookSignInModel`` needs, thinned
/// to a protocol seam so tests never touch `AppTrackingTransparency`
/// (ios-architecture: a protocol seam per real dependency). The real
/// adapter (``ATTrackingManagerTrackingAuthorizing``) wraps `ATTrackingManager`
/// directly.
protocol TrackingAuthorizing: Sendable {
	/// Reads the current system status without prompting.
	func currentStatus() -> TrackingAuthorizationStatus

	/// Presents the system prompt when the status is
	/// ``TrackingAuthorizationStatus/notDetermined`` and awaits the user's
	/// choice; a no-op read of ``currentStatus()`` otherwise, since the
	/// system only ever prompts once per install.
	func requestAuthorization() async -> TrackingAuthorizationStatus
}
