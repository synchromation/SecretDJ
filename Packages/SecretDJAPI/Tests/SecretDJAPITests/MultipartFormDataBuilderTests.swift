import Foundation
import Testing

@testable import SecretDJAPI

enum MultipartFormDataBuilderTests {
	struct `Body construction` {
		/// Byte-for-byte against `secretdjv3/PostRequestProvider.swift`'s
		/// `imageRequestBody`: one field, then the file part, then the closing
		/// boundary — no extra trailing blank line (that only appears in
		/// `PostRequestProvider`'s non-image `requestBody`, used by
		/// `topupnotify`, out of scope here).
		@Test func `matches the legacy image-upload body layout exactly`() {
			let builder = MultipartFormDataBuilder(boundary: "TESTBOUNDARY")

			let body = builder.body(
				fields: ["user": "00000087_feae54c9"],
				fileFieldName: "avatarfile",
				filename: "avatar.jpg",
				mimeType: "image/jpeg",
				fileData: Data("fake-jpeg-bytes".utf8),
			)

			let expected = Data(
				[
					"--TESTBOUNDARY\r\n",
					"Content-Disposition: form-data; name=\"user\"\r\n\r\n",
					"00000087_feae54c9\r\n",
					"--TESTBOUNDARY\r\n",
					"Content-Disposition: form-data; name=\"avatarfile\"; filename=\"avatar.jpg\"\r\n",
					"Content-Type: image/jpeg\r\n\r\n",
				].joined().utf8,
			) + Data("fake-jpeg-bytes".utf8) + Data("\r\n--TESTBOUNDARY--\r\n".utf8)

			#expect(body == expected)
		}

		@Test func `orders multiple fields deterministically by key`() throws {
			let builder = MultipartFormDataBuilder(boundary: "B")

			let body = builder.body(
				fields: ["user": "u1", "sig": "s1"],
				fileFieldName: "avatarfile",
				filename: "avatar.jpg",
				mimeType: "image/jpeg",
				fileData: Data(),
			)
			let text = try #require(String(bytes: body, encoding: .utf8))

			let sigRange = try #require(text.range(of: "name=\"sig\""))
			let userRange = try #require(text.range(of: "name=\"user\""))
			#expect(sigRange.lowerBound < userRange.lowerBound)
		}

		@Test func `carries the file bytes verbatim, uninterpreted`() {
			let builder = MultipartFormDataBuilder(boundary: "B")
			let imageBytes = Data([0xFF, 0xD8, 0xFF, 0x00, 0x01, 0x02])

			let body = builder.body(
				fields: [:],
				fileFieldName: "avatarfile",
				filename: "avatar.jpg",
				mimeType: "image/jpeg",
				fileData: imageBytes,
			)

			let header = Data(
				[
					"--B\r\n",
					"Content-Disposition: form-data; name=\"avatarfile\"; filename=\"avatar.jpg\"\r\n",
					"Content-Type: image/jpeg\r\n\r\n",
				].joined().utf8,
			)
			let footer = Data("\r\n--B--\r\n".utf8)
			#expect(body == header + imageBytes + footer)
		}
	}

	struct `Content-Type header` {
		@Test func `embeds the boundary`() {
			let builder = MultipartFormDataBuilder(boundary: "XYZ")

			#expect(builder.contentType == "multipart/form-data; boundary=XYZ")
		}

		@Test func `defaults to a fresh boundary each time when none is supplied`() {
			let first = MultipartFormDataBuilder()
			let second = MultipartFormDataBuilder()

			#expect(first.boundary != second.boundary)
		}
	}
}
