import CoreLocation

/// The system location-authorization state ``LocationService`` acts on,
/// thinned from `CLAuthorizationStatus` (mirrors
/// ``TrackingAuthorizationStatus``'s gating shape). Secret DJ only ever
/// requests when-in-use (LEGACY.md "Location": when-in-use only), so
/// `authorizedAlways` collapses into ``authorized`` alongside it.
enum LocationAuthorizationStatus: Equatable {
	/// The user hasn't been asked yet — a screen that needs location should
	/// request authorization before relying on a fix.
	case notDetermined
	/// Location access is allowed; requesting a fix may proceed.
	case authorized
	/// The user explicitly declined location access.
	case denied
	/// Location is unavailable for a reason outside the user's control
	/// (e.g. a device restriction) — treated the same as ``denied`` for
	/// gating purposes.
	case restricted
}

extension LocationAuthorizationStatus {
	init(_ status: CLAuthorizationStatus) {
		switch status {
		case .notDetermined:
			self = .notDetermined

		case .authorizedWhenInUse,
		     .authorizedAlways:
			self = .authorized

		case .denied:
			self = .denied

		case .restricted:
			self = .restricted

		@unknown default:
			self = .denied
		}
	}
}
