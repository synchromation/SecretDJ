import CoreLocation

/// The production ``LocationProviding``: a thin bridge to `CLLocationManager`
/// — everything worth testing (authorization gating, first-fix tracking,
/// feeding the API's implicit parameter) lives in ``LocationService``
/// instead, over the fake.
///
/// `CLLocationManager` calls its delegate back on the thread that created
/// the manager (Apple's documented contract); since this type is only ever
/// constructed on the main actor, the delegate methods below — `nonisolated`
/// to satisfy `CLLocationManagerDelegate`'s unannotated requirements — use
/// `MainActor.assumeIsolated` rather than hopping through a `Task`, which
/// would require a `Sendable` capture of `self`.
final class CLLocationManagerLocationProviding: NSObject, LocationProviding {
	private let manager = CLLocationManager()

	var onAuthorizationChange: ((LocationAuthorizationStatus) -> Void)?
	var onLocationUpdate: ((LocationCoordinate) -> Void)?

	var authorizationStatus: LocationAuthorizationStatus {
		LocationAuthorizationStatus(manager.authorizationStatus)
	}

	override init() {
		super.init()
		manager.delegate = self
	}

	func requestWhenInUseAuthorization() {
		manager.requestWhenInUseAuthorization()
	}

	func requestLocation() {
		manager.requestLocation()
	}
}

extension CLLocationManagerLocationProviding: CLLocationManagerDelegate {
	/// Both callbacks read the plain CoreLocation value outside
	/// `assumeIsolated` (no isolation of its own to cross) and construct this
	/// app's own — implicitly main-actor-isolated, per this module's default
	/// — types only inside it.
	nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
		let clStatus = manager.authorizationStatus

		MainActor.assumeIsolated {
			onAuthorizationChange?(LocationAuthorizationStatus(clStatus))
		}
	}

	nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
		guard let coordinate = locations.last?.coordinate else { return }

		MainActor.assumeIsolated {
			onLocationUpdate?(LocationCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude))
		}
	}

	/// A one-shot `requestLocation()` failure has no legacy UI beyond leaving
	/// `coordinate` at its previous value — a later feed fetch just tries
	/// again.
	nonisolated func locationManager(_: CLLocationManager, didFailWithError _: Error) {}
}
