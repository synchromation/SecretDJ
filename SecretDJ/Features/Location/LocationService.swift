import FeedUI
import Foundation
import Observability
import SecretDJAPI

/// Owns the app's one CoreLocation relationship (ios-architecture: a
/// side-effecting dependency behind a seam) — authorization state for UI,
/// the current coordinate that feeds every API call's implicit `coords`
/// parameter (``DeviceImplicitParameterProvider`` reads it through
/// ``LocationCoordinateBox``), and the first-fix timestamp `FeedUI`'s
/// auto-refresh cadence reads through ``GPSFixAgeProviding`` (LEGACY.md
/// "Refresh rules": 3s until that fix is ~12s old, then 20s — bug #181's
/// `gotFirstFixLocation`).
///
/// Legacy requests a fresh one-shot fix on every feed fetch rather than
/// subscribing to continuous updates; this service doesn't poll on its
/// own — screens call ``requestLocation()`` from their own load paths
/// (S6.1+).
@MainActor
@Observable
final class LocationService: GPSFixAgeProviding {
	/// The most recent known fix, or `nil` before the first one arrives.
	private(set) var coordinate: LocationCoordinate?
	/// Current system authorization, for the permission-denied surface and
	/// for gating whether a request makes sense.
	private(set) var authorizationStatus: LocationAuthorizationStatus

	private let provider: any LocationProviding
	private let coordinateBox: LocationCoordinateBox
	private let observability: ObservabilityPipeline
	private let now: () -> Date

	private var firstFixDate: Date?

	init(
		provider: any LocationProviding,
		coordinateBox: LocationCoordinateBox,
		observability: ObservabilityPipeline = .disabled,
		now: @escaping () -> Date = Date.init,
	) {
		self.provider = provider
		self.coordinateBox = coordinateBox
		self.observability = observability
		self.now = now
		authorizationStatus = provider.authorizationStatus

		provider.onAuthorizationChange = { [weak self] status in
			self?.handle(authorizationChange: status)
		}
		provider.onLocationUpdate = { [weak self] coordinate in
			self?.handle(locationUpdate: coordinate)
		}
	}

	/// Presents the when-in-use prompt if not yet determined; a no-op
	/// otherwise (the system only ever prompts once per install — mirrors
	/// ``TrackingAuthorizing/requestAuthorization()``'s contract).
	func requestAuthorizationIfNeeded() {
		guard authorizationStatus == .notDetermined else { return }

		provider.requestWhenInUseAuthorization()
	}

	/// Requests one fresh fix when authorized; a no-op otherwise. Callers
	/// request a fix from their own load paths (legacy requests one on
	/// every feed fetch — LEGACY.md "Refresh rules") rather than this
	/// service polling on its own.
	func requestLocation() {
		guard authorizationStatus == .authorized else { return }

		provider.requestLocation()
	}

	/// Re-reads authorization without prompting — call on scene foreground
	/// (legacy re-checks on every foreground:
	/// `updateViewForLocationPermission`).
	func refreshAuthorizationStatus() {
		handle(authorizationChange: provider.authorizationStatus)
	}

	/// ``GPSFixAgeProviding`` conformance: `nil` before the first fix this
	/// launch, otherwise how long ago it arrived.
	func firstFixAge() -> Duration? {
		guard let firstFixDate else { return nil }

		return .seconds(now().timeIntervalSince(firstFixDate))
	}

	private func handle(authorizationChange status: LocationAuthorizationStatus) {
		guard status != authorizationStatus else { return }

		authorizationStatus = status
		observability.interaction("locationAuthorizationChanged")
	}

	private func handle(locationUpdate newCoordinate: LocationCoordinate) {
		coordinate = newCoordinate
		if firstFixDate == nil {
			firstFixDate = now()
		}

		coordinateBox.update(APICoordinate(latitude: newCoordinate.latitude, longitude: newCoordinate.longitude))
	}
}
