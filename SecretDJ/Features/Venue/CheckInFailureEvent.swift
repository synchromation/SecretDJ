/// Fires when ``CheckInModel/checkIn()`` rolls back after a failed call.
/// Purely a signal: the caller turns it into a toast, mirrors
/// ``SharedFeatures/LikeFailureEvent``'s doc comment.
struct CheckInFailureEvent: Equatable {
	/// Increments on every occurrence, so two failures in a row are still
	/// distinct values for a SwiftUI `onChange(of:)` to react to.
	let id: Int
	/// The server's own error copy (D11 — rendered as-delivered), or `nil`
	/// when the failure carried none (a connection error, or a server
	/// failure with no message) — this feature owns zero copy of its own
	/// (mirrors ``SharedFeatures/LikeFailureEvent``'s doc comment), so the
	/// caller supplies its own localized fallback text when this is `nil`.
	let message: String?
}
