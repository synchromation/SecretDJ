import SecretDJDomain

/// The `Response` object action endpoints (`checkin`, `like`/`unlike`,
/// `requestsong`, `machinecontrol`, ...) nest inside the envelope:
/// free-text confirmation copy, an optional hand-off URL, an optional
/// award-style rich-toast payload, and a numeric `ReturnCode` whose meaning
/// is endpoint-specific (LEGACY.md "Backend API and Spotify integration" →
/// "Response envelope and retry" + endpoint catalog).
///
/// `data`'s shape (S8.6) is ``SecretDJDomain/RichToastData`` — see that
/// type's own doc comment for which endpoints actually send it (`checkin`,
/// `requestsong`; never `like`/`unlike`) and its LIVE-CAPTURE citation.
public struct APIActionResponse: Sendable, Hashable, Decodable {
	public let text: String?
	public let url: String?
	public let returnCode: Int
	public let data: RichToastData?

	private enum CodingKeys: String, CodingKey {
		case text = "Text"
		case url = "Url"
		case returnCode = "ReturnCode"
		case data = "Data"
	}
}

/// Convenience payload for the many action endpoints whose entire response
/// body is a single top-level `Response` object.
public struct APIActionPayload: Sendable, Hashable, Decodable {
	public let response: APIActionResponse

	private enum CodingKeys: String, CodingKey {
		case response = "Response"
	}
}

/// A payload for endpoints whose body carries nothing beyond the envelope
/// (fire-and-forget calls like `promote`).
public struct EmptyAPIPayload: Sendable, Hashable, Decodable {
	public init() {}
}
