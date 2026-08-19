/// A scriptable ``KioskSignInServicing`` fake for tests and previews —
/// never touches the network. Records its arguments and returns the
/// configured result, so tests can both seed outcomes and assert on what
/// was sent (mirrors the consumer's own `InMemoryAuthenticationService`).
@MainActor
final class InMemoryKioskSignInService: KioskSignInServicing {
	var signInResult: Result<KioskAuthenticatedSession, KioskSignInError>

	private(set) var signInInvocations: [(screenName: String, passwordHash: String)] = []

	init(signInResult: Result<KioskAuthenticatedSession, KioskSignInError> = .failure(.connection)) {
		self.signInResult = signInResult
	}

	func signIn(screenName: String, passwordHash: String) async throws(KioskSignInError) -> KioskAuthenticatedSession {
		signInInvocations.append((screenName: screenName, passwordHash: passwordHash))
		switch signInResult {
		case .success(let session):
			return session

		case .failure(let error):
			throw error
		}
	}
}
