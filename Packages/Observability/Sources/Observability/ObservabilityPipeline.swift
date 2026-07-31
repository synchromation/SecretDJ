/// The single entry point the app emits observability events into.
///
/// Features never talk to logging, crash-reporting, or analytics SDKs
/// directly — they emit semantic events here, and the destinations configured
/// at the composition root fan them out. Models take a pipeline in their
/// initializer, defaulting to ``disabled`` so tests and previews stay silent
/// unless they inject a ``RecordingDestination``.
public final class ObservabilityPipeline: Sendable {
	/// A pipeline with no destinations — the null object for previews and
	/// tests that don't observe instrumentation.
	public static let disabled = ObservabilityPipeline(destinations: [])

	private let destinations: [any ObservabilityDestination]

	public init(destinations: [any ObservabilityDestination]) {
		self.destinations = destinations
	}

	/// Records a leveled diagnostic message under a category (usually the
	/// feature name).
	public func log(_ level: DiagnosticLevel, _ message: String, category: String) {
		emit(.diagnostic(Diagnostic(level: level, message: message, category: category)))
	}

	/// Records a non-fatal error at ``DiagnosticLevel/error``.
	public func report(_ error: any Error, category: String) {
		log(.error, String(describing: error), category: category)
	}

	/// Records that a screen became visible.
	public func screen(_ name: String) {
		emit(.breadcrumb(Breadcrumb(kind: .screen(name: name))))
	}

	/// Records a meaningful user action, named for its intention.
	public func interaction(_ description: String) {
		emit(.breadcrumb(Breadcrumb(kind: .interaction(description: description))))
	}

	/// Records a completed network call; pass nil `statusCode`/`duration`
	/// when the call never reached a response.
	public func network(method: String, path: String, statusCode: Int? = nil, duration: Duration? = nil) {
		let call = Breadcrumb.Kind.network(method: method, path: path, statusCode: statusCode, duration: duration)

		emit(.breadcrumb(Breadcrumb(kind: call)))
	}

	/// Sends a typed analytics event.
	public func track(_ event: some AnalyticsEvent) {
		emit(.analytics(AnalyticsPayload(name: event.name, parameters: event.parameters)))
	}

	private func emit(_ event: ObservabilityEvent) {
		for destination in destinations {
			destination.receive(event)
		}
	}
}
