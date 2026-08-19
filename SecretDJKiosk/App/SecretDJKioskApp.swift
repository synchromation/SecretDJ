import Foundation
import Observability
import SecretDJAPI
import SharedFeatures
import SwiftUI
import UIKit

/// The kiosk's composition root — the same shape as the consumer's own
/// `SecretDJApp` (`SecretDJ/App/SecretDJApp.swift`), scoped to what S7.1
/// actually needs: a ``SessionStore`` (its own keychain service, per D5 —
/// "no shared keychain group between the apps... kiosk venue credentials
/// are its own"), an ``APIClient`` carrying the kiosk's implicit
/// parameters, and console-only observability. Everything else the
/// consumer root builds (location, preview player, StoreKit, Facebook) has
/// no kiosk equivalent yet — later S7 tasks add what they need here.
@main
struct SecretDJKioskApp: App {
	@State private var sessionStore: SessionStore
	/// The kiosk-wide shared song-preview player (S6.4's design, S7.3's
	/// first consumer): constructed here, at the true composition root, even
	/// though no kiosk screen starts a preview yet (that's S7.6's job) —
	/// ``IdleTimerModel`` needs to observe ``PreviewPlayerModel/isPlaying``
	/// from the moment the kiosk home shows, and `PreviewPlayerModel`'s own
	/// doc comment is explicit that exactly one instance should exist
	/// app-wide, never one per screen. Building it early (always idle, since
	/// nothing calls `play(songId:url:)` yet) costs nothing and avoids
	/// threading an `Optional` through every S7.3+ screen only to make it
	/// non-optional again in S7.6.
	@State private var previewPlayerModel: PreviewPlayerModel
	private let apiClient: APIClient

	init() {
		let sessionStore = SessionStore(
			snapshotStore: UserDefaultsSessionSnapshotStore(),
			credentialStore: KeychainCredentialStore(service: "com.secretdj.kiosk.session"),
		)
		_sessionStore = State(initialValue: sessionStore)

		apiClient = APIClient(
			configuration: .live,
			implicitParameters: KioskDeviceImplicitParameterProvider(),
			transport: URLSessionAPITransport(),
		)

		_previewPlayerModel = State(initialValue: PreviewPlayerModel(
			downloading: URLSessionPreviewDownloading(),
			playerFactory: SystemAudioPlayerFactory(),
			observability: .live,
		))
	}

	var body: some Scene {
		WindowGroup {
			KioskRootView(
				sessionStore: sessionStore,
				apiClient: apiClient,
				previewPlayer: previewPlayerModel,
				observability: .live,
			)
			.environment(\.observability, .live)
		}
	}
}

extension APIClientConfiguration {
	/// The kiosk's production configuration — identical shape to the
	/// consumer's own `.live` (`SecretDJApp.swift`), with `isKiosk: true`
	/// the one wire difference (`appmodel=1`; LEGACY.md "Backend API and
	/// Spotify integration").
	static let live = APIClientConfiguration(
		environment: .production,
		deviceIdentifier: UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString,
		screenWidth: Int(UIScreen.main.bounds.width),
		clientVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0",
		isKiosk: true,
	)
}

extension ObservabilityPipeline {
	/// The kiosk's observability configuration: console-only. The kiosk
	/// target doesn't yet link `ObservabilitySentry`/
	/// `ObservabilityTelemetryDeck` — D4's vendor choice was made for the
	/// consumer app; wiring the same vendors into the kiosk is a follow-up,
	/// not part of S7.1's shell.
	static let live = ObservabilityPipeline(destinations: [ConsoleDestination()])
}
