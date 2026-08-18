import SecretDJAPI
import SecretDJDomain

/// The production ``AuthenticationServicing``: calls straight through to
/// ``SecretDJAPI/APIClient``'s auth endpoints, mapping ``APIError`` to this
/// feature's own ``AuthenticationError``.
struct APIClientAuthenticationService: AuthenticationServicing {
	private let client: APIClient

	init(client: APIClient) {
		self.client = client
	}

	func signIn(screenName: String, passwordHash: String) async throws(AuthenticationError) -> AuthenticatedSession {
		do {
			let response = try await client.signIn(screenName: screenName, passwordHash: passwordHash)
			return AuthenticatedSession(
				personId: response.payload.personId,
				screenName: response.payload.screenName,
				rotatedToken: response.rotatedToken,
			)
		} catch {
			throw AuthenticationError(error)
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
		do {
			let response = try await client.createUser(
				firstName: firstName,
				lastName: lastName,
				gender: gender,
				email: email,
				screenName: screenName,
				passwordHash: passwordHash,
			)
			return AuthenticatedSession(
				personId: response.payload.personId,
				screenName: response.payload.screenName,
				rotatedToken: response.rotatedToken,
			)
		} catch {
			throw AuthenticationError(error)
		}
	}

	func resetPassword(screenName: String) async throws(AuthenticationError) -> PasswordResetOutcome {
		do {
			let response = try await client.resetPassword(screenName: screenName)
			return PasswordResetOutcome(succeeded: response.payload.returnCode == 0, message: response.payload.message)
		} catch {
			throw AuthenticationError(error)
		}
	}

	func resetPassword(email: String) async throws(AuthenticationError) -> PasswordResetOutcome {
		do {
			let response = try await client.resetPassword(email: email)
			return PasswordResetOutcome(succeeded: response.payload.returnCode == 0, message: response.payload.message)
		} catch {
			throw AuthenticationError(error)
		}
	}
}
