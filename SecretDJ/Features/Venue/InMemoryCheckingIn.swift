/// A scriptable ``CheckingIn`` fake for tests and previews — never touches
/// the network, mirrors ``SharedFeatures/InMemoryLikeToggling``'s shape.
/// Beyond the usual immediate ``result``, ``hang()``/``resume(with:)`` let a
/// test suspend a call mid-flight to observe ``CheckInModel``'s optimistic
/// state before the server "answers" (the double-tap race coverage needs
/// this; a plain immediate-resolution fake can't exercise it).
@MainActor
final class InMemoryCheckingIn: CheckingIn {
	private(set) var calls: [String] = []
	var result: Result<CheckInOutcome, CheckInError>

	private var isHanging = false
	private var continuation: CheckedContinuation<Void, Never>?

	init(result: Result<CheckInOutcome, CheckInError> = .success(CheckInOutcome(message: "", url: nil))) {
		self.result = result
	}

	/// Makes the next call suspend until ``resume(with:)`` releases it.
	func hang() {
		isHanging = true
	}

	/// Releases a hung call with `result`, which also becomes the outcome
	/// for any later call made without hanging again.
	func resume(with result: Result<CheckInOutcome, CheckInError>) {
		self.result = result
		isHanging = false
		continuation?.resume()
		continuation = nil
	}

	func checkIn(venueId: String) async throws(CheckInError) -> CheckInOutcome {
		calls.append(venueId)

		if isHanging {
			await withCheckedContinuation { continuation = $0 }
		}

		switch result {
		case .success(let value): return value
		case .failure(let error): throw error
		}
	}
}
