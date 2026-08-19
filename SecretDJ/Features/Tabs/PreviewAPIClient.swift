import Foundation
import SecretDJAPI

/// An ``APIClient`` whose transport always fails instead of touching the
/// network — previews only, never production (previews always inject fakes,
/// per swiftui-views). Exists because ``TabsView`` composes S6 feed screens'
/// loaders directly from an injected `APIClient` rather than taking a
/// `FeedLoading` fake per screen, so its own previews need a harmless
/// concrete client rather than a real one.
enum PreviewAPIClient {
	static func broken() -> APIClient {
		APIClient(
			configuration: APIClientConfiguration(
				environment: .production,
				deviceIdentifier: "preview",
				screenWidth: 390,
				clientVersion: "1.0.0",
				isKiosk: false,
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
