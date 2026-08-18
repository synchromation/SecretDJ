/// Hashes a plaintext password into the SHA-1 hex digest the wire format
/// sends as `password` on sign-in/sign-up, and that seeds
/// ``APICredential/passwordHash`` for request signing.
///
/// Ported from `secretdjv3/String+Crypto.swift`'s `String.sha1()`. SHA-1 is
/// a wire-compatibility requirement (D7), not a security choice — changing
/// it is a coordinated server-side change, not a client one.
public enum PasswordHashing {
	public static func sha1Hex(_ password: String) -> String {
		SecretDJAPI.sha1Hex(password)
	}
}
