import Observability
import TelemetryDeck

/// Forwards analytics events to TelemetryDeck.
///
/// This is the only place the app touches the TelemetryDeck SDK. Diagnostics
/// and breadcrumbs are ignored here — they belong to the console and the
/// crash reporter — so the vendor receives exactly the typed, reviewable
/// analytics surface and nothing else.
public final class TelemetryDeckDestination: ObservabilityDestination {
	/// - Parameter appID: The TelemetryDeck app ID; initializing the
	///   destination initializes the SDK.
	public init(appID: String) {
		TelemetryDeck.initialize(config: TelemetryDeck.Config(appID: appID))
	}

	public func receive(_ event: ObservabilityEvent) {
		guard case .analytics(let payload) = event else {
			return
		}

		TelemetryDeck.signal(payload.name, parameters: payload.parameters)
	}
}
