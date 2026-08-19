import Foundation
import SecretDJAPI

/// One recorded call to ``InMemoryAccountService/requestDeleteAccount``.
struct RequestDeleteAccountInvocation: Equatable {
	let userId: String
	let credential: APICredential
}

/// A scriptable ``AccountServicing`` fake for tests and previews — never
/// touches the network. Deletion is a destructive write, so this is the
/// only way the app ever exercises this call outside a live smoke test
/// (never automated, given the endpoint's consequences).
@MainActor
final class InMemoryAccountService: AccountServicing {
	var requestDeleteAccountResult: Result<AccountDeletionOutcome, AccountError>

	private(set) var requestDeleteAccountInvocations: [RequestDeleteAccountInvocation] = []

	init(requestDeleteAccountResult: Result<AccountDeletionOutcome, AccountError> = .failure(.connection)) {
		self.requestDeleteAccountResult = requestDeleteAccountResult
	}

	func requestDeleteAccount(
		userId: String,
		credential: APICredential,
	) async throws(AccountError) -> AccountDeletionOutcome {
		requestDeleteAccountInvocations.append(RequestDeleteAccountInvocation(userId: userId, credential: credential))
		switch requestDeleteAccountResult {
		case .success(let outcome):
			return outcome

		case .failure(let error):
			throw error
		}
	}
}
