import Foundation

/// How long ago the app obtained its first GPS fix this launch — the value
/// ``FeedScreenModel`` reads to apply the legacy auto-refresh cadence rule
/// (LEGACY.md "The feed engine" → "Refresh rules": polling tightens until
/// that fix is about 12 seconds old, bug #181's
/// `UserManager.gotFirstFixLocation` workaround). The app computes this from
/// CoreLocation; FeedUI takes no location dependency of its own.
@MainActor
public protocol GPSFixAgeProviding {
	/// `nil` before the app has obtained any GPS fix this launch; otherwise
	/// how long ago the first fix arrived. Re-evaluated fresh on every call,
	/// since the answer changes as the fix ages.
	func firstFixAge() -> Duration?
}
