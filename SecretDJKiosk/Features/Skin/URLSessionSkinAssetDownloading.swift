import Foundation

/// The production ``SkinAssetDownloading``: a plain
/// `URLSession.shared.data(from:)` fetch — no auth, no request signing
/// (skin asset URLs are plain S3 links, unsigned — LEGACY.md "Venue login
/// and the skin system"), matching legacy's own asset download exactly
/// (`secretdjv3/SkinAPIAccess.swift`'s `downloadAssets`).
struct URLSessionSkinAssetDownloading: SkinAssetDownloading {
	func data(from url: URL) async throws -> Data {
		let (data, _) = try await URLSession.shared.data(from: url)
		return data
	}
}
