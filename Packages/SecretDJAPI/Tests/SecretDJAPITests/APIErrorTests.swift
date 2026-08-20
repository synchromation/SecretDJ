import Foundation
import Testing

@testable import SecretDJAPI

/// ``APIError/description`` is what `ObservabilityPipeline.report(_:category:)`
/// logs via `String(describing:)` (observability skill: "never rely on...
/// redact at the emission call site"). Every endpoint call signs its
/// request with credentials/tokens as URL query parameters
/// (``APIRequestBuilder``), and `URLSession` attaches the failing URL to a
/// transport error's `userInfo` — so the default, reflection-based
/// description of `.transport`/`.decoding` would otherwise embed that whole
/// signed URL in logs and crash reports. These tests pin a description
/// that never does.
enum APIErrorTests {
	struct `Transport and decoding failures` {
		@Test func `a transport failure's description never contains the failing request's URL`() throws {
			let signedInURL = try #require(URL(
				string: "https://api.secretdj.com/signin?email=jane%40example.com&password=hunter2&sig=abc123",
			))
			let underlying = URLError(
				.notConnectedToInternet,
				userInfo: [
					NSURLErrorFailingURLErrorKey: signedInURL,
					NSLocalizedDescriptionKey: "The Internet connection appears to be offline.",
				],
			)

			let description = String(describing: APIError.transport(underlying))

			#expect(!description.contains("jane@example.com"))
			#expect(!description.contains("hunter2"))
			#expect(!description.contains("sig=abc123"))
			#expect(!description.contains("secretdj.com"))
		}

		@Test func `a decoding failure's description never contains the underlying error's content`() {
			let underlying = DecodingError.dataCorrupted(
				DecodingError.Context(codingPath: [], debugDescription: "jane@example.com was unexpected"),
			)

			let description = String(describing: APIError.decoding(underlying))

			#expect(!description.contains("jane@example.com"))
		}
	}

	struct `Every other case` {
		@Test func `missingCredential describes itself plainly`() {
			#expect(String(describing: APIError.missingCredential) == "missingCredential")
		}

		@Test func `requestGeneration describes itself plainly`() {
			#expect(String(describing: APIError.requestGeneration) == "requestGeneration")
		}

		@Test func `server keeps the server's own message, the only content the API didn't originate`() {
			let description = String(describing: APIError.server(message: "Wrong password."))

			#expect(description.contains("Wrong password."))
		}
	}
}
