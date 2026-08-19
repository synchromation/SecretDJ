/// Fires when ``OptimisticLikeModel/toggle()`` rolls back after a failed
/// like/unlike call. Purely a signal: the app turns it into a toast
/// (`message` is already display-ready — the server's own error copy, or a
/// client-side fallback), mirrors `FeedUI`'s ``FeedUI/JukeboxChangedEvent``
/// doc comment on why this stays a plain signal rather than owning
/// presentation itself.
struct LikeFailureEvent: Equatable {
	/// Increments on every occurrence, so two failures in a row are still
	/// distinct values for a SwiftUI `onChange(of:)` to react to.
	let id: Int
	let message: String
}
