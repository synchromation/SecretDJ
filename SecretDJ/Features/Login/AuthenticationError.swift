import SecretDJAPI

/// Every way an ``AuthenticationServicing`` call can fail, collapsed from
/// ``APIError`` to the two outcomes the Login feature's models act on.
enum AuthenticationError: Error, Equatable {
	/// The server rejected the request; `message` is its copy, when
	/// present, and arrives already localized (D11).
	case server(message: String?)
	/// Anything before a server response — offline, timeout, a malformed
	/// reply — with no server copy to show.
	case connection

	init(_ apiError: APIError) {
		if case .server(let message) = apiError {
			self = .server(message: message)
		} else {
			self = .connection
		}
	}
}
