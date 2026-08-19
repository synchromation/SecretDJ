import Foundation

/// A scriptable ``SkinAssetDownloading`` fake for tests and previews — never
/// touches the network. Every call suspends until ``complete(url:with:)`` or
/// ``fail(url:with:)`` releases the *oldest* still-pending call for that
/// specific URL (mirrors ``InMemoryPreviewDownloading``'s FIFO shape, but
/// keyed per URL rather than one global queue: ``SkinModel`` downloads
/// several distinct assets concurrently, and a test resolving them in a
/// chosen order needs to address each one independently, not just "the next
/// call in").
actor InMemorySkinAssetDownloading: SkinAssetDownloading {
	private(set) var requestedURLs: [URL] = []

	private var pending: [URL: [CheckedContinuation<Data, any Error>]] = [:]

	func data(from url: URL) async throws -> Data {
		requestedURLs.append(url)
		return try await withCheckedThrowingContinuation { continuation in
			pending[url, default: []].append(continuation)
		}
	}

	/// Resolves the oldest still-pending call for `url` with `data`. A
	/// no-op when nothing is pending for that URL.
	func complete(url: URL, with data: Data) {
		guard var queue = pending[url], !queue.isEmpty else { return }
		let continuation = queue.removeFirst()
		pending[url] = queue
		continuation.resume(returning: data)
	}

	/// Resolves the oldest still-pending call for `url` with `error`. A
	/// no-op when nothing is pending for that URL.
	func fail(url: URL, with error: any Error) {
		guard var queue = pending[url], !queue.isEmpty else { return }
		let continuation = queue.removeFirst()
		pending[url] = queue
		continuation.resume(throwing: error)
	}
}
