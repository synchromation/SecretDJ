/// The identity and rotated token a successful `signin` or `createuser`
/// call returns — enough to build a ``SecretDJAPI/SessionUser`` and
/// ``SecretDJAPI/APICredential`` (the credential's password hash is the
/// caller's own SHA-1 digest, never part of the response — see
/// ``SecretDJAPI/LoginDetails``'s doc comment).
struct AuthenticatedSession: Equatable {
	let personId: String
	let screenName: String
	/// The server's freshly issued token, when the response carried one
	/// (``SecretDJAPI/APIResponse/rotatedToken``).
	let rotatedToken: String?
}
