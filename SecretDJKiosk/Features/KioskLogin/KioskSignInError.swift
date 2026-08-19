import SecretDJAPI

/// Every way a ``KioskSignInServicing`` call can fail. Mirrors the
/// consumer's own `AuthenticationError` shape for `server`/`connection`
/// (``init(_:)`` maps ``SecretDJAPI/APIError`` identically), plus the one
/// kiosk-only outcome: a login that authenticated but isn't pinned to a
/// venue — legacy's `kSignInUnauthorisedProblemText` ("wrong type of
/// signin"), which the kiosk rejects outright rather than signing in with
/// no venue.
enum KioskSignInError: Error, Equatable {
	/// The server rejected the request; `message` is its copy, when
	/// present, and arrives already localized (D11).
	case server(message: String?)
	/// Anything before a server response — offline, timeout, a malformed
	/// reply — with no server copy to show.
	case connection
	/// The credentials authenticated, but the response carried no forced
	/// venue (`Venues.Force`) — this account isn't a venue account.
	case notAVenueAccount

	init(_ apiError: APIError) {
		if case .server(let message) = apiError {
			self = .server(message: message)
		} else {
			self = .connection
		}
	}
}
