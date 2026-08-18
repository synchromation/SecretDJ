import Foundation

/// Per-install configuration shared by every request: which backend to
/// target, the device identity baked into the User-Agent, and the
/// kiosk/consumer discriminator.
///
/// `appmodel=1` (added when ``isKiosk`` is `true`) is the *only* wire
/// difference between the two apps (LEGACY.md "Backend API and Spotify
/// integration"; `secretdjv3/AppConfiguration.swift:121-132`).
public struct APIClientConfiguration: Sendable {
	public let environment: APIEnvironment
	/// The device's `identifierForVendor` (or an equivalent stable id) —
	/// read by the caller, never by this package (ios-architecture: no
	/// UIKit inside packages).
	public let deviceIdentifier: String
	/// `UIScreen.main.bounds.size.width` at launch, in points.
	public let screenWidth: Int
	/// The app's marketing version, dotted (e.g. `"5.1.4"`). Dots are
	/// stripped when building the User-Agent, matching the legacy format.
	public let clientVersion: String
	/// `true` for the kiosk app; adds `appmodel=1` to every request.
	public let isKiosk: Bool

	public init(
		environment: APIEnvironment,
		deviceIdentifier: String,
		screenWidth: Int,
		clientVersion: String,
		isKiosk: Bool,
	) {
		self.environment = environment
		self.deviceIdentifier = deviceIdentifier
		self.screenWidth = screenWidth
		self.clientVersion = clientVersion
		self.isKiosk = isKiosk
	}

	/// `"secret dj <idfv>:<screenWidthPoints>:<version-without-dots>"` — the
	/// structured User-Agent the server relies on for device identification
	/// (LEGACY.md "Backend API and Spotify integration" → "Session config";
	/// ported from `secretdjv3/NetworkAccess.swift:71-86`).
	public var userAgent: String {
		let strippedVersion = clientVersion.replacingOccurrences(of: ".", with: "")
		return "secret dj \(deviceIdentifier):\(screenWidth):\(strippedVersion)"
	}

	/// The static headers the legacy session config applies to every
	/// request (`secretdjv3/NetworkAccess.swift:78-83`).
	var headers: [String: String] {
		[
			"Accept": "application/json",
			"Accept-Language": "en",
			"Accept-Encoding": "gzip",
			"User-Agent": userAgent,
		]
	}
}
