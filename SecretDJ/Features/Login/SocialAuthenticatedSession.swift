/// The identity, new-account signal, and server-issued credential a social
/// sign-in call (`applesignin`/`facebooksignin`) returns — unlike
/// ``AuthenticatedSession``, both social sign-ins get their signing
/// credential back from the server instead of using the caller's own
/// password hash (``SecretDJAPI/LoginDetails``'s doc comment).
struct SocialAuthenticatedSession: Equatable {
	let personId: String
	let screenName: String
	/// `true` for a brand-new account (``SecretDJAPI/LoginDetails/created``).
	let created: Bool
	/// The server-issued credential to sign future requests with — this
	/// becomes the new session's ``SecretDJAPI/APICredential/passwordHash``.
	let issuedCredential: String?
	let rotatedToken: String?
}
