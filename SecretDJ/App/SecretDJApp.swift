import Observability
import ObservabilitySentry
import ObservabilityTelemetryDeck
import SecretDJAPI
import SharedFeatures
import SwiftUI
import UIKit

@main
struct SecretDJApp: App {
	@UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
	@Environment(\.scenePhase) private var scenePhase

	@State private var sessionStore: SessionStore
	/// Created in ``init()`` alongside ``apiClient`` so both share the same
	/// ``LocationCoordinateBox`` (S5.3) — the coordinate ``LocationService``
	/// resolves is the same one `apiClient` appends to every request.
	@State private var locationService: LocationService
	/// The app-wide shared song-preview player (S6.4) — constructed once
	/// here, at the true composition root, and threaded down through
	/// `RootView`/`TabsView` to every `TuneInScreen`
	/// (``SharedFeatures/PreviewPlayerModel``'s own doc comment on why
	/// exactly one instance exists per app, never one per screen).
	@State private var previewPlayerModel: PreviewPlayerModel
	private let apiClient: APIClient
	/// StoreKit 2 purchases (S6.7) — one instance for the app's lifetime,
	/// shared by every ``TopUpsScreen`` presentation and by
	/// ``topUpTransactionListener`` so a purchase and a later restore/drain
	/// agree about the same underlying unfinished-transaction queue. A
	/// plain `let`, not `@State`, matching ``apiClient`` — nothing here
	/// ever replaces the instance, only mutates it internally.
	private let productPurchasing = StoreKitProductPurchasing()
	/// Started in ``body`` below, replacing legacy's resubmit-on-every-
	/// screen-appearance loop (``TopUpTransactionListener``'s doc comment)
	/// with a single startup drain.
	private let topUpTransactionListener: TopUpTransactionListener

	init() {
		let sessionStore = SessionStore(
			snapshotStore: UserDefaultsSessionSnapshotStore(),
			credentialStore: KeychainCredentialStore(),
		)
		_sessionStore = State(initialValue: sessionStore)

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
		_previewPlayerModel = State(initialValue: PreviewPlayerModel(
			downloading: URLSessionPreviewDownloading(),
			playerFactory: SystemAudioPlayerFactory(),
			observability: .live,
		))
		topUpTransactionListener = TopUpTransactionListener(
			purchasing: productPurchasing,
			servicing: APIClientTopUpsService(client: apiClient),
			sessionStore: sessionStore,
			observability: .live,
		)
		AudioSessionConfiguration.configureForPreviewPlayback(observability: .live)
	}

	var body: some Scene {
		WindowGroup {
			RootView(
				sessionStore: sessionStore,
				apiClient: apiClient,
				locationService: locationService,
				previewPlayerModel: previewPlayerModel,
				productPurchasing: productPurchasing,
				topUpTransactionListener: topUpTransactionListener,
				observability: .live,
			)
			.environment(\.observability, .live)
			.task { await topUpTransactionListener.start() }
			.onOpenURL { url in
				_ = appDelegate.application(UIApplication.shared, open: url)
			}
			.onChange(of: scenePhase) { _, newPhase in
				// Ports `secretdjv3/SceneDelegate.swift`'s `sceneDidBecomeActive`
				// comment verbatim: "Set auto-lock (we do this here so that
				// changes to the settings update automatically)" — S6.11's
				// in-app toggle replaces the legacy Settings-bundle switch, but
				// the scene-activation re-apply is unchanged.
				if newPhase == .active {
					AutoLockPreferenceModel.applyPersistedPreference(store: UserDefaultsAutoLockPreferenceStore())
				}
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
