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

	/// `applesignin`. `auth` is the caller's pre-computed day-of-year digest
	/// (``SecretDJAPI/AppleSignInAuthDigest``); `firstName`/`lastName`/`email`
	/// travel together only on Apple's first authorization for this account
	/// (``SecretDJAPI/APIClient/appleSignIn(appleUserId:auth:firstName:lastName:email:)``'s
	/// doc comment).
	func appleSignIn(
		appleUserId: String,
		auth: String,
		firstName: String?,
		lastName: String?,
		email: String?,
	) async throws(AuthenticationError) -> AppleAuthenticatedSession
}
