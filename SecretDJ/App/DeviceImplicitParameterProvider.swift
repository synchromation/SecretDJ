import Foundation
import SecretDJAPI

/// The composition root's ``ImplicitParameterProviding``: supplies the
/// request-time values every API call needs. Location comes from
/// ``LocationCoordinateBox`` — the thread-safe bridge from
/// ``LocationService``'s `@MainActor` state to this nonisolated read
/// (S5.3). Installed-app detection arrives with the feature that needs it
/// (``InstalledAppsMask``'s doc comment) — until then this always reports
/// no installed apps.
struct DeviceImplicitParameterProvider: ImplicitParameterProviding {
	let coordinateBox: LocationCoordinateBox

	var location: APICoordinate? {
		coordinateBox.current
	}

	var installedApps: InstalledAppsMask {
		[]
	}

	/// The device's preferred language as a BCP-47 tag, sent as
	/// `Accept-Language` on every request so server copy arrives localized
	/// (D11).
	var preferredLanguage: String {
		Locale.preferredLanguages.first ?? "en"
	}
}
