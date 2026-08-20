import Foundation
import Observability
import SecretDJAPI
import SharedFeatures

/// Builds the fixture dependency set ``SecretDJApp`` substitutes for its
/// real, network- and hardware-backed dependencies when ``UITestMode/isActive``
/// (PLAN.md S8.2) — deterministic, in-memory, and network-free everywhere
/// the accessibility audit walks. Every piece here mirrors the shape an
/// existing `Preview*` fixture in this app already uses for the same
/// dependency (``PreviewSessionStore``, ``PreviewAPIClient``,
/// ``FakeProductPurchasing``, ``PreviewLocationService``) — this type just
/// wires them together for a full app launch instead of one screen's
/// preview, in the one place ``SecretDJApp`` substitutes from.
@MainActor
enum UITestDependencies {
	/// A signed-out session, or a fixture signed-in one
	/// (``UITestMode/isSignedIn``) — never reads or writes real
	/// `UserDefaults`/keychain storage.
	static func makeSessionStore() -> SessionStore {
		let store = SessionStore(
			snapshotStore: InMemorySessionSnapshotStore(),
			credentialStore: InMemoryCredentialStore(),
		)
		if UITestMode.isSignedIn {
			store.signIn(
				user: SessionUser(personId: "fixture-person-1", screenName: "Fixture User"),
				venue: nil,
				credential: APICredential(token: "fixture-token", passwordHash: "fixture-hash"),
			)
		}
		return store
	}

	/// An ``SecretDJAPI/APIClient`` backed by ``FixtureAPITransport`` — every
	/// call this app makes decodes a canned, deterministic response, and
	/// none of them ever reach `URLSession`.
	static func makeAPIClient() -> APIClient {
		APIClient(
			configuration: APIClientConfiguration(
				environment: .production,
				deviceIdentifier: "uitest",
				screenWidth: 390,
				clientVersion: "1.0.0",
				isKiosk: false,
			),
			implicitParameters: UITestImplicitParameters(),
			transport: FixtureAPITransport(),
		)
	}

	/// An always-authorized, never-real-CoreLocation location service —
	/// mirrors ``PreviewLocationService/authorized()``.
	static func makeLocationService() -> LocationService {
		LocationService(
			provider: InMemoryLocationProviding(authorizationStatus: .authorized),
			coordinateBox: LocationCoordinateBox(),
		)
	}

	/// A preview player that never downloads or decodes real audio —
	/// mirrors the fixture ``KioskSkinGateView`` already builds for its own
	/// previews.
	static func makePreviewPlayerModel() -> PreviewPlayerModel {
		PreviewPlayerModel(
			downloading: InMemoryPreviewDownloading(),
			playerFactory: InMemoryAudioPlayerFactory(),
		)
	}

	/// A ``ProductPurchasing`` fake that always resolves the top-up SKU
	/// ``FixtureAPITransport``'s feed carries, so ``TopUpsScreen`` has a
	/// real, tappable product row to audit — never touches real StoreKit.
	static func makeProductPurchasing() -> FakeProductPurchasing {
		FakeProductPurchasing(
			productResult: .success(PurchasableProduct(
				sku: "fixture.topup.1",
				displayName: "Fixture Credits",
				displayPrice: "$0.99",
			)),
		)
	}
}

private struct UITestImplicitParameters: ImplicitParameterProviding {
	let location: APICoordinate? = nil
	let installedApps: InstalledAppsMask = []
	let preferredLanguage = "en"
}
