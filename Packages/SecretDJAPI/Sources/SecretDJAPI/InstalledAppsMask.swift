/// The `appmask` bitmask of companion apps installed on the device — the
/// server uses it to decide which action buttons to return (e.g. the Uber
/// deep-link action). Bit values are the wire contract, unchanged from the
/// legacy client (LEGACY.md "Backend API and Spotify integration";
/// `secretdjv3/URLSchemeHandler.swift:21-24`).
///
/// This type only models the parameter; app-side detection (URL-scheme
/// probing) arrives with the feature that needs it.
public struct InstalledAppsMask: OptionSet, Sendable, Hashable {
	public let rawValue: Int

	public init(rawValue: Int) {
		self.rawValue = rawValue
	}

	public static let facebook = InstalledAppsMask(rawValue: 1)
	public static let twitter = InstalledAppsMask(rawValue: 2)
	public static let uber = InstalledAppsMask(rawValue: 4)
	public static let instagram = InstalledAppsMask(rawValue: 8)
}
