import Foundation

/// The thin async/await seam over `URLSession` — swapped for a fake in
/// tests so no unit test in this package performs real networking.
public protocol APITransport: Sendable {
	func send(_ request: URLRequest) async throws -> Data
}

/// The production transport: a plain `URLSession` wrapper. Session-level
/// configuration (timeout, headers) is the composition root's concern; this
/// type adds nothing beyond the async bridge.
public struct URLSessionAPITransport: APITransport {
	private let session: URLSession

	public init(session: URLSession = .shared) {
		self.session = session
	}

	public func send(_ request: URLRequest) async throws -> Data {
		let (data, _) = try await session.data(for: request)
		return data
	}
}
