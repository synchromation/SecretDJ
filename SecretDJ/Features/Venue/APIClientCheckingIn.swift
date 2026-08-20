import Foundation
import SecretDJAPI

/// The production ``CheckingIn``: calls straight through to
/// ``SecretDJAPI/APIClient``'s `checkIn` endpoint, reading the signed-in
/// user/credential fresh on every call — never captured once at
/// construction time, matching ``APIClientFeedLoading/sessionFeed(sessionStore:locationService:endpoint:)``'s
/// doc comment — and rotating the session's token when the response carries
/// one. Mirrors ``APIClientLikeToggling``'s exact shape.
struct APIClientCheckingIn: CheckingIn {
	private let client: APIClient
	private let sessionStore: SessionStore

	init(client: APIClient, sessionStore: SessionStore) {
		self.client = client
		self.sessionStore = sessionStore
	}

	func checkIn(venueId: String) async throws(CheckInError) -> CheckInOutcome {
		let session = await MainActor.run { (sessionStore.user?.personId, sessionStore.credential) }
		guard let userId = session.0, let credential = session.1 else {
			throw .notSignedIn
		}

		do {
			let response = try await client.checkIn(userId: userId, venueId: venueId, credential: credential)
			if let rotatedToken = response.rotatedToken {
				await MainActor.run { sessionStore.rotateToken(rotatedToken) }
			}
			return CheckInOutcome(
				message: response.payload.text,
				url: response.payload.url.flatMap(URL.init),
				richToast: response.payload.data,
			)
		} catch {
			if case .server(let message) = error {
				throw .server(message: message)
			}
			throw .connection
		}
	}
}
