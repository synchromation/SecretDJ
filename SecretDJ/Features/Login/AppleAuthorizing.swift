/// The Sign in with Apple flow ``AppleSignInModel`` needs, thinned to a
/// protocol seam so tests never touch AuthenticationServices UI
/// (ios-architecture: a protocol seam per real dependency). The real
/// adapter (``ASAuthorizationControllerAppleAuthorizing``) wraps
/// `ASAuthorizationAppleIDProvider`/`ASAuthorizationController` directly.
protocol AppleAuthorizing: Sendable {
	/// Presents the system Sign in with Apple flow and awaits its result.
	func requestSignIn() async throws(AppleAuthorizationError) -> AppleAuthorizationResult
}
