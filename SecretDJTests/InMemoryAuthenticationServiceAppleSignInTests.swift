import Testing

@testable import SecretDJ

@MainActor
enum InMemoryAuthenticationServiceAppleSignInTests {
	struct `Apple sign-in` {
		@Test func `records the full invocation`() async throws {
			let service = InMemoryAuthenticationService(
				appleSignInResult: .success(AppleAuthenticatedSession(
					personId: "41",
					screenName: "TurboTim",
					created: true,
					issuedCredential: "issued-credential",
					rotatedToken: "tok",
				)),
			)

			_ = try await service.appleSignIn(
				appleUserId: "apple-user-id",
				auth: "auth-digest",
				firstName: "Turbo",
				lastName: "Tim",
				email: "turbo@example.com",
			)

			let invocation = try #require(service.appleSignInInvocations.first)
			#expect(invocation.appleUserId == "apple-user-id")
			#expect(invocation.auth == "auth-digest")
			#expect(invocation.firstName == "Turbo")
			#expect(invocation.lastName == "Tim")
			#expect(invocation.email == "turbo@example.com")
		}

		@Test func `returns the scripted success value`() async throws {
			let session = AppleAuthenticatedSession(
				personId: "41",
				screenName: "TurboTim",
				created: true,
				issuedCredential: "issued-credential",
				rotatedToken: "tok",
			)
			let service = InMemoryAuthenticationService(appleSignInResult: .success(session))

			let result = try await service.appleSignIn(
				appleUserId: "apple-user-id",
				auth: "auth-digest",
				firstName: nil,
				lastName: nil,
				email: nil,
			)

			#expect(result == session)
		}

		@Test func `throws the scripted failure value`() async {
			let service = InMemoryAuthenticationService(appleSignInResult: .failure(.server(message: "Nope.")))

			await #expect(throws: AuthenticationError.server(message: "Nope.")) {
				try await service.appleSignIn(
					appleUserId: "apple-user-id",
					auth: "auth-digest",
					firstName: nil,
					lastName: nil,
					email: nil,
				)
			}
		}
	}
}
