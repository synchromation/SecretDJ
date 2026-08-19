import SecretDJAPI

/// `setuserdetails` with just `screenname` — the post-signup username step
/// shared by the Apple and Facebook sign-up routes (each runs before
/// onboarding's own remaining steps; native sign-up collects a screen name
/// as part of its own details form instead) and isn't
/// ``OnboardingServicing``'s job (see ``OnboardingRoute``'s doc comment).
protocol SocialUsernameServicing: Sendable {
	func setScreenName(
		userId: String,
		screenName: String,
		credential: APICredential,
	) async throws(AuthenticationError) -> ScreenNameUpdateOutcome
}

/// ``SocialUsernameServicing/setScreenName(userId:screenName:credential:)``'s
/// outcome.
struct ScreenNameUpdateOutcome: Equatable {
	let succeeded: Bool
	let message: String?
	/// The server's freshly issued token, when the response carried one —
	/// feed to ``SecretDJAPI/SessionStore/rotateToken(_:)``.
	let rotatedToken: String?
}
