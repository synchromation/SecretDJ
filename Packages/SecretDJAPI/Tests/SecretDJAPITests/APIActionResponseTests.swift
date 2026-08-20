import Foundation
import Testing

@testable import SecretDJAPI

enum APIActionResponseTests {
	struct `Decoding the Response object` {
		/// Shape matches `secret-dj-ios-old/SecretDJTests/ChangeMood.json`
		/// (no `Url` field).
		@Test func `reads Text and ReturnCode when Url is absent`() throws {
			let json = Data(
				"""
				{"Text": "We got your request", "ReturnCode": 0}
				""".utf8,
			)

			let response = try JSONDecoder().decode(APIActionResponse.self, from: json)

			#expect(response.text == "We got your request")
			#expect(response.url == nil)
			#expect(response.returnCode == 0)
		}

		@Test func `reads Url when present`() throws {
			let json = Data(
				"""
				{"Text": "Thanks!", "Url": "https://example.com/reward", "ReturnCode": 0}
				""".utf8,
			)

			let response = try JSONDecoder().decode(APIActionResponse.self, from: json)

			#expect(response.url == "https://example.com/reward")
		}

		/// `SongRequestResult.outOfCreditsReturnCode` in SecretDJDomain.
		@Test func `reads a negative ReturnCode such as the out-of-credits code`() throws {
			let json = Data(#"{"ReturnCode": -8}"#.utf8)

			let response = try JSONDecoder().decode(APIActionResponse.self, from: json)

			#expect(response.returnCode == -8)
		}

		/// The rich-toast `Data` field (S8.6, LEGACY.md "Toasts") — see
		/// ``SecretDJDomain/RichToastData``'s own LIVE-CAPTURE doc comment.
		@Test func `reads a Data payload as a rich toast`() throws {
			let json = Data(#"{"ReturnCode": 0, "Data": {"Title": "Reward!"}}"#.utf8)

			let response = try JSONDecoder().decode(APIActionResponse.self, from: json)

			#expect(response.data?.title == "Reward!")
		}

		@Test func `a missing Data field decodes to no rich toast`() throws {
			let json = Data(#"{"ReturnCode": 0}"#.utf8)

			let response = try JSONDecoder().decode(APIActionResponse.self, from: json)

			#expect(response.data == nil)
		}
	}

	struct `Decoding the whole action envelope` {
		/// Modeled on `secret-dj-ios-old/SecretDJTests/ChangeMood.json`'s
		/// full shape.
		@Test func `reads a nested Response object under its top-level key`() throws {
			let json = Data(
				"""
				{
				  "Response": {"Text": "We got your request", "ReturnCode": 0},
				  "Success": true,
				  "Token": "EYJZ0cLNUpg5HIBvj1qWQ6uhxfQ="
				}
				""".utf8,
			)

			let payload = try JSONDecoder().decode(APIActionPayload.self, from: json)

			#expect(payload.response.text == "We got your request")
			#expect(payload.response.returnCode == 0)
		}
	}

	struct `Decoding an empty payload` {
		@Test func `decodes successfully regardless of extra sibling fields`() throws {
			let json = Data(#"{"Success": true, "Token": "abc"}"#.utf8)

			_ = try JSONDecoder().decode(EmptyAPIPayload.self, from: json)
		}
	}
}
