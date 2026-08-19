/// The CoreLocation flow ``LocationService`` needs, thinned to a protocol
/// seam so tests never touch `CLLocationManager` directly (ios-architecture:
/// a seam per real dependency; mirrors ``TrackingAuthorizing``). The real
/// adapter (``CLLocationManagerLocationProviding``) bridges
/// `CLLocationManagerDelegate`'s callbacks into
/// ``onAuthorizationChange``/``onLocationUpdate`` under Swift 6 strict
/// concurrency.
@MainActor
protocol LocationProviding: AnyObject {
	/// The current system authorization, read synchronously (no stream type
	/// needed — ``onAuthorizationChange`` covers every later transition).
	var authorizationStatus: LocationAuthorizationStatus { get }

	/// Set by ``LocationService`` at construction; called whenever
	/// authorization changes for any reason (the user answered the prompt,
	/// or changed it later in Settings).
	var onAuthorizationChange: ((LocationAuthorizationStatus) -> Void)? { get set }
	/// Set by ``LocationService`` at construction; called with each fix
	/// ``requestLocation()`` (or the system) delivers.
	var onLocationUpdate: ((LocationCoordinate) -> Void)? { get set }

	/// Presents the system when-in-use prompt. A no-op once the user has
	/// already answered it (the system only ever prompts once per install).
	func requestWhenInUseAuthorization()

	/// Requests one fresh fix, delivered to ``onLocationUpdate``. Legacy
	/// requests a fresh fix on every feed fetch rather than subscribing to
	/// continuous updates (LEGACY.md "Refresh rules") — this mirrors that
	/// one-shot shape.
	func requestLocation()
}
