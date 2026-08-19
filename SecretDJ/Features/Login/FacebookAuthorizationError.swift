/// Every way the Facebook Login SDK flow can end without a usable result.
enum FacebookAuthorizationError: Error, Equatable {
	/// The user dismissed the Facebook login flow — not a failure worth
	/// surfacing (mirrors ``AppleAuthorizationError/cancelled``; legacy shows
	/// no toast for this case either).
	case cancelled

	/// Any other `LoginManager` error, a login that granted no access token,
	/// or a malformed Graph API response.
	case failed
}
