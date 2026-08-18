import Foundation
import SecretDJAPI

/// The composition root's ``ImplicitParameterProviding``: supplies the
/// request-time values every API call needs. Location and installed-app
/// detection arrive with the features that need them
/// (``InstalledAppsMask``'s doc comment) — until then this always reports
/// no fix and no installed apps.
struct DeviceImplicitParameterProvider: ImplicitParameterProviding {
	var location: APICoordinate? {
		nil
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
