import Foundation
import SecretDJAPI
import SecretDJDomain

/// One recorded call to ``InMemoryOnboardingService/setGender``.
struct SetGenderInvocation: Equatable {
	let userId: String
	let gender: Gender
	let credential: APICredential
}

/// One recorded call to ``InMemoryOnboardingService/uploadAvatar``.
struct UploadAvatarInvocation: Equatable {
	let userId: String
	let imageData: Data
	let credential: APICredential
}

/// A scriptable ``OnboardingServicing`` fake for tests and previews — never
/// touches the network. Each call records its arguments and returns the
/// result configured for it, so tests can both seed outcomes and assert on
/// what was sent.
@MainActor
final class InMemoryOnboardingService: OnboardingServicing {
	var setGenderResult: Result<OnboardingUpdateOutcome, OnboardingError>
	var uploadAvatarResult: Result<AvatarUploadOutcome, OnboardingError>

	private(set) var setGenderInvocations: [SetGenderInvocation] = []
	private(set) var uploadAvatarInvocations: [UploadAvatarInvocation] = []

	init(
		setGenderResult: Result<OnboardingUpdateOutcome, OnboardingError> = .failure(.connection),
		uploadAvatarResult: Result<AvatarUploadOutcome, OnboardingError> = .failure(.connection),
	) {
		self.setGenderResult = setGenderResult
		self.uploadAvatarResult = uploadAvatarResult
	}

	func setGender(
		userId: String,
		gender: Gender,
		credential: APICredential,
	) async throws(OnboardingError) -> OnboardingUpdateOutcome {
		setGenderInvocations.append(SetGenderInvocation(userId: userId, gender: gender, credential: credential))
		switch setGenderResult {
		case .success(let outcome):
			return outcome

		case .failure(let error):
			throw error
		}
	}

	func uploadAvatar(
		userId: String,
		imageData: Data,
		credential: APICredential,
	) async throws(OnboardingError) -> AvatarUploadOutcome {
		uploadAvatarInvocations.append(UploadAvatarInvocation(
			userId: userId,
			imageData: imageData,
			credential: credential,
		))
		switch uploadAvatarResult {
		case .success(let outcome):
			return outcome

		case .failure(let error):
			throw error
		}
	}
}
