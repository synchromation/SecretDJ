import SecretDJDomain

/// Fires when a request or moderation call resolves with copy to show —
/// the server's own success/failure/moderation-result text (D11 — rendered
/// as-delivered), or (for a transport failure) a client-side fallback the
/// caller supplies since this package owns no copy of its own (mirrors
/// ``LikeFailureEvent``'s doc comment). Purely a signal: the caller turns it
/// into a toast.
public struct TuneInToastEvent: Equatable, Sendable {
	/// Increments on every occurrence, so two toasts in a row are still
	/// distinct values for a SwiftUI `onChange(of:)` to react to.
	public let id: Int
	public let message: String
	/// The same request's optional `Response.Data` award payload (S8.6) —
	/// only ever non-nil on a successful request
	/// (``TuneInScreenModel/requestSong()``'s own doc comment), never on a
	/// moderation result or a failure. Whether this actually renders as a
	/// rich toast is the presenting layer's call
	/// (``SharedFeatures/TuneInScreen``'s `showsRichToasts` doc comment) —
	/// the kiosk never does (`secretdjv3/KioskTuneInViewController.swift`'s
	/// `jukeboxButtonTapped` never calls `handleRichToast`).
	public let richToast: RichToastData?

	public init(id: Int, message: String, richToast: RichToastData? = nil) {
		self.id = id
		self.message = message
		self.richToast = richToast
	}
}
