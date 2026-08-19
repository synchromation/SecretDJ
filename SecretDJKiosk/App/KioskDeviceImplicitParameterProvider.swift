import Foundation
import SecretDJAPI

/// The kiosk's ``ImplicitParameterProviding``. `appmodel=1` itself comes
/// from ``APIClientConfiguration/isKiosk``, not from here — this type only
/// supplies the same three request-time values the consumer's own
/// `DeviceImplicitParameterProvider` does (LEGACY.md "Backend API and
/// Spotify integration": `coords`/`appmask`/language are shared implicit
/// parameters, identical semantics on both apps — `appmodel=1` is "the
/// *only* wire difference").
///
/// ``location`` always reports `nil` for now. The wire contract already
/// treats this as a valid state — `coords` is appended "when a location
/// fix exists", never required — and wiring a real fix means a
/// CoreLocation/permission stack this shell doesn't own: S7.1's scope is
/// `SecretDJKiosk/App/` + `SecretDJKiosk/Features/KioskLogin/`, and the
/// consumer's own location feature (`SecretDJ/Features/Location/`) is
/// app-local, not a package this target can reuse. Documented seam for
/// whichever later task gives the kiosk its own location feature.
struct KioskDeviceImplicitParameterProvider: ImplicitParameterProviding {
	var location: APICoordinate? {
		nil
	}

	/// Mirrors the consumer's own default: installed-app detection arrives
	/// with the feature that needs it.
	var installedApps: InstalledAppsMask {
		[]
	}

	/// The device's preferred language as a BCP-47 tag, sent as
	/// `Accept-Language` on every request so server copy arrives localized
	/// (D11) — identical to the consumer's own provider.
	var preferredLanguage: String {
		Locale.preferredLanguages.first ?? "en"
	}
}
