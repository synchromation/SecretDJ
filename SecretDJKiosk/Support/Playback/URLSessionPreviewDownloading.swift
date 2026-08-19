import Foundation
import SharedFeatures

/// The kiosk's production ``SharedFeatures/PreviewDownloading``: a plain
/// `URLSession.shared.data(from:)` fetch, identical to the consumer app's
/// own `SecretDJ/Support/Playback/URLSessionPreviewDownloading.swift` — the
/// protocol's own doc comment documents this as a per-app implementation
/// (no auth or domain decoding to diverge on), so each app target provides
/// its own rather than sharing one through the package.
struct URLSessionPreviewDownloading: PreviewDownloading {
	func data(from url: URL) async throws -> Data {
		let (data, _) = try await URLSession.shared.data(from: url)
		return data
	}
}
