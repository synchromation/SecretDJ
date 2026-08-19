/// A raw device coordinate, thinned from CoreLocation's
/// `CLLocationCoordinate2D` so ``LocationProviding`` and its fake never
/// import CoreLocation (mirrors ``TrackingAuthorizationStatus``'s
/// `ATTrackingManager` thinning) — only ``CLLocationManagerLocationProviding``
/// bridges to the framework type.
struct LocationCoordinate: Equatable {
	let latitude: Double
	let longitude: Double
}
