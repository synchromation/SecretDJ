import Foundation
import Observability
import Observation
import SecretDJDomain

/// The like/unlike toggle every likeable item (venue, song, person) drives
/// through — S6.2 builds it for the venue screen; S6.3 (songs) and S6.6
/// (people) construct the same type unmodified, only varying `itemId`/
/// `type`/the initial ``SecretDJDomain/LikeInfo`` (ios-architecture: one
/// seam per real dependency, kept item-generic here because three real
/// features need the identical shape). ``toggle()`` flips ``likeInfo``
/// immediately, then reconciles with the server: adopts its like-summary
/// copy on success (D11 — server copy renders as-delivered verbatim, never
/// re-worded client-side) or rolls back to the pre-toggle value on failure,
/// surfacing ``failureEvent`` for the caller to turn into a toast.
@MainActor
@Observable
final class OptimisticLikeModel {
	private(set) var likeInfo: LikeInfo
	/// Whether a toggle is currently in flight — guards ``toggle()`` against
	/// a second tap racing the first, and lets the view disable the control.
	private(set) var isToggling = false
	/// Set each time a toggle rolls back; `nil` until the first failure. The
	/// app observes this to show its toast (mirrors
	/// ``FeedUI/FeedScreenModel/jukeboxChangedEvent``'s doc comment — a pure
	/// signal, presentation stays with the caller).
	private(set) var failureEvent: LikeFailureEvent?

	private let itemId: String
	private let venueId: String?
	private let type: ItemType
	private let likeToggling: any LikeToggling
	private let observability: ObservabilityPipeline

	init(
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
	func toggle() async {
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

	/// Adopts a fresh server-sourced ``SecretDJDomain/LikeInfo`` — e.g. the
	/// venue screen's own venue payload republishing on every auto-refresh
	/// tick, per ``FeedUI/FeedScreenModel/venueDetails``'s doc comment —
	/// so the displayed like state and summary copy stay current between
	/// this item's own toggles rather than freezing at whatever it looked
	/// like when this model was first constructed. Ignored while
	/// ``isToggling``: a refresh's snapshot necessarily predates an in-flight
	/// toggle's own optimistic flip or its eventual server answer, so
	/// applying it here would stomp one or the other.
	func reconcile(with serverLikeInfo: LikeInfo) {
		guard !isToggling else { return }
		likeInfo = serverLikeInfo
	}

	private func message(for error: LikeError) -> String {
		if case .server(let message) = error, let message {
			return message
		}
		return Self.fallbackFailureMessage
	}

	static var fallbackFailureMessage: String {
		String(
			localized: "Sorry, we couldn't update that — please try again.",
			comment: "Toast shown when liking or unliking something fails.",
		)
	}
}
