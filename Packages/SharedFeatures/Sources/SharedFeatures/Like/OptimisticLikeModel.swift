import Foundation
import Observability
import Observation
import SecretDJDomain

/// The like/unlike toggle every likeable item (venue, song, person) drives
/// through — S6.2 built it for the venue screen item-generic on purpose;
/// S6.3 (songs) embeds it unmodified here, and S6.6 (people) will construct
/// the same type unmodified too, only varying `itemId`/`type`/the initial
/// ``SecretDJDomain/LikeInfo``. Relocated from the consumer app's
/// `Support/Like` into SharedFeatures for S6.3b so TuneIn can embed it
/// directly (its own `APIClientLikeToggling` adapter stays consumer-side,
/// since it depends on `SecretDJAPI`/`SessionStore`, which SharedFeatures
/// never imports — ios-architecture). ``toggle()`` flips ``likeInfo``
/// immediately, then reconciles with the server: adopts its like-summary
/// copy on success (D11 — server copy renders as-delivered verbatim, never
/// re-worded client-side) or rolls back to the pre-toggle value on failure,
/// surfacing ``failureEvent`` for the caller to turn into a toast.
@MainActor
@Observable
public final class OptimisticLikeModel {
	public private(set) var likeInfo: LikeInfo
	/// Whether a toggle is currently in flight — guards ``toggle()`` against
	/// a second tap racing the first, and lets the view disable the control.
	public private(set) var isToggling = false
	/// Set each time a toggle rolls back; `nil` until the first failure. The
	/// caller observes this to show its own toast (mirrors
	/// `FeedUI`'s `FeedScreenModel.jukeboxChangedEvent` doc comment — a pure
	/// signal, presentation stays with the caller).
	public private(set) var failureEvent: LikeFailureEvent?

	private let itemId: String
	private let venueId: String?
	private let type: ItemType
	private let likeToggling: any LikeToggling
	private let observability: ObservabilityPipeline

	public init(
		itemId: String,
		venueId: String?,
		type: ItemType,
		likeInfo: LikeInfo,
		likeToggling: any LikeToggling,
		observability: ObservabilityPipeline = .disabled,
	) {
		self.itemId = itemId
		self.venueId = venueId
		self.type = type
		self.likeInfo = likeInfo
		self.likeToggling = likeToggling
		self.observability = observability
	}

	/// Flips ``likeInfo/likedByYou`` immediately, then calls like/unlike to
	/// match. A no-op while a previous call is still in flight — the
	/// double-tap guard — so two rapid taps only ever produce one network
	/// call and one state transition, not a torn optimistic flip.
	public func toggle() async {
		guard !isToggling else { return }

		isToggling = true
		defer { isToggling = false }

		observability.interaction("toggleLike")

		let previous = likeInfo
		let newLikedState = !previous.likedByYou
		likeInfo = LikeInfo(likedByYou: newLikedState, info: previous.info)

		do {
			let result = newLikedState
				? try await likeToggling.like(itemId: itemId, venueId: venueId, type: type)
				: try await likeToggling.unlike(itemId: itemId, venueId: venueId, type: type)
			likeInfo = LikeInfo(likedByYou: result.isLikedByYou, info: result.message)
			observability.track(newLikedState ? LikeEvent.liked : LikeEvent.unliked)
		} catch {
			likeInfo = previous
			observability.report(error, category: "Like")
			observability.track(LikeEvent.likeFailed)
			failureEvent = LikeFailureEvent(id: (failureEvent?.id ?? 0) + 1, message: message(for: error))
		}
	}

	/// The server's own error copy, when the failure carried one; `nil`
	/// otherwise (a connection error, or a server failure with no message) —
	/// left for the caller to fall back on its own copy, per
	/// ``LikeFailureEvent/message``'s doc comment.
	private func message(for error: LikeError) -> String? {
		if case .server(let message) = error {
			return message
		}
		return nil
	}

	/// Adopts a fresh server-sourced ``SecretDJDomain/LikeInfo`` — e.g. the
	/// venue screen's own venue payload republishing on every auto-refresh
	/// tick — so the displayed like state and summary copy stay current
	/// between this item's own toggles rather than freezing at whatever it
	/// looked like when this model was first constructed. Ignored while
	/// ``isToggling``: a refresh's snapshot necessarily predates an in-flight
	/// toggle's own optimistic flip or its eventual server answer, so
	/// applying it here would stomp one or the other.
	public func reconcile(with serverLikeInfo: LikeInfo) {
		guard !isToggling else { return }
		likeInfo = serverLikeInfo
	}
}
