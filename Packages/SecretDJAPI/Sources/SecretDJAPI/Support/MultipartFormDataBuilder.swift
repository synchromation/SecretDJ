import Foundation

/// Builds a `multipart/form-data` body byte-for-byte like the legacy
/// client's image-upload path (`secretdjv3/PostRequestProvider.swift`'s
/// `imageRequestBody`): each field as `--boundary\r\nContent-Disposition:
/// form-data; name="<key>"\r\n\r\n<value>\r\n`, then one file part with a
/// `filename`/`Content-Type`, closed by `--boundary--\r\n`. Field order
/// isn't part of the wire contract — the legacy body iterates a
/// `[String: Any]` dictionary, whose order Swift never guarantees — so this
/// builder sorts by key instead, for deterministic, testable output.
struct MultipartFormDataBuilder {
	let boundary: String

	init(boundary: String = "Boundary-\(UUID().uuidString)") {
		self.boundary = boundary
	}

	var contentType: String {
		"multipart/form-data; boundary=\(boundary)"
	}

	func body(
		fields: [String: String],
		fileFieldName: String,
		filename: String,
		mimeType: String,
		fileData: Data,
	) -> Data {
		var body = Data()
		for key in fields.keys.sorted() {
			body.appendMultipartString("--\(boundary)\r\n")
			body.appendMultipartString("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
			body.appendMultipartString("\(fields[key] ?? "")\r\n")
		}

		body.appendMultipartString("--\(boundary)\r\n")
		body.appendMultipartString(
			"Content-Disposition: form-data; name=\"\(fileFieldName)\"; filename=\"\(filename)\"\r\n",
		)
		body.appendMultipartString("Content-Type: \(mimeType)\r\n\r\n")
		body.append(fileData)
		body.appendMultipartString("\r\n")
		body.appendMultipartString("--\(boundary)--\r\n")

		return body
	}
}

extension Data {
	fileprivate mutating func appendMultipartString(_ string: String) {
		append(Data(string.utf8))
	}
}
