/// The rotating-token challenge-response credential the auth scheme signs
/// every non-exempt request with (LEGACY.md "Backend API and Spotify
/// integration" → "Auth scheme: rotating token + HMAC signature").
public struct APICredential: Sendable, Hashable {
	/// The server's latest issued token, base64-encoded — rotates on
	/// (almost) every response (S1.4 persists it).
	public let token: String
	/// The SHA-1 hex digest of the account password — the HMAC signing
	/// key, never the plaintext (see ``PasswordHashing``).
	public let passwordHash: String

	public init(token: String, passwordHash: String) {
		self.token = token
		self.passwordHash = passwordHash
	}
}
