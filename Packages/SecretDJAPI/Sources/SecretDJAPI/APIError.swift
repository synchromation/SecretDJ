/// Every way an ``APIClient`` call can fail, transport and envelope errors
/// alike.
public enum APIError: Error, Sendable {
	/// Signing was required but no ``APICredential`` was supplied — mirrors
	/// the legacy client's sig-exclusion list (LEGACY.md "Backend API and
	/// Spotify integration" → auth scheme).
	case missingCredential
	/// The assembled endpoint and parameters could not form a valid URL.
	case requestGeneration
	/// The underlying transport (`URLSession`) failed — offline, timeout,
	/// TLS, cancellation, etc.
	case transport(any Error)
	/// The response body was not the expected JSON shape.
	case decoding(any Error)
	/// The envelope decoded with `Success == false`; `message` is the
	/// server's copy, when present.
	case server(message: String?)
}

extension APIError: CustomStringConvertible {
	/// A description safe to hand to `ObservabilityPipeline.report(_:category:)`,
	/// which logs errors via `String(describing:)` (observability skill).
	/// Every signed endpoint call carries its credentials/token as URL query
	/// parameters (``APIRequestBuilder``), and both `URLSession` (on
	/// ``transport``) and `JSONDecoder` (on ``decoding``, via a corrupted
	/// value's debug description) can embed arbitrary request content in
	/// their default, reflection-based description — so those two cases drop
	/// their associated error entirely here, the same way every caller that
	/// collapses ``APIError`` into its own feature-local error type already
	/// discards them (mapping both to a bare `.connection` case). `message`
	/// is left as the server sent it: display copy about this request's own
	/// outcome, not request content this type generated.
	public var description: String {
		switch self {
		case .missingCredential: "missingCredential"
		case .requestGeneration: "requestGeneration"
		case .transport: "transport"
		case .decoding: "decoding"
		case .server(let message): "server(message: \(message ?? "nil"))"
		}
	}
}
