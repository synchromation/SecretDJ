import Foundation

/// A scriptable ``PreviewDownloading`` fake for tests and previews — never
/// touches the network. Every call suspends until ``complete(with:)`` or
/// ``fail(with:)`` releases the *oldest* still-pending one (FIFO), so a test
/// can have two downloads in flight at once — e.g. ``PreviewPlayerModel``'s
/// single-active-preview race, where a second ``PreviewPlayerModel/play(songId:url:)``
/// starts before the first's download has resolved — and settle each in a
/// known order (mirrors ``InMemorySongRequesting``'s hang/resume shape, but
/// as an actor so overlapping in-flight calls never race each other for the
/// same stored continuation).
public actor InMemoryPreviewDownloading: PreviewDownloading {
	public private(set) var requestedURLs: [URL] = []

	private var pending: [CheckedContinuation<Data, any Error>] = []

	public init() {}

	public func data(from url: URL) async throws -> Data {
		requestedURLs.append(url)
		return try await withCheckedThrowingContinuation { continuation in
			pending.append(continuation)
		}
	}

	/// Resolves the oldest still-pending call with `data`. A no-op when
	/// nothing is pending.
	public func complete(with data: Data) {
		guard !pending.isEmpty else { return }
		pending.removeFirst().resume(returning: data)
	}

	/// Resolves the oldest still-pending call with `error`. A no-op when
	/// nothing is pending.
	public func fail(with error: any Error) {
		guard !pending.isEmpty else { return }
		pending.removeFirst().resume(throwing: error)
	}
}
