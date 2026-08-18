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
