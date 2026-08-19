/// A scriptable ``MachineControlling`` fake for tests and previews — never
/// touches the network, mirrors ``InMemoryAtmosphereChanging``'s hang/resume
/// shape for exercising ``TuneInScreenModel``'s double-tap guard
/// deterministically.
@MainActor
public final class InMemoryMachineControlling: MachineControlling {
	public struct Invocation: Equatable, Sendable {
		public let action: TuneInModerationAction
		public let songId: String
		public let venueId: String
	}

	public private(set) var invocations: [Invocation] = []
	public var result: Result<MachineControlResult, MachineControlError>

	private var isHanging = false
	private var continuation: CheckedContinuation<Void, Never>?

	public init(result: Result<MachineControlResult, MachineControlError> = .success(
		MachineControlResult(message: nil),
	)) {
		self.result = result
	}

	/// Makes the next call suspend until ``resume(with:)`` releases it.
	public func hang() {
		isHanging = true
	}

	/// Releases a hung call with `result`, which also becomes the outcome
	/// for any later call made without hanging again.
	public func resume(with result: Result<MachineControlResult, MachineControlError>) {
		self.result = result
		isHanging = false
		continuation?.resume()
		continuation = nil
	}

	public func moderate(
		_ action: TuneInModerationAction,
		songId: String,
		venueId: String,
	) async throws(MachineControlError) -> MachineControlResult {
		invocations.append(Invocation(action: action, songId: songId, venueId: venueId))

		if isHanging {
			await withCheckedContinuation { continuation = $0 }
		}

		switch result {
		case .success(let value): return value
		case .failure(let error): throw error
		}
	}
}
