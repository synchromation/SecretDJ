import Foundation
import Testing

@testable import SecretDJAPI

enum APIEnvelopeHeaderTests {
	struct `Decoding the envelope's constant fields` {
		/// `secretdjv3/NetworkResponseParser.swift`.
		@Test func `reads a successful envelope with a rotated token`() throws {
			let json = Data(
				"""
				{"Success": true, "Message": "", "Token": "kne6cciXUgQTWfBIHhzqNkjlVpE="}
				""".utf8,
			)

			let header = try JSONDecoder().decode(APIEnvelopeHeader.self, from: json)

			#expect(header.isSuccess)
			#expect(header.token == "kne6cciXUgQTWfBIHhzqNkjlVpE=")
		}

		/// Modeled on `secret-dj-ios-old/SecretDJTests/PasswordChangeFail.json`.
		@Test func `reads a failure envelope's server message`() throws {
			let json = Data(
				"""
				{"Success": false, "Message": "Sorry, that screen name is taken."}
				""".utf8,
			)

			let header = try JSONDecoder().decode(APIEnvelopeHeader.self, from: json)

			#expect(!header.isSuccess)
			#expect(header.message == "Sorry, that screen name is taken.")
		}

		@Test func `a missing Token decodes to nil`() throws {
			let json = Data(#"{"Success": true, "Message": ""}"#.utf8)

			let header = try JSONDecoder().decode(APIEnvelopeHeader.self, from: json)

			#expect(header.token == nil)
		}

		@Test func `ignores sibling body fields such as Response or Sections`() throws {
			let json = Data(
				"""
				{"Success": true, "Token": "x", "Response": {"Text": "hi", "ReturnCode": 0}}
				""".utf8,
			)

			let header = try JSONDecoder().decode(APIEnvelopeHeader.self, from: json)

			#expect(header.isSuccess)
		}
	}
}
