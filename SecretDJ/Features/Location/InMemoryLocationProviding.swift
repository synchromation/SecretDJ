/// A scriptable ``LocationProviding`` fake for tests and previews — never
/// touches real CoreLocation. Tests drive it by calling
/// ``simulateAuthorizationChange(to:)``/``simulateLocationUpdate(_:)`` to
/// push a change through the handlers ``LocationService`` registered
/// (exactly as the real adapter's delegate bridge would), or by assigning
/// ``authorizationStatus`` directly to simulate the OS having changed it
/// silently — the case ``LocationService/refreshAuthorizationStatus()``
/// pulls for on foreground.
@MainActor
final class InMemoryLocationProviding: LocationProviding {
	var authorizationStatus: LocationAuthorizationStatus
	var onAuthorizationChange: ((LocationAuthorizationStatus) -> Void)?
	var onLocationUpdate: ((LocationCoordinate) -> Void)?

	private(set) var requestWhenInUseAuthorizationCallCount = 0
	private(set) var requestLocationCallCount = 0

	init(authorizationStatus: LocationAuthorizationStatus = .notDetermined) {
		self.authorizationStatus = authorizationStatus
	}

	func requestWhenInUseAuthorization() {
		requestWhenInUseAuthorizationCallCount += 1
	}

	func requestLocation() {
		requestLocationCallCount += 1
	}

	/// Simulates the system delivering an authorization change — e.g. the
	/// user answering the prompt ``requestWhenInUseAuthorization()``
	/// presented, or changing it later in Settings.
	func simulateAuthorizationChange(to status: LocationAuthorizationStatus) {
		authorizationStatus = status
		onAuthorizationChange?(status)
	}

	/// Simulates the system delivering a fix in response to
	/// ``requestLocation()``.
	func simulateLocationUpdate(_ coordinate: LocationCoordinate) {
		onLocationUpdate?(coordinate)
	}
}
