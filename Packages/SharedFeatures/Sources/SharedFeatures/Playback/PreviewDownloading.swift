import Foundation

/// The whole-file fetch ``PreviewPlayerModel`` needs to download a song
/// preview's bytes before decoding them (ios-architecture: a protocol seam
/// per real dependency), thinned to exactly this — no domain knowledge of
/// songs or the API. An app implements this over `URLSession`
/// (`SecretDJ/Support/Playback/URLSessionPreviewDownloading.swift`); the
/// call is cancellable through ordinary structured-concurrency `Task`
/// cancellation, which `URLSession`'s own `data(from:)` already honors.
///
/// Deliberately not a domain-specific seam like ``SongRequesting``/
/// ``LikeToggling``: the backend serves previews as a plain byte stream from
/// S3 with a custom `.pbz` extension and a generic Content-Type (LEGACY.md
/// "Audio and playback" → "Evolution: StreamingKit → AVPlayer → download +
/// AVAudioPlayer"), so there's no response shape to decode here — just
/// bytes, handed to ``AudioPlayerFactory`` once the whole file has arrived.
public protocol PreviewDownloading: Sendable {
	func data(from url: URL) async throws -> Data
}
