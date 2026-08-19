import SecretDJAPI

/// The `promote` call ``VenueScreen`` fires for a URL-less promotion tap
/// (``FeedUI/FeedActionOutcome/engagePromotion(promotionId:)``), thinned
/// from ``SecretDJAPI/APIClient`` to this exact surface (ios-architecture:
/// a protocol seam per real dependency).
protocol PromotionEngaging: Sendable {
	/// Fires the tracking ping and returns — legacy's own doc comment on
	/// this endpoint: "don't care what the result was"
	/// (``SecretDJAPI/APIClient/promotionEngaged(userId:venueId:promotionId:credential:)``).
	/// A no-op, silently, both when no session is signed in and when the
	/// call itself fails.
	func engage(venueId: String, promotionId: Int) async
}
