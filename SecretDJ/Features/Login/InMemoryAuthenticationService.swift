import SecretDJDomain

/// One recorded call to ``InMemoryAuthenticationService/createUser``.
struct CreateUserInvocation: Equatable {
	let firstName: String
	let lastName: String
	let gender: Gender
	let email: String
	let screenName: String
	let passwordHash: String
}

/// One recorded call to ``InMemoryAuthenticationService/appleSignIn``.
struct AppleSignInInvocation: Equatable {
	let appleUserId: String
	let auth: String
	let firstName: String?
	let lastName: String?
	let email: String?
}

/// One recorded call to ``InMemoryAuthenticationService/facebookSignIn``.
struct FacebookSignInInvocation: Equatable {
	let facebookUserId: String
	let accessToken: String
	let auth: String
	let gender: Gender?
	let firstName: String?
	let lastName: String?
	let email: String?
}

/// A scriptable ``AuthenticationServicing`` fake for tests and previews —
/// never touches the network. Each call records its arguments and returns
/// the result configured for it, so tests can both seed outcomes and assert
/// on what was sent.
@MainActor
final class InMemoryAuthenticationService: AuthenticationServicing {
	var signInResult: Result<AuthenticatedSession, AuthenticationError>
	var createUserResult: Result<AuthenticatedSession, AuthenticationError>
	var resetPasswordResult: Result<PasswordResetOutcome, AuthenticationError>
	var appleSignInResult: Result<SocialAuthenticatedSession, AuthenticationError>
	var facebookSignInResult: Result<SocialAuthenticatedSession, AuthenticationError>

	private(set) var signInInvocations: [(screenName: String, passwordHash: String)] = []
	private(set) var createUserInvocations: [CreateUserInvocation] = []
	private(set) var resetPasswordScreenNameInvocations: [String] = []
	private(set) var resetPasswordEmailInvocations: [String] = []
	private(set) var appleSignInInvocations: [AppleSignInInvocation] = []
	private(set) var facebookSignInInvocations: [FacebookSignInInvocation] = []

	init(
		signInResult: Result<AuthenticatedSession, AuthenticationError> = .failure(.connection),
		createUserResult: Result<AuthenticatedSession, AuthenticationError> = .failure(.connection),
		resetPasswordResult: Result<PasswordResetOutcome, AuthenticationError> = .failure(.connection),
		appleSignInResult: Result<SocialAuthenticatedSession, AuthenticationError> = .failure(.connection),
		facebookSignInResult: Result<SocialAuthenticatedSession, AuthenticationError> = .failure(.connection),
	) {
		self.signInResult = signInResult
		self.createUserResult = createUserResult
		self.resetPasswordResult = resetPasswordResult
		self.appleSignInResult = appleSignInResult
		self.facebookSignInResult = facebookSignInResult
	}

	func signIn(screenName: String, passwordHash: String) async throws(AuthenticationError) -> AuthenticatedSession {
		signInInvocations.append((screenName: screenName, passwordHash: passwordHash))
		switch signInResult {
		case .success(let session):
			return session

		case .failure(let error):
			throw error
		}
	}

	func createUser(
		firstName: String,
		lastName: String,
		gender: Gender,
		email: String,
		screenName: String,
		passwordHash: String,
	) async throws(AuthenticationError) -> AuthenticatedSession {
		createUserInvocations.append(CreateUserInvocation(
			firstName: firstName,
			lastName: lastName,
			gender: gender,
			email: email,
			screenName: screenName,
			passwordHash: passwordHash,
		))
		switch createUserResult {
		case .success(let session):
			return session

		case .failure(let error):
			throw error
		}
	}

	func resetPassword(screenName: String) async throws(AuthenticationError) -> PasswordResetOutcome {
		resetPasswordScreenNameInvocations.append(screenName)
		switch resetPasswordResult {
		case .success(let outcome):
			return outcome

		case .failure(let error):
			throw error
		}
	}

	func resetPassword(email: String) async throws(AuthenticationError) -> PasswordResetOutcome {
		resetPasswordEmailInvocations.append(email)
		switch resetPasswordResult {
		case .success(let outcome):
			return outcome

		case .failure(let error):
			throw error
		}
	}

	func appleSignIn(
		appleUserId: String,
		auth: String,
		firstName: String?,
		lastName: String?,
		email: String?,
	) async throws(AuthenticationError) -> SocialAuthenticatedSession {
		appleSignInInvocations.append(AppleSignInInvocation(
			appleUserId: appleUserId,
			auth: auth,
			firstName: firstName,
			lastName: lastName,
			email: email,
		))
		switch appleSignInResult {
		case .success(let session):
			return session

		case .failure(let error):
			throw error
		}
	}

	func facebookSignIn(
		facebookUserId: String,
		accessToken: String,
		auth: String,
		gender: Gender?,
		firstName: String?,
		lastName: String?,
		email: String?,
	) async throws(AuthenticationError) -> SocialAuthenticatedSession {
		facebookSignInInvocations.append(FacebookSignInInvocation(
			facebookUserId: facebookUserId,
			accessToken: accessToken,
			auth: auth,
			gender: gender,
			firstName: firstName,
			lastName: lastName,
			email: email,
		))
		switch facebookSignInResult {
		case .success(let session):
			return session

		case .failure(let error):
			throw error
		}
	}
}
