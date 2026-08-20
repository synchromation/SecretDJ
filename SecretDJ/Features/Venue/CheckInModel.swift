import Observability
import Observation

/// Venue check-in (LEGACY.md "Venue screen": "Check in ...: optimistic UI
/// (button disables), scope is always `.everyone`... Success toast/rich-toast
/// + optional URL come from the server; failure rolls back."). Unlike
/// ``SharedFeatures/OptimisticLikeModel``, this is one-directional — legacy
/// never offers an undo, so once ``checkedIn`` is `true` (optimistically or
/// from the server) ``checkIn()`` becomes a permanent no-op, matching the
/// legacy button's own permanent-disable behavior.
@MainActor
@Observable
final class CheckInModel {
	private(set) var checkedIn: Bool
	/// Whether a check-in call is currently in flight — guards ``checkIn()``
	/// against a second tap racing the first, and lets the view disable the
	/// control.
	private(set) var isCheckingIn = false
	/// Set each time ``checkIn()`` succeeds; `nil` until the first one. The
	/// caller decides how to present it — ``CheckInOutcome/url``, when
	/// present, takes priority over ``CheckInOutcome/message`` (this type's
	/// own doc comment).
	private(set) var successEvent: CheckInSuccessEvent?
	/// Set each time ``checkIn()`` rolls back after a failure; `nil` until
	/// the first one. The caller turns this into a toast.
	private(set) var failureEvent: CheckInFailureEvent?

	private let venueId: String
	private let checkingIn: any CheckingIn
	private let observability: ObservabilityPipeline

	init(
		venueId: String,
		checkedIn: Bool,
		checkingIn: any CheckingIn,
		observability: ObservabilityPipeline = .disabled,
	) {
		self.venueId = venueId
		self.checkedIn = checkedIn
		self.checkingIn = checkingIn
		self.observability = observability
	}

	/// Flips ``checkedIn`` immediately, then calls check-in to match. A
	/// no-op while ``isCheckingIn`` or once already ``checkedIn`` — the
	/// double-tap guard and the "no undo" rule both live in this one guard.
	func checkIn() async {
		guard !isCheckingIn, !checkedIn else { return }

		isCheckingIn = true
		defer { isCheckingIn = false }

		observability.interaction("checkIn")

		checkedIn = true

		do {
			let outcome = try await checkingIn.checkIn(venueId: venueId)
			observability.track(CheckInEvent.checkedIn)
			successEvent = CheckInSuccessEvent(
				id: (successEvent?.id ?? 0) + 1,
				message: outcome.message,
				url: outcome.url,
				richToast: outcome.richToast,
			)
		} catch {
			checkedIn = false
			observability.report(error, category: "CheckIn")
			observability.track(CheckInEvent.checkInFailed)
			failureEvent = CheckInFailureEvent(id: (failureEvent?.id ?? 0) + 1, message: message(for: error))
		}
	}

	/// The server's own error copy, when the failure carried one; `nil`
	/// otherwise, left for the caller to fall back on its own copy (mirrors
	/// ``SharedFeatures/OptimisticLikeModel``'s own `message(for:)`).
	private func message(for error: CheckInError) -> String? {
		if case .server(let message) = error {
			return message
		}
		return nil
	}

	/// Adopts a fresh server-sourced ``checkedIn`` flag — e.g. the venue
	/// screen's own venue payload republishing on every auto-refresh tick —
	/// without ever regressing an already-`true` state back to `false`:
	/// unlike ``SharedFeatures/OptimisticLikeModel/reconcile(with:)``'s
	/// bidirectional toggle, check-in only ever moves one way in this
	/// screen's lifetime, so a refresh that races a just-completed check-in
	/// (the server hasn't caught up yet) must never flicker the button back
	/// to enabled. Also ignored while ``isCheckingIn``, for the same reason
	/// ``SharedFeatures/OptimisticLikeModel``'s own reconcile is: a stale
	/// snapshot must not stomp an in-flight optimistic flip.
	func reconcile(with serverCheckedIn: Bool) {
		guard !isCheckingIn, !checkedIn else { return }
		checkedIn = serverCheckedIn
	}
}
