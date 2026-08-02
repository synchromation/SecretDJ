import Observability
import Sentry

/// Forwards diagnostics and breadcrumbs to Sentry.
///
/// This is the only place the app touches the Sentry SDK. The routing policy
/// (observability skill) lives in `receive(_:)`:
///
/// - Screen, interaction, and network breadcrumbs — and notice/warning
///   diagnostics — become Sentry breadcrumbs: invisible on their own, they
///   are attached as the trail on any later error or crash, never standalone
///   issues.
/// - Error and critical diagnostics are captured as Sentry events, carrying
///   the accumulated trail.
/// - Debug/info diagnostics and analytics events are not Sentry's business.
///
/// Automatic instrumentation is disabled: this app breadcrumbs explicitly,
/// so the trail Sentry shows is exactly the trail in Xcode's console.
public final class SentryDestination: ObservabilityDestination {
	/// - Parameter dsn: The Sentry project DSN; initializing the destination
	///   starts the SDK (crash handling included) with swizzling disabled.
	public init(dsn: String) {
		SentrySDK.start { options in
			options.dsn = dsn
			options.enableSwizzling = false
		}
	}

	public func receive(_ event: ObservabilityEvent) {
		switch event {
		case .diagnostic(let diagnostic):
			forward(diagnostic)
		case .breadcrumb(let breadcrumb):
			SentrySDK.addBreadcrumb(sentryBreadcrumb(for: breadcrumb))
		case .analytics:
			break
		}
	}

	private func forward(_ diagnostic: Diagnostic) {
		switch diagnostic.level {
		case .debug,
		     .info:
			break
		case .notice,
		     .warning:
			SentrySDK.addBreadcrumb(sentryBreadcrumb(for: diagnostic))
		case .error,
		     .critical:
			capture(diagnostic)
		}
	}

	private func capture(_ diagnostic: Diagnostic) {
		let event = Event(level: diagnostic.level == .critical ? .fatal : .error)
		event.message = SentryMessage(formatted: diagnostic.message)
		event.logger = diagnostic.category

		SentrySDK.capture(event: event)
	}

	private func sentryBreadcrumb(for diagnostic: Diagnostic) -> Sentry.Breadcrumb {
		let crumb = Sentry.Breadcrumb(
			level: diagnostic.level == .warning ? .warning : .info,
			category: diagnostic.category,
		)
		crumb.message = diagnostic.message

		return crumb
	}

	private func sentryBreadcrumb(for breadcrumb: Observability.Breadcrumb) -> Sentry.Breadcrumb {
		switch breadcrumb.kind {
		case .screen(let name):
			let crumb = Sentry.Breadcrumb(level: .info, category: "screen")
			crumb.type = "navigation"
			crumb.message = name

			return crumb
		case .interaction(let description):
			let crumb = Sentry.Breadcrumb(level: .info, category: "interaction")
			crumb.type = "user"
			crumb.message = description

			return crumb
		case .network(let method, let path, let statusCode, let duration):
			let crumb = Sentry.Breadcrumb(level: .info, category: "network")
			crumb.type = "http"
			crumb.data = [
				"method": method,
				"url": path,
				"status_code": statusCode.map(String.init) ?? "none",
				"duration": duration.map { String(describing: $0) } ?? "none",
			]

			return crumb
		}
	}
}
