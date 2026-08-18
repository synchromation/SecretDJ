/// Supplies the request-time inputs the client injects into every API
/// call, so tests can fake them instead of reading UIKit/CoreLocation
/// (LEGACY.md "Backend API and Spotify integration" → implicit query
/// parameters; D11 adds device language).
public protocol ImplicitParameterProviding: Sendable {
	/// The most recent known device location, or `nil` before any fix —
	/// mirrors the legacy client only appending `coords` when a fix exists.
	var location: APICoordinate? { get }

	/// Which companion apps (Instagram, Twitter, Uber, ...) are currently
	/// installed, probed via queryable URL schemes.
	var installedApps: InstalledAppsMask { get }

	/// The user's preferred language as a BCP-47 tag (e.g. `"en-GB"`), sent
	/// with every request so server copy arrives localized (D11).
	var preferredLanguage: String { get }
}
