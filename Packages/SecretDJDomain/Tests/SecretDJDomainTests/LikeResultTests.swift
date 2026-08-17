import Foundation
import Testing

@testable import SecretDJDomain

struct LikeResultTests {
	@Test func `decodes the server's toast copy and the new liked state`() throws {
		let json = Data(
			"""
			{"Text": "You buzzed this", "Url": "", "LikeInfo": {"LikedByYou": true}}
			""".utf8,
		)

		let result = try JSONDecoder().decode(LikeResult.self, from: json)

		#expect(result.message == "You buzzed this")
		#expect(result.url.isEmpty)
		#expect(result.isLikedByYou)
	}

	struct `Malformed responses` {
		@Test func `a missing LikeInfo fails to decode`() {
			let json = Data(#"{"Text": "You buzzed this", "Url": ""}"#.utf8)

			#expect(throws: (any Error).self) {
				try JSONDecoder().decode(LikeResult.self, from: json)
			}
		}

		@Test func `a missing Url fails to decode`() {
			let json = Data(#"{"Text": "You buzzed this", "LikeInfo": {"LikedByYou": true}}"#.utf8)

			#expect(throws: (any Error).self) {
				try JSONDecoder().decode(LikeResult.self, from: json)
			}
		}
	}
}
