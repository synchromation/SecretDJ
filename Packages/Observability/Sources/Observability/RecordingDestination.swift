import Synchronization

/// Captures events in memory so tests can assert on instrumentation.
public final class RecordingDestination: ObservabilityDestination {
	private let recorded = Mutex<[ObservabilityEvent]>([])

	public init() {}

	/// Every event received, in emission order.
	public var events: [ObservabilityEvent] {
		recorded.withLock(\.self)
	}

	/// Just the breadcrumb kinds, for trail assertions.
	public var breadcrumbs: [Breadcrumb.Kind] {
		events.compactMap { event in
			guard case .breadcrumb(let breadcrumb) = event else {
				return nil
			}

			return breadcrumb.kind
		}
	}

	/// Just the analytics payloads, for tracking assertions.
	public var analytics: [AnalyticsPayload] {
		events.compactMap { event in
			guard case .analytics(let payload) = event else {
				return nil
			}

			return payload
		}
	}

	public func receive(_ event: ObservabilityEvent) {
		recorded.withLock { $0.append(event) }
	}
}
