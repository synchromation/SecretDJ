import Observability
import ObservabilitySentry
import ObservabilityTelemetryDeck
import SwiftUI

@main
struct ExampleApp: App {
	@State private var counterModel = CounterModel(
		store: UserDefaultsCounterStore(),
		observability: .live,
	)

	var body: some Scene {
		WindowGroup {
			CounterView(model: counterModel)
				.environment(\.observability, .live)
		}
	}
}

extension ObservabilityPipeline {
	/// The app's observability configuration, built once at the composition
	/// root. The console destination is always on, so diagnostics,
	/// breadcrumbs, and analytics all appear in Xcode's debug console;
	/// vendor destinations (TelemetryDeck, a crash reporter) are appended
	/// here — and only here — for release builds.
	static let live: ObservabilityPipeline = {
		var destinations: [any ObservabilityDestination] = [ConsoleDestination()]

		#if !DEBUG
			destinations.append(SentryDestination(dsn: SentryConfiguration.dsn))
			destinations.append(TelemetryDeckDestination(appID: TelemetryDeckConfiguration.appID))
		#endif

		return ObservabilityPipeline(destinations: destinations)
	}()
}
