import Foundation
import Testing

@testable import SecretDJDomain

struct LikeInfoTests {
	@Test func `decodes the server's liked flag and display copy`() throws {
		let json = Data(#"{"LikedByYou": true, "Info": "12 people buzzed this"}"#.utf8)

		let likeInfo = try JSONDecoder().decode(LikeInfo.self, from: json)

		#expect(likeInfo.likedByYou)
		#expect(likeInfo.info == "12 people buzzed this")
	}

	@Test func `missing fields default to not-liked with empty copy`() throws {
		let json = Data("{}".utf8)

		let likeInfo = try JSONDecoder().decode(LikeInfo.self, from: json)

		#expect(!likeInfo.likedByYou)
		#expect(likeInfo.info.isEmpty)
	}
}
