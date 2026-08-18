import SecretDJAPI

/// `setuserdetails` with just `screenname` — the Apple sign-up route's
/// post-signup username step, which runs before onboarding's gender/photo
/// steps and isn't ``OnboardingServicing``'s job (see ``OnboardingRoute``'s
/// doc comment).
protocol AppleUsernameServicing: Sendable {
	func setScreenName(
		userId: String,
		screenName: String,
		credential: APICredential,
	) async throws(AuthenticationError) -> ScreenNameUpdateOutcome
}

/// ``AppleUsernameServicing/setScreenName(userId:screenName:credential:)``'s
/// outcome.
struct ScreenNameUpdateOutcome: Equatable {
	let succeeded: Bool
	let message: String?
	/// The server's freshly issued token, when the response carried one —
	/// feed to ``SecretDJAPI/SessionStore/rotateToken(_:)``.
	let rotatedToken: String?
}
