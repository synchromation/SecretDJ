/// How serious a diagnostic message is; higher levels are more severe.
public enum DiagnosticLevel: Int, Comparable, Sendable {
	/// Detail useful only while actively working on the emitting code.
	case debug

	/// Routine happenings worth having in a log, with no action needed.
	case info

	/// Notable-but-expected events, such as a fallback path being taken.
	case notice

	/// Something is degraded or unexpected, but the app can carry on.
	case warning

	/// An operation failed; the user may have noticed.
	case error

	/// The app is in a state where continuing correctly is doubtful.
	case critical

	public static func < (lhs: Self, rhs: Self) -> Bool {
		lhs.rawValue < rhs.rawValue
	}
}

/// A leveled log message attributed to a category (usually a feature name).
public struct Diagnostic: Equatable, Sendable {
	public let level: DiagnosticLevel
	public let message: String
	public let category: String

	public init(level: DiagnosticLevel, message: String, category: String) {
		self.level = level
		self.message = message
		self.category = category
	}
}

/// One step in the trail of what happened before an error or crash.
public struct Breadcrumb: Equatable, Sendable {
	public enum Kind: Equatable, Sendable {
		/// A screen became visible to the user.
		case screen(name: String)

		/// The user performed a meaningful action, described by the
		/// intention it expresses ("increment"), never by gesture mechanics.
		case interaction(description: String)

		/// A network call completed; `statusCode` and `duration` are nil
		/// when the call never reached a response.
		case network(method: String, path: String, statusCode: Int?, duration: Duration?)
	}

	public let kind: Kind

	public init(kind: Kind) {
		self.kind = kind
	}
}

/// An analytics event flattened to the wire shape every vendor understands.
public struct AnalyticsPayload: Equatable, Sendable {
	public let name: String
	public let parameters: [String: String]

	public init(name: String, parameters: [String: String]) {
		self.name = name
		self.parameters = parameters
	}
}

/// Everything that can flow through the pipeline, as one routable value.
public enum ObservabilityEvent: Equatable, Sendable {
	case diagnostic(Diagnostic)
	case breadcrumb(Breadcrumb)
	case analytics(AnalyticsPayload)
}
