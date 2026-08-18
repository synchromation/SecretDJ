/// Every way the Sign in with Apple system flow can end without a usable
/// result.
enum AppleAuthorizationError: Error, Equatable {
	/// The user dismissed the system sheet — not a failure worth surfacing
	/// (the legacy `LoginViewController` shows no toast for this case).
	case cancelled

	/// Any other `ASAuthorizationError`, a credential of an unexpected
	/// type, or a malformed result.
	case failed
}
