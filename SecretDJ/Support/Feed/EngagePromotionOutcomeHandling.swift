import FeedUI
import Observability

/// Every screen that forwards a ``FeedUI/FeedActionOutcome`` to
/// ``TabRouter`` calls this alongside ``HailRideOutcomeHandling``/
/// ``OpenURLOutcomeHandling``/``SocialAppOutcomeHandling`` — intercepting
/// ``FeedUI/FeedActionOutcome/engagePromotion(promotionId:)`` before it
/// reaches ``AppDestination/init(outcome:)`` (which returns `nil` for it)
/// and ``TabRouter``, which would otherwise silently drop it (S8.5
/// cross-check: previously only ``VenueScreen`` handled this outcome, since
/// it alone carried a ``PromotionEngaging`` dependency). `venueId` is
/// resolved by the caller, not here — `nil` on a screen with no single
/// venue in view (Places Nearby, Activity, Profile); ``PromotionEngaging``
/// decides what to do with that (its own doc comment).
enum EngagePromotionOutcomeHandling {
	/// Handles `outcome` and returns `true` when it's an `engagePromotion`
	/// hand-off; otherwise does nothing and returns `false`, leaving the
	/// caller to route `outcome` normally. The engagement call itself fires
	/// in an unstructured `Task` — this outcome carries no navigation and no
	/// screen state depends on its result (legacy's own "don't care what the
	/// result was"), matching ``VenueScreen``'s prior inline handling.
	@MainActor
	@discardableResult
	static func handle(
		_ outcome: FeedActionOutcome,
		venueId: String?,
		promotionEngaging: any PromotionEngaging,
		observability: ObservabilityPipeline,
	) -> Bool {
		guard case .engagePromotion(let promotionId) = outcome else { return false }

		observability.interaction("engagePromotion")
		Task { await promotionEngaging.engage(venueId: venueId, promotionId: promotionId) }
		return true
	}
}
