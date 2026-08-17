/// The server's opaque change-detection token for a feed's content.
///
/// Two equal hashes mean the feed is unchanged; a different hash signals the
/// feed needs to be refetched.
public struct FeedHash: Hashable, Sendable {
	/// The token exactly as the server returned it.
	public let rawValue: String

	/// Wraps a hash value already retrieved from the server.
	public init(rawValue: String) {
		self.rawValue = rawValue
	}
}
