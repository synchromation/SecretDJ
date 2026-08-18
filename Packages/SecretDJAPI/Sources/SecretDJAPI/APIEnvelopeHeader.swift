/// The constant fields every Secret DJ API response carries, decoded
/// independently of the response's variable body (`Sections` for feeds,
/// `Response` for action endpoints, or endpoint-specific fields like
/// `User`/`Param`) — LEGACY.md "Backend API and Spotify integration" →
/// "Response envelope and retry"; ported from
/// `secretdjv3/NetworkResponseParser.swift`.
public struct APIEnvelopeHeader: Sendable, Hashable, Decodable {
	public let isSuccess: Bool
	public let message: String?
	/// The server's rotated token, present on (almost) every response.
	/// `nil` (or, on the wire, empty) means the caller's existing token is
	/// still valid — S1.4 persists whichever value the caller should keep.
	public let token: String?

	private enum CodingKeys: String, CodingKey {
		case isSuccess = "Success"
		case message = "Message"
		case token = "Token"
	}
}
