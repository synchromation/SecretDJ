import Foundation
import OSLog
import Synchronization

/// Writes every event to the unified logging system, so the full stream —
/// diagnostics, breadcrumbs, and analytics — is visible live in Xcode's
/// debug console (filterable by category and level) and in Console.app.
public final class ConsoleDestination: ObservabilityDestination {
	private static let breadcrumbsCategory = "Breadcrumbs"
	private static let analyticsCategory = "Analytics"

	private let subsystem: String
	private let loggersByCategory = Mutex<[String: Logger]>([:])

	/// - Parameter subsystem: The unified-logging subsystem; defaults to the
	///   main bundle identifier.
	public init(subsystem: String = Bundle.main.bundleIdentifier ?? "app") {
		self.subsystem = subsystem
	}

	public func receive(_ event: ObservabilityEvent) {
		switch event {
		case .diagnostic(let diagnostic):
			log(diagnostic)
		case .breadcrumb(let breadcrumb):
			logger(category: Self.breadcrumbsCategory).log("\(breadcrumb.summary, privacy: .public)")
		case .analytics(let payload):
			logger(category: Self.analyticsCategory).log("\(payload.summary, privacy: .public)")
		}
	}

	private func log(_ diagnostic: Diagnostic) {
		let logger = logger(category: diagnostic.category)

		logger.log(
			level: diagnostic.level.logType,
			"[\(diagnostic.level.label, privacy: .public)] \(diagnostic.message, privacy: .public)",
		)
	}

	private func logger(category: String) -> Logger {
		loggersByCategory.withLock { loggers in
			if let logger = loggers[category] {
				return logger
			}

			let logger = Logger(subsystem: subsystem, category: category)
			loggers[category] = logger

			return logger
		}
	}
}

extension DiagnosticLevel {
	/// The closest unified-logging type; `warning` maps to `.error` so it
	/// stands out in Xcode — the `label` in the message keeps the levels
	/// distinguishable.
	fileprivate var logType: OSLogType {
		switch self {
		case .debug: .debug
		case .info: .info
		case .notice: .default
		case .warning: .error
		case .error: .error
		case .critical: .fault
		}
	}

	fileprivate var label: String {
		String(describing: self)
	}
}

extension Breadcrumb {
	fileprivate var summary: String {
		switch kind {
		case .screen(let name):
			"screen → \(name)"
		case .interaction(let description):
			"interaction → \(description)"
		case .network(let method, let path, let statusCode, let duration):
			[
				"\(method) \(path)",
				statusCode.map { "→ \($0)" },
				duration.map { "(\($0))" },
			]
			.compactMap(\.self)
			.joined(separator: " ")
		}
	}
}

extension AnalyticsPayload {
	fileprivate var summary: String {
		parameters.isEmpty
			? "event → \(name)"
			: "event → \(name) \(parameters)"
	}
}
