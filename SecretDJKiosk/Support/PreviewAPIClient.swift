import Foundation
import SecretDJAPI

/// An ``SecretDJAPI/APIClient`` whose transport always fails instead of
/// touching the network — previews and adapter tests only, never production
/// (previews always inject fakes, per swiftui-views), mirrors the consumer's
/// own `PreviewAPIClient` (`SecretDJ/Features/Tabs/PreviewAPIClient.swift`).
/// Exists because ``KioskHomeView`` composes S7.4/S7.5 feed screens' loaders
/// directly from an injected `APIClient` rather than taking a `FeedLoading`
/// fake per screen (mirrors `TabsView`'s own composition-root shape), so its
/// own previews — and this target's adapter tests, which only need to prove
/// `notSignedIn`/`connection` mapping, not a real decoded response — need a
/// harmless concrete client rather than a real one.
enum PreviewAPIClient {
	static func broken() -> APIClient {
		APIClient(
			configuration: APIClientConfiguration(
				environment: .production,
				deviceIdentifier: "preview",
				screenWidth: 1024,
				clientVersion: "1.0.0",
				isKiosk: true,
			),
			implicitParameters: NoImplicitParameters(),
			transport: BrokenAPITransport(),
		)
	}
}

private struct NoImplicitParameters: ImplicitParameterProviding {
	let location: APICoordinate? = nil
	let installedApps: InstalledAppsMask = []
	let preferredLanguage = "en"
}

private struct BrokenAPITransport: APITransport {
	func send(_: URLRequest) async throws -> Data {
		throw URLError(.notConnectedToInternet)
	}
}
