import Foundation
import Testing

/// Percent-encoded name→value pairs, read without decoding — the same
/// technique `APIRequestBuilderTests` uses, shared here for the endpoint
/// suites that need to inspect a captured ``RequestRecorder`` request.
func percentEncodedParameters(of request: URLRequest) throws -> [String: String] {
	let url = try #require(request.url)
	let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
	let items = components.percentEncodedQueryItems ?? []
	return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
}

/// A multipart request's body, decoded as UTF-8 text (the JPEG bytes inside
/// an avatar-upload body won't round-trip cleanly, but the surrounding
/// `Content-Disposition`/field text — what these tests assert on — does).
func bodyText(of request: URLRequest) throws -> String {
	let body = try #require(request.httpBody)
	return try #require(String(bytes: body, encoding: .utf8))
}
