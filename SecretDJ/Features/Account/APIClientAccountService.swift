import Foundation
import SecretDJAPI

/// The production ``AccountServicing``: calls straight through to
/// ``SecretDJAPI/APIClient``'s `requestdeleteaccount` endpoint, mapping
/// ``APIError`` to this feature's own ``AccountError``.
struct APIClientAccountService: AccountServicing {
	private let client: APIClient

	init(client: APIClient) {
		self.client = client
	}

	func requestDeleteAccount(
		userId: String,
		credential: APICredential,
	) async throws(AccountError) -> AccountDeletionOutcome {
		do {
			let response = try await client.requestDeleteAccount(userId: userId, credential: credential)
			return AccountDeletionOutcome(message: response.payload.message)
		} catch {
			throw AccountError(error)
		}
	}
}
