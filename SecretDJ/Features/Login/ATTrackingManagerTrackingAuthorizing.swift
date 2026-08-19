import AppTrackingTransparency

/// The production ``TrackingAuthorizing``: reads and requests App Tracking
/// Transparency authorization straight through `ATTrackingManager`
/// (`secretdjv3/AppTrackingTransparency.swift`'s
/// `requestTrackingPermission`/`trackingHasBeenRejected`, rebuilt as an
/// injectable seam rather than free functions).
struct ATTrackingManagerTrackingAuthorizing: TrackingAuthorizing {
	func currentStatus() -> TrackingAuthorizationStatus {
		TrackingAuthorizationStatus(ATTrackingManager.trackingAuthorizationStatus)
	}

	func requestAuthorization() async -> TrackingAuthorizationStatus {
		guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
			return currentStatus()
		}

		let status = await withCheckedContinuation { continuation in
			ATTrackingManager.requestTrackingAuthorization { status in
				continuation.resume(returning: status)
			}
		}
		return TrackingAuthorizationStatus(status)
	}
}

extension TrackingAuthorizationStatus {
	fileprivate init(_ status: ATTrackingManager.AuthorizationStatus) {
		switch status {
		case .authorized:
			self = .authorized

		case .denied:
			self = .denied

		case .restricted:
			self = .restricted

		case .notDetermined:
			self = .notDetermined

		@unknown default:
			self = .denied
		}
	}
}
