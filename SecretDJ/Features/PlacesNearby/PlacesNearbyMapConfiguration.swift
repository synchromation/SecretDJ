/// Ports legacy's `MapConfig.showMap` (`secretdjv3/AppConfiguration.swift:115-117`)
/// — a build-time constant gating the Places Nearby map bar button, kept as
/// a simple `Bool` rather than a runtime feature flag since legacy never
/// toggled it. `true` here matches legacy's shipped default.
enum PlacesNearbyMapConfiguration {
	static let isMapEnabled = true
}
