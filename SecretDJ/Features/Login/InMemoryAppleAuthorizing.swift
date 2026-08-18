/// A scriptable ``AppleAuthorizing`` fake for tests and previews — never
/// presents real AuthenticationServices UI.
@MainActor
final class InMemoryAppleAuthorizing: AppleAuthorizing {
	var result: Result<AppleAuthorizationResult, AppleAuthorizationError>

	private(set) var requestCount = 0

	init(result: Result<AppleAuthorizationResult, AppleAuthorizationError> = .failure(.failed)) {
		self.result = result
	}

	func requestSignIn() async throws(AppleAuthorizationError) -> AppleAuthorizationResult {
		requestCount += 1
		switch result {
		case .success(let value):
			return value

		case .failure(let error):
			throw error
		}
	}
}
