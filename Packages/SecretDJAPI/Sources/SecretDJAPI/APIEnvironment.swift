import Foundation

/// The backend deployment an API request targets.
public enum APIEnvironment: Sendable {
	/// The live production backend all real accounts and venues use.
	case production

	/// No staging or sandbox backend has been confirmed to exist, so this
	/// case's base URL is a deliberately-invalid placeholder pending
	/// confirmation from the backend team.
	case staging

	/// The base URL every request in this environment is built against.
	public var baseURL: URL {
		switch self {
		case .production:
			Self.url("https://api4.secretdj.com")

		case .staging:
			Self.url("https://staging.secretdj.invalid")
		}
	}

	private static func url(_ string: String) -> URL {
		guard let url = URL(string: string) else {
			preconditionFailure("Invalid static base URL literal: \(string)")
		}

		return url
	}
}
