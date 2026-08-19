/// A scriptable ``FacebookAuthorizing`` fake for tests and previews — never
/// touches the Facebook SDK.
@MainActor
final class InMemoryFacebookAuthorizing: FacebookAuthorizing {
	var result: Result<FacebookAuthorizationResult, FacebookAuthorizationError>

	private(set) var requestCount = 0

	init(result: Result<FacebookAuthorizationResult, FacebookAuthorizationError> = .failure(.failed)) {
		self.result = result
	}

	func requestSignIn() async throws(FacebookAuthorizationError) -> FacebookAuthorizationResult {
		requestCount += 1
		switch result {
		case .success(let value):
			return value

		case .failure(let error):
			throw error
		}
	}
}
