import Foundation
import SecretDJAPI
import SecretDJDomain

/// The production ``SettingsServicing``: calls straight through to
/// ``SecretDJAPI/APIClient``'s `userdetails`/`setuserdetails` endpoints,
/// mapping ``APIError`` to this feature's own ``SettingsError``.
struct APIClientSettingsService: SettingsServicing {
	private let client: APIClient

	init(client: APIClient) {
		self.client = client
	}

	func fetchDetails(userId: String, credential: APICredential) async throws(SettingsError) -> Person {
		do {
			let response = try await client.userDetails(userId: userId, credential: credential)
			return response.payload
		} catch {
			throw SettingsError(error)
		}
	}

	func changeDetails(
		userId: String,
		firstName: String,
		lastName: String,
		screenName: String,
		email: String,
		credential: APICredential,
	) async throws(SettingsError) -> SettingsUpdateOutcome {
		do {
			let response = try await client.setUserDetails(
				userId: userId,
				firstName: firstName,
				lastName: lastName,
				screenName: screenName,
				email: email,
				credential: credential,
			)
			return SettingsUpdateOutcome(
				succeeded: response.payload.returnCode == 0,
				message: response.payload.message,
				rotatedToken: response.rotatedToken,
			)
		} catch {
			throw SettingsError(error)
		}
	}

	func changePassword(
		userId: String,
		newPasswordHash: String,
		credential: APICredential,
	) async throws(SettingsError) -> SettingsUpdateOutcome {
		do {
			let response = try await client.setUserDetails(
				userId: userId,
				passwordHash: newPasswordHash,
				credential: credential,
			)
			return SettingsUpdateOutcome(
				succeeded: response.payload.returnCode == 0,
				message: response.payload.message,
				rotatedToken: response.rotatedToken,
			)
		} catch {
			throw SettingsError(error)
		}
	}
}
