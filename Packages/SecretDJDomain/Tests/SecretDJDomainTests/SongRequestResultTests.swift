import Testing

@testable import SecretDJDomain

struct SongRequestResultTests {
	@Test func `return code zero is success, carrying the server's message and URL`() {
		let result = SongRequestResult(returnCode: 0, message: "Queued!", url: "https://example.com", imageSize: 0)

		#expect(result == .success(message: "Queued!", url: "https://example.com"))
	}

	struct `Out of credits (business rule 5)` {
		@Test func `return code -8 with a profile picture offers the top-up screen`() {
			let result = SongRequestResult(returnCode: -8, message: nil, url: nil, imageSize: 640)

			#expect(result == .outOfCredits(hasProfilePicture: true))
		}

		@Test func `return code -8 with no profile picture offers the pic-for-credits upsell`() {
			let result = SongRequestResult(returnCode: -8, message: nil, url: nil, imageSize: 0)

			#expect(result == .outOfCredits(hasProfilePicture: false))
		}
	}

	struct `Any other non-zero code` {
		@Test func `is a failure carrying the server's message`() {
			let result = SongRequestResult(returnCode: -1, message: "Song unavailable", url: nil, imageSize: 0)

			#expect(result == .failure(message: "Song unavailable"))
		}

		@Test func `falls back to an empty message when the server sends none`() {
			let result = SongRequestResult(returnCode: -1, message: nil, url: nil, imageSize: 0)

			#expect(result == .failure(message: ""))
		}
	}
}
