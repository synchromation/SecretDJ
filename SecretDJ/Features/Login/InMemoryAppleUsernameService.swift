import SecretDJAPI

/// One recorded call to ``InMemoryAppleUsernameService/setScreenName``.
struct SetScreenNameInvocation: Equatable {
	let userId: String
	let screenName: String
	let credential: APICredential
}

/// A scriptable ``AppleUsernameServicing`` fake for tests and previews —
/// never touches the network. Each call records its arguments and returns
/// the result configured for it, so tests can both seed outcomes and assert
/// on what was sent.
@MainActor
final class InMemoryAppleUsernameService: AppleUsernameServicing {
	var setScreenNameResult: Result<ScreenNameUpdateOutcome, AuthenticationError>
	private(set) var setScreenNameInvocations: [SetScreenNameInvocation] = []

	init(setScreenNameResult: Result<ScreenNameUpdateOutcome, AuthenticationError> = .failure(.connection)) {
		self.setScreenNameResult = setScreenNameResult
	}

	func setScreenName(
		userId: String,
		screenName: String,
		credential: APICredential,
	) async throws(AuthenticationError) -> ScreenNameUpdateOutcome {
		setScreenNameInvocations.append(SetScreenNameInvocation(
			userId: userId,
			screenName: screenName,
			credential: credential,
		))
		switch setScreenNameResult {
		case .success(let outcome):
			return outcome

		case .failure(let error):
			throw error
		}
	}
}
