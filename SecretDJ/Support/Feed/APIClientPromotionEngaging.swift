import SecretDJAPI

/// The production ``PromotionEngaging``: calls straight through to
/// ``SecretDJAPI/APIClient``'s `promote` endpoint, reading the signed-in
/// user/credential fresh on every call — never captured once at
/// construction time, matching ``APIClientFeedLoading/sessionFeed(sessionStore:locationService:endpoint:)``'s
/// doc comment — and rotating the session's token when the response
/// carries one. A `nil` `venueId` never reaches the transport at all
/// (``PromotionEngaging/engage(venueId:promotionId:)``'s own doc comment).
struct APIClientPromotionEngaging: PromotionEngaging {
	private let client: APIClient
	private let sessionStore: SessionStore

	init(client: APIClient, sessionStore: SessionStore) {
		self.client = client
		self.sessionStore = sessionStore
	}

	func engage(venueId: String?, promotionId: Int) async {
		guard let venueId else { return }

		let session = await MainActor.run { (sessionStore.user?.personId, sessionStore.credential) }
		guard let userId = session.0, let credential = session.1 else { return }

		guard let response = try? await client.promotionEngaged(
			userId: userId,
			venueId: venueId,
			promotionId: promotionId,
			credential: credential,
		) else { return }

		if let rotatedToken = response.rotatedToken {
			await MainActor.run { sessionStore.rotateToken(rotatedToken) }
		}
	}
}
