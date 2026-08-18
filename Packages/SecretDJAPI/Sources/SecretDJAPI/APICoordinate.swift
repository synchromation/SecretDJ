import Foundation

/// A device location fix, formatted for the wire exactly as the legacy
/// client does (`secretdjv3/NetworkingParameterProvider.swift:88-95`).
public struct APICoordinate: Sendable, Hashable {
	public let latitude: Double
	public let longitude: Double

	public init(latitude: Double, longitude: Double) {
		self.latitude = latitude
		self.longitude = longitude
	}

	/// `"%.6f,%.6f"` — the `coords` query parameter's exact format.
	var queryValue: String {
		String(format: "%.6f,%.6f", latitude, longitude)
	}
}
