/// A scriptable ``TrackingAuthorizing`` fake for tests and previews — never
/// presents the real system prompt.
@MainActor
final class InMemoryTrackingAuthorizing: TrackingAuthorizing {
	var status: TrackingAuthorizationStatus
	/// The status ``requestAuthorization()`` resolves to, simulating the
	/// user's choice in the system prompt.
	var requestedStatus: TrackingAuthorizationStatus

	private(set) var requestCount = 0

	init(
		status: TrackingAuthorizationStatus = .notDetermined,
		requestedStatus: TrackingAuthorizationStatus = .authorized,
	) {
		self.status = status
		self.requestedStatus = requestedStatus
	}

	func currentStatus() -> TrackingAuthorizationStatus {
		status
	}

	func requestAuthorization() async -> TrackingAuthorizationStatus {
		requestCount += 1
		guard status == .notDetermined else {
			return status
		}

		status = requestedStatus
		return status
	}
}
