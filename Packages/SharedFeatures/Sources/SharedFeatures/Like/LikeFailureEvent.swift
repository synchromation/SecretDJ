/// Fires when ``OptimisticLikeModel/toggle()`` rolls back after a failed
/// like/unlike call. Purely a signal: the caller turns it into a toast,
/// mirrors `FeedUI`'s `JukeboxChangedEvent` doc comment on why this stays a
/// plain signal rather than owning presentation itself.
public struct LikeFailureEvent: Equatable, Sendable {
	/// Increments on every occurrence, so two failures in a row are still
	/// distinct values for a SwiftUI `onChange(of:)` to react to.
	public let id: Int
	/// The server's own error copy (D11 — rendered as-delivered), or `nil`
	/// when the failure carried none (a connection error, or a server
	/// failure with no message) — this package owns zero copy of its own
	/// (mirrors ``MoodTileModel``'s doc comment: "the client owns no
	/// fallback copy of its own to show instead"), so the caller supplies
	/// its own localized fallback text from its own String Catalog when
	/// this is `nil`.
	public let message: String?

	public init(id: Int, message: String?) {
		self.id = id
		self.message = message
	}
}
