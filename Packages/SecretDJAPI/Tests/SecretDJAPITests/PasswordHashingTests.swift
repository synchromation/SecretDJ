import Testing

@testable import SecretDJAPI

enum PasswordHashingTests {
	struct `SHA-1 hex digest` {
		/// Ported from `secretdjv3/String+Crypto.swift`'s `String.sha1()`.
		/// No legacy unit test exercises it directly, so this is pinned
		/// with the standard FIPS 180-1 known-answer vectors instead.
		@Test func `hashes the empty string to the standard SHA-1 vector`() {
			#expect(PasswordHashing.sha1Hex("") == "da39a3ee5e6b4b0d3255bfef95601890afd80709")
		}

		@Test func `hashes abc to the standard SHA-1 vector`() {
			#expect(PasswordHashing.sha1Hex("abc") == "a9993e364706816aba3e25717850c26c9cd0d89d")
		}

		@Test func `is deterministic for the same input`() {
			#expect(PasswordHashing.sha1Hex("hunter2") == PasswordHashing.sha1Hex("hunter2"))
		}
	}
}
