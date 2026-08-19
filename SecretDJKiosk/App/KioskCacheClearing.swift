import Foundation

/// One kiosk cache the staff reset (``StaffResetModel``) clears. Every
/// registered conformance runs on reset — additive, so a later feature
/// registers its own cache without touching ``StaffResetModel`` itself:
/// S7.2's skin system will add one for its downloaded venue skin assets
/// (LEGACY.md "Venue login and the skin system" — legacy's own
/// `?RESTART?` handler "purges `URLCache`, deletes all skin assets").
protocol KioskCacheClearing: Sendable {
	func clear()
}

/// Clears the shared `URLCache` — the one kiosk cache that already exists
/// today, ahead of S7.2's skin asset cache.
struct URLCacheClearing: KioskCacheClearing {
	func clear() {
		URLCache.shared.removeAllCachedResponses()
	}
}
