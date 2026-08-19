import Foundation
import SecretDJAPI
import SecretDJDomain

/// One recorded call to ``InMemorySettingsService/fetchDetails``.
struct FetchDetailsInvocation: Equatable {
	let userId: String
	let credential: APICredential
}

/// One recorded call to ``InMemorySettingsService/changeDetails``.
struct ChangeDetailsInvocation: Equatable {
	let userId: String
	let firstName: String
	let lastName: String
	let screenName: String
	let email: String
	let credential: APICredential
}

/// One recorded call to ``InMemorySettingsService/changePassword``.
struct ChangePasswordInvocation: Equatable {
	let userId: String
	let newPasswordHash: String
	let credential: APICredential
}

/// A scriptable ``SettingsServicing`` fake for tests and previews — never
/// touches the network. Each call records its arguments and returns the
/// result configured for it, so tests can both seed outcomes and assert on
/// what was sent.
@MainActor
final class InMemorySettingsService: SettingsServicing {
	var fetchDetailsResult: Result<Person, SettingsError>
	var changeDetailsResult: Result<SettingsUpdateOutcome, SettingsError>
	var changePasswordResult: Result<SettingsUpdateOutcome, SettingsError>

	private(set) var fetchDetailsInvocations: [FetchDetailsInvocation] = []
	private(set) var changeDetailsInvocations: [ChangeDetailsInvocation] = []
	private(set) var changePasswordInvocations: [ChangePasswordInvocation] = []

	init(
		fetchDetailsResult: Result<Person, SettingsError> = .failure(.connection),
		changeDetailsResult: Result<SettingsUpdateOutcome, SettingsError> = .failure(.connection),
		changePasswordResult: Result<SettingsUpdateOutcome, SettingsError> = .failure(.connection),
	) {
		self.fetchDetailsResult = fetchDetailsResult
		self.changeDetailsResult = changeDetailsResult
		self.changePasswordResult = changePasswordResult
	}

	func fetchDetails(userId: String, credential: APICredential) async throws(SettingsError) -> Person {
		fetchDetailsInvocations.append(FetchDetailsInvocation(userId: userId, credential: credential))
		switch fetchDetailsResult {
		case .success(let person):
			return person

		case .failure(let error):
			throw error
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
		changeDetailsInvocations.append(ChangeDetailsInvocation(
			userId: userId,
			firstName: firstName,
			lastName: lastName,
			screenName: screenName,
			email: email,
			credential: credential,
		))
		switch changeDetailsResult {
		case .success(let outcome):
			return outcome

		case .failure(let error):
			throw error
		}
	}

	func changePassword(
		userId: String,
		newPasswordHash: String,
		credential: APICredential,
	) async throws(SettingsError) -> SettingsUpdateOutcome {
		changePasswordInvocations.append(ChangePasswordInvocation(
			userId: userId,
			newPasswordHash: newPasswordHash,
			credential: credential,
		))
		switch changePasswordResult {
		case .success(let outcome):
			return outcome

		case .failure(let error):
			throw error
		}
	}
}
