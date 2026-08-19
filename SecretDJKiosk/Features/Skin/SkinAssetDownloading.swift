import Foundation

/// The whole-file fetch ``SkinModel`` needs to download one chrome asset's
/// bytes before persisting it (ios-architecture: a protocol seam per real
/// dependency) — thinned to exactly this, no domain knowledge of skins.
/// Mirrors `SharedFeatures/PreviewDownloading`'s exact shape (S6.4's own
/// whole-file download seam) deliberately kept as its own local protocol
/// rather than reused across packages: a skin asset and a song preview are
/// unrelated dependencies that happen to share a signature, and this
/// feature has no reason to depend on `SharedFeatures` for it. An app
/// implements this over `URLSession`
/// (``URLSessionSkinAssetDownloading``); the call is cancellable through
/// ordinary structured-concurrency `Task` cancellation, which
/// `URLSession`'s own `data(from:)` already honors.
protocol SkinAssetDownloading: Sendable {
	func data(from url: URL) async throws -> Data
}
