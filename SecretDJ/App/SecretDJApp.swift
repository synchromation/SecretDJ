import Observability
import ObservabilitySentry
import ObservabilityTelemetryDeck
import SecretDJAPI
import SwiftUI
import UIKit

@main
struct SecretDJApp: App {
	@UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

	@State private var sessionStore = SessionStore(
		snapshotStore: UserDefaultsSessionSnapshotStore(),
		credentialStore: KeychainCredentialStore(),
	)
	/// Created in ``init()`` alongside ``apiClient`` so both share the same
	/// ``LocationCoordinateBox`` (S5.3) — the coordinate ``LocationService``
	/// resolves is the same one `apiClient` appends to every request.
	@State private var locationService: LocationService

	private let apiClient: APIClient

	init() {
		let coordinateBox = LocationCoordinateBox()
		_locationService = State(initialValue: LocationService(
			provider: CLLocationManagerLocationProviding(),
			coordinateBox: coordinateBox,
			observability: .live,
		))
		apiClient = APIClient(
			configuration: .live,
			implicitParameters: DeviceImplicitParameterProvider(coordinateBox: coordinateBox),
			transport: URLSessionAPITransport(),
		)
	}

	var body: some Scene {
		WindowGroup {
			RootView(
				sessionStore: sessionStore,
				apiClient: apiClient,
				locationService: locationService,
				observability: .live,
			)
			.environment(\.observability, .live)
			.onOpenURL { url in
				_ = appDelegate.application(UIApplication.shared, open: url)
			}
		}
	}
}

extension APIClientConfiguration {
	/// The production configuration: the live backend, this install's
	/// device identity, and the app's own marketing version
	/// (`secretdjv3/AppConfiguration.swift`'s device/version identity, per
	/// LEGACY.md "Backend API and Spotify integration" → "Session config").
	static let live = APIClientConfiguration(
		environment: .production,
		deviceIdentifier: UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString,
		screenWidth: Int(UIScreen.main.bounds.width),
		clientVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0",
		isKiosk: false,
	)
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
