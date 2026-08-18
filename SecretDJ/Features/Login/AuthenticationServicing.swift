import SecretDJDomain

/// The auth calls the Login feature's models need, thinned from
/// ``SecretDJAPI/APIClient`` to this feature's exact surface so
/// ``LoginModel``/``SignUpModel``/``ForgottenPasswordModel`` are testable
/// without networking (ios-architecture: a protocol seam per real
/// dependency).
protocol AuthenticationServicing: Sendable {
	/// `signin` — screen name plus the already-hashed password.
	func signIn(screenName: String, passwordHash: String) async throws(AuthenticationError) -> AuthenticatedSession

	/// `createuser` — every sign-up field plus the already-hashed password.
	func createUser(
		firstName: String,
		lastName: String,
		gender: Gender,
		email: String,
		screenName: String,
		passwordHash: String,
	) async throws(AuthenticationError) -> AuthenticatedSession

	/// `resetpassword` by screen name.
	func resetPassword(screenName: String) async throws(AuthenticationError) -> PasswordResetOutcome

	/// `resetpassword` by email.
	func resetPassword(email: String) async throws(AuthenticationError) -> PasswordResetOutcome
}
