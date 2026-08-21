import DesignSystem
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
	/// ever replaces the instance, only mutates it internally. Typed as the
	/// protocol (rather than defaulting to a `StoreKitProductPurchasing()`
	/// literal) so ``init()``'s UI-test branch can assign
	/// ``UITestDependencies/makeProductPurchasing()`` instead — never real
	/// StoreKit under UI-test automation.
	private let productPurchasing: any ProductPurchasing
	/// Started in ``body`` below, replacing legacy's resubmit-on-every-
	/// screen-appearance loop (``TopUpTransactionListener``'s doc comment)
	/// with a single startup drain.
	private let topUpTransactionListener: TopUpTransactionListener

	init() {
		if UITestMode.isActive {
			// PLAN.md S8.2's UI-test mode: every dependency below comes from
			// ``UITestDependencies`` instead — deterministic, in-memory, and
			// never touching the real network, StoreKit, or Core Location.
			// This branch is the app's *only* substitution point; nothing
			// else in the composition root re-checks ``UITestMode``.
			//
			// Animations off: XCTest's synchronization doesn't wait out a
			// sheet/NavigationStack transition, so `performAccessibilityAudit()`
			// can sample mid-fade and report a transient "Contrast failed" on
			// whatever's still animating in — a flake, not a real design
			// issue. Disabling animations removes that whole class of
			// timing races.
			UIView.setAnimationsEnabled(false)
			let sessionStore = UITestDependencies.makeSessionStore()
			_sessionStore = State(initialValue: sessionStore)
			_locationService = State(initialValue: UITestDependencies.makeLocationService())
			apiClient = UITestDependencies.makeAPIClient()
			_previewPlayerModel = State(initialValue: UITestDependencies.makePreviewPlayerModel())
			productPurchasing = UITestDependencies.makeProductPurchasing()
			topUpTransactionListener = TopUpTransactionListener(
				purchasing: productPurchasing,
				servicing: APIClientTopUpsService(client: apiClient),
				sessionStore: sessionStore,
				observability: .disabled,
			)
			return
		}

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
		productPurchasing = StoreKitProductPurchasing()
		topUpTransactionListener = TopUpTransactionListener(
			purchasing: productPurchasing,
			servicing: APIClientTopUpsService(client: apiClient),
			sessionStore: sessionStore,
			observability: .live,
		)
		AudioSessionConfiguration.configureForPreviewPlayback(observability: .live)
	}

	/// `.disabled` under UI-test automation (PLAN.md S8.2's ground rule: no
	/// vendor/analytics traffic from a test run either) — `.live` otherwise.
	private var observability: ObservabilityPipeline {
		UITestMode.isActive ? .disabled : .live
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
				observability: observability,
			)
			// S9.5: legacy shipped dark-only (LEGACY.md "Dark-only theme" —
			// "colours are hardcoded dark... there is no light-mode design to
			// migrate"), so this app presents dark by default too rather than
			// following the device's own appearance — `Theme.ColorRole`
			// already carries a full light palette (S9.2's doc comment) for a
			// future user-facing appearance choice, this is just today's
			// fixed default. Reversible in one line: delete this modifier
			// (or make it conditional on a future preference) and every
			// screen already resolves the right colors for either appearance
			// on its own, since nothing else in the app hardcodes "dark".
			.preferredColorScheme(.dark)
			// Legacy's own brand teal on every nav item (`AppColors
			// .navigationItemText`/`.greenBlue`, LEGACY.md's `StyleKit`
			// brand-color note) — one root-level tint cascades into every
			// nav bar back/bar-button item and `TabsView`'s own selected-tab
			// icon, rather than each screen setting its own.
			.tint(Theme.ColorRole.accent.color)
			.environment(\.observability, observability)
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
