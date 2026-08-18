import Foundation
import SecretDJAPI
import SecretDJDomain

/// The production ``OnboardingServicing``: calls straight through to
/// ``SecretDJAPI/APIClient``'s profile endpoints, mapping ``APIError`` to
/// this feature's own ``OnboardingError``.
struct APIClientOnboardingService: OnboardingServicing {
	private let client: APIClient

	init(client: APIClient) {
		self.client = client
	}

	func setGender(
		userId: String,
		gender: Gender,
		credential: APICredential,
	) async throws(OnboardingError) -> OnboardingUpdateOutcome {
		do {
			let response = try await client.setUserDetails(userId: userId, gender: gender, credential: credential)
			return OnboardingUpdateOutcome(
				succeeded: response.payload.returnCode == 0,
				message: response.payload.message,
				rotatedToken: response.rotatedToken,
			)
		} catch {
			throw OnboardingError(error)
		}
	}

	func uploadAvatar(
		userId: String,
		imageData: Data,
		credential: APICredential,
	) async throws(OnboardingError) -> AvatarUploadOutcome {
		do {
			let response = try await client.uploadAvatar(userId: userId, imageData: imageData, credential: credential)
			return AvatarUploadOutcome(rewardMessage: response.payload.text, rotatedToken: response.rotatedToken)
		} catch {
			throw OnboardingError(error)
		}
	}
}
