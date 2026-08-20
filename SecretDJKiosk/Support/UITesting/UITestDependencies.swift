import Foundation
import Observability
import SecretDJAPI
import SharedFeatures

/// Builds the fixture dependency set ``SecretDJKioskApp`` substitutes for
/// its real, network-backed dependencies when ``UITestMode/isActive``
/// (PLAN.md S8.2) — mirrors the consumer app's own `UITestDependencies`
/// (`SecretDJ/Support/UITesting/UITestDependencies.swift`), reusing this
/// target's own `Preview*`-shaped fixtures (``PreviewKioskSessionStore``,
/// ``PreviewSkinManifest``, ``InMemorySkinStoring``) wired together for a
/// full app launch instead of one screen's preview.
@MainActor
enum UITestDependencies {
	/// The fixture venue id every kiosk UI test session checks into —
	/// shared with ``preSeededSkinStoring()`` so the signed-in session and
	/// its skin snapshot agree on which venue is ready.
	static let venueId = "fixture-venue-1"

	/// A signed-out session, or a fixture session already checked into
	/// ``venueId`` (``UITestMode/isSignedIn``) — never reads or writes real
	/// `UserDefaults`/keychain storage.
	static func makeSessionStore() -> SessionStore {
		if UITestMode.isSignedIn {
			PreviewKioskSessionStore.signedIn(venueId: venueId)
		} else {
			PreviewKioskSessionStore.signedOut()
		}
	}

	/// An ``SecretDJAPI/APIClient`` backed by ``FixtureAPITransport`` —
	/// every call this app makes decodes a canned, deterministic response,
	/// and none of them ever reach `URLSession`.
	static func makeAPIClient() -> APIClient {
		APIClient(
			configuration: APIClientConfiguration(
				environment: .production,
				deviceIdentifier: "uitest",
				screenWidth: 1024,
				clientVersion: "1.0.0",
				isKiosk: true,
			),
			implicitParameters: UITestImplicitParameters(),
			transport: FixtureAPITransport(),
		)
	}

	/// A preview player that never downloads or decodes real audio.
	static func makePreviewPlayerModel() -> PreviewPlayerModel {
		PreviewPlayerModel(
			downloading: InMemoryPreviewDownloading(),
			playerFactory: InMemoryAudioPlayerFactory(),
		)
	}

	/// A ``SkinStoring`` fake pre-seeded with a ready manifest for
	/// ``venueId`` — ``SkinModel/start()``'s cache-hit path resolves
	/// straight to `.ready` from this with no network call at all (its own
	/// doc comment), so this is the entire kiosk skin-download step's
	/// substitution: no `skinresources` fixture response is ever needed.
	static func preSeededSkinStoring() -> InMemorySkinStoring {
		PreviewSkinManifest.preSeed(InMemorySkinStoring(), venueId: venueId)
	}
}

private struct UITestImplicitParameters: ImplicitParameterProviding {
	let location: APICoordinate? = nil
	let installedApps: InstalledAppsMask = []
	let preferredLanguage = "en"
}
