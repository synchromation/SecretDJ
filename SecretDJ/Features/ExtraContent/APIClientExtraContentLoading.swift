import SecretDJAPI
import SecretDJDomain

/// The production ``ExtraContentLoading``: calls straight through to
/// ``SecretDJAPI/APIClient``'s `extracontent` endpoint, reading the
/// signed-in user/credential fresh on every call — never captured once at
/// construction time, matching
/// ``APIClientFeedLoading/sessionFeed(sessionStore:locationService:endpoint:)``'s
/// doc comment — and rotating the session's token when the response carries
/// one. Mirrors ``APIClientCheckingIn``'s exact shape.
struct APIClientExtraContentLoading: ExtraContentLoading {
	private let client: APIClient
	private let sessionStore: SessionStore

	init(client: APIClient, sessionStore: SessionStore) {
		self.client = client
		self.sessionStore = sessionStore
	}

	func loadExtraContent(venueId: String?, screen: ExtraContentScreen) async throws -> [Item] {
		let session = await MainActor.run { (sessionStore.user?.personId, sessionStore.credential) }
		guard let userId = session.0, let credential = session.1 else {
			throw NotSignedInExtraContentLoadingError()
		}

		let response = try await client.extraContent(
			userId: userId,
			venueId: venueId,
			screen: screen,
			credential: credential,
		)

		if let rotatedToken = response.rotatedToken {
			await MainActor.run { sessionStore.rotateToken(rotatedToken) }
		}

		return response.payload.sections.first?.items ?? []
	}
}

/// Thrown by ``APIClientExtraContentLoading`` when no session is signed in
/// at the moment a load fires — e.g. a pending rotation-triggered refetch
/// outliving a sign-out. Mirrors `NotSignedInFeedLoadingError`'s doc
/// comment: a defensive guard against that race, not a state the ticker
/// needs to render (fetch failures never surface to the UI —
/// ``ExtraContentModel/fetch()``'s doc comment).
struct NotSignedInExtraContentLoadingError: Error, Equatable {}
