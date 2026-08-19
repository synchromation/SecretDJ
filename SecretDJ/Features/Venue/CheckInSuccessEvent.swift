import Foundation

/// Fires when ``CheckInModel/checkIn()`` succeeds — the server's own
/// confirmation copy and optional hand-off URL, carried through unmodified
/// (D11 — server copy renders as-delivered verbatim). Purely a signal: the
/// caller decides what to show, mirrors ``SharedFeatures/LikeFailureEvent``'s
/// doc comment on why this stays a plain signal rather than owning
/// presentation itself.
struct CheckInSuccessEvent: Equatable {
	/// Increments on every occurrence, so two check-ins in a row (a
	/// reconnect after a rollback, say) are still distinct values for a
	/// SwiftUI `onChange(of:)` to react to.
	let id: Int
	let message: String?
	let url: URL?
}
