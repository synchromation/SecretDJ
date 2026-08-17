import SecretDJDomain

/// Whether a feed's previously cached hash still matches the server's latest
/// hash — the signal that a feed needs to reload its content.
public struct FeedRenderState: Equatable, Sendable {
	/// `true` when `cached` and `latest` differ, meaning the feed changed.
	public let needsReload: Bool

	/// Compares a feed's previously cached hash against the server's latest.
	public init(cached: FeedHash, latest: FeedHash) {
		needsReload = cached != latest
	}
}
