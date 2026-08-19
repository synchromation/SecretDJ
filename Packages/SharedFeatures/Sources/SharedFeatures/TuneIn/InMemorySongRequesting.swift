import SecretDJDomain

/// A scriptable ``SongRequesting`` fake for tests and previews — never
/// touches the network, mirrors ``InMemoryAtmosphereChanging``'s
/// hang/resume shape for exercising ``TuneInScreenModel``'s double-tap guard
/// deterministically.
@MainActor
public final class InMemorySongRequesting: SongRequesting {
	public struct Invocation: Equatable, Sendable {
		public let songId: String
		public let venueId: String
	}

	public private(set) var invocations: [Invocation] = []
	public var result: Result<SongRequestResult, SongRequestError>

	private var isHanging = false
	private var continuation: CheckedContinuation<Void, Never>?

	public init(result: Result<SongRequestResult, SongRequestError> = .success(.success(message: nil, url: nil))) {
		self.result = result
	}

	/// Makes the next call suspend until ``resume(with:)`` releases it.
	public func hang() {
		isHanging = true
	}

	/// Releases a hung call with `result`, which also becomes the outcome
	/// for any later call made without hanging again.
	public func resume(with result: Result<SongRequestResult, SongRequestError>) {
		self.result = result
		isHanging = false
		continuation?.resume()
		continuation = nil
	}

	public func requestSong(songId: String, venueId: String) async throws(SongRequestError) -> SongRequestResult {
		invocations.append(Invocation(songId: songId, venueId: venueId))

		if isHanging {
			await withCheckedContinuation { continuation = $0 }
		}

		switch result {
		case .success(let value): return value
		case .failure(let error): throw error
		}
	}
}
