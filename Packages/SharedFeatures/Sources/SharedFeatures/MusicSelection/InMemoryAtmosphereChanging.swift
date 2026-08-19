/// A scriptable ``AtmosphereChanging`` fake for tests and previews — never
/// touches the network. Mirrors the consumer app's `InMemoryLikeToggling`
/// shape, including ``hang()``/``resume(with:)`` for exercising
/// ``MoodTileModel``'s double-tap guard deterministically, since two
/// `@MainActor` calls racing on incidental scheduling can't be relied on to
/// interleave.
@MainActor
public final class InMemoryAtmosphereChanging: AtmosphereChanging {
	public struct Invocation: Equatable, Sendable {
		public let itemId: Int
		public let venueId: String
		public let minutes: Int
	}

	public private(set) var invocations: [Invocation] = []
	public var result: Result<AtmosphereChangeResult, AtmosphereChangeError>

	private var isHanging = false
	private var continuation: CheckedContinuation<Void, Never>?

	public init(result: Result<AtmosphereChangeResult, AtmosphereChangeError> = .success(
		AtmosphereChangeResult(message: nil),
	)) {
		self.result = result
	}

	/// Makes the next call suspend until ``resume(with:)`` releases it.
	public func hang() {
		isHanging = true
	}

	/// Releases a hung call with `result`, which also becomes the outcome
	/// for any later call made without hanging again.
	public func resume(with result: Result<AtmosphereChangeResult, AtmosphereChangeError>) {
		self.result = result
		isHanging = false
		continuation?.resume()
		continuation = nil
	}

	public func changeAtmosphere(
		itemId: Int,
		venueId: String,
		minutes: Int,
	) async throws(AtmosphereChangeError) -> AtmosphereChangeResult {
		invocations.append(Invocation(itemId: itemId, venueId: venueId, minutes: minutes))

		if isHanging {
			await withCheckedContinuation { continuation = $0 }
		}

		switch result {
		case .success(let value): return value
		case .failure(let error): throw error
		}
	}
}
