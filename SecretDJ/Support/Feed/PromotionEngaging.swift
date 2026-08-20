import SecretDJAPI

/// The `promote` call every S6 feed screen fires for a URL-less promotion
/// tap (``FeedUI/FeedActionOutcome/engagePromotion(promotionId:)``, via
/// ``EngagePromotionOutcomeHandling``), thinned from ``SecretDJAPI/APIClient``
/// to this exact surface (ios-architecture: a protocol seam per real
/// dependency).
protocol PromotionEngaging: Sendable {
	/// Fires the tracking ping and returns — legacy's own doc comment on
	/// this endpoint: "don't care what the result was"
	/// (``SecretDJAPI/APIClient/promotionEngaged(userId:venueId:promotionId:credential:)``).
	/// A no-op, silently, when no session is signed in, when the call itself
	/// fails, and (``APIClientPromotionEngaging``'s own doc comment) when
	/// `venueId` is `nil` — a screen with no single venue in view (Places
	/// Nearby, Activity, Profile) has nothing to send the server, mirroring
	/// legacy's own venue-gated rule for this one action
	/// (`secretdjv3/FeedActionProvider.swift`'s `handle(item:barActions:venue:)`:
	/// a promotion tap with no `venue` in scope is dropped entirely).
	func engage(venueId: String?, promotionId: Int) async
}
