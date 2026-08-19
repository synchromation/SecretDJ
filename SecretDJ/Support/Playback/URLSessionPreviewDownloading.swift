import Foundation
import SharedFeatures

/// The production ``SharedFeatures/PreviewDownloading``: a plain
/// `URLSession.shared.data(from:)` fetch — no auth, no request signing, no
/// domain decoding, matching legacy's own preview download exactly
/// (LEGACY.md "Audio and playback": "download the whole file with
/// `URLSession` and hand the raw bytes to `AVAudioPlayer(data:)`"). Structured
/// `Task` cancellation (``PreviewPlayerModel/stop()`` cancelling its
/// download `Task`) propagates straight through to the underlying
/// `URLSessionTask`, which `URLSession`'s async API already honors.
struct URLSessionPreviewDownloading: PreviewDownloading {
	func data(from url: URL) async throws -> Data {
		let (data, _) = try await URLSession.shared.data(from: url)
		return data
	}
}
