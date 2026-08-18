import SecretDJDomain

/// Whether a companion social app is installed, probed by URL scheme — the
/// client-side half of the `appmask` signal (LEGACY.md "Backend API and
/// Spotify integration"; `secretdjv3/URLSchemeHandler.swift`). Detection
/// itself (URL-scheme probing) belongs to the consuming app; ``FeedActionRouter``
/// only consumes the answer, to decide whether a promotion's social profile
/// URL converts to a native deep link.
public protocol InstalledApps: Sendable {
	func isInstalled(_ platform: SocialPlatform) -> Bool
}
