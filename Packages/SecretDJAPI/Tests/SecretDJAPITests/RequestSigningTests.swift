import Testing

@testable import SecretDJAPI

enum RequestSigningTests {
	struct `HMAC-SHA1 signature` {
		/// Pinned from `SecretDJTests/SignatureProviderTests.swift`'s
		/// `testGeneratesSig`.
		@Test func `matches the legacy SignatureProviderTests fixture`() {
			let signer = HMACSHA1RequestSigner()

			let signature = signer.signature(
				token: "kPV0J8Q+DVABopusWMnQkc6kldY=",
				passwordHash: "889101801761492e1a2140d491c4235a1798e284",
			)

			#expect(signature == "aT2uJ/sUIn/14v1XhnrlZzJgYL8=")
		}

		/// A second known-answer pair, pinned from
		/// `SecretDJTests/HmacTests.swift`'s `testHmac`, proving the
		/// algorithm is ported precisely rather than fitted to one case.
		@Test func `matches the legacy HmacTests fixture`() {
			let signer = HMACSHA1RequestSigner()

			let signature = signer.signature(
				token: "SBqYZt5tFDkHMXfuT+u5BwhZZIE=",
				passwordHash: "f46278212c65661b70de203687118f005b67629e",
			)

			#expect(signature == "s5EDqcLl4XuJ0P8WpGOfPhy2API=")
		}

		@Test func `an undecodable base64 token yields an empty signature`() {
			let signer = HMACSHA1RequestSigner()

			let signature = signer.signature(token: "not valid base64!!", passwordHash: "irrelevant")

			#expect(signature.isEmpty)
		}
	}
}
