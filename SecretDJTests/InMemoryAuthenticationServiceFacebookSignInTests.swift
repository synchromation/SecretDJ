import SecretDJDomain
import Testing

@testable import SecretDJ

@MainActor
enum InMemoryAuthenticationServiceFacebookSignInTests {
	struct `Facebook sign-in` {
		@Test func `records the full invocation`() async throws {
			let service = InMemoryAuthenticationService(
				facebookSignInResult: .success(SocialAuthenticatedSession(
					personId: "41",
					screenName: "TurboTim",
					created: true,
					issuedCredential: "issued-credential",
					rotatedToken: "tok",
				)),
			)

			_ = try await service.facebookSignIn(
				facebookUserId: "facebook-user-id",
				accessToken: "fb-token",
				auth: "auth-digest",
				gender: .female,
				firstName: "Turbo",
				lastName: "Tim",
				email: "turbo@example.com",
			)

			let invocation = try #require(service.facebookSignInInvocations.first)
			#expect(invocation.facebookUserId == "facebook-user-id")
			#expect(invocation.accessToken == "fb-token")
			#expect(invocation.auth == "auth-digest")
			#expect(invocation.gender == .female)
			#expect(invocation.firstName == "Turbo")
			#expect(invocation.lastName == "Tim")
			#expect(invocation.email == "turbo@example.com")
		}

		@Test func `returns the scripted success value`() async throws {
			let session = SocialAuthenticatedSession(
				personId: "41",
				screenName: "TurboTim",
				created: true,
				issuedCredential: "issued-credential",
				rotatedToken: "tok",
			)
			let service = InMemoryAuthenticationService(facebookSignInResult: .success(session))

			let result = try await service.facebookSignIn(
				facebookUserId: "facebook-user-id",
				accessToken: "fb-token",
				auth: "auth-digest",
				gender: nil,
				firstName: nil,
				lastName: nil,
				email: nil,
			)

			#expect(result == session)
		}

		@Test func `throws the scripted failure value`() async {
			let service = InMemoryAuthenticationService(facebookSignInResult: .failure(.server(message: "Nope.")))

			await #expect(throws: AuthenticationError.server(message: "Nope.")) {
				try await service.facebookSignIn(
					facebookUserId: "facebook-user-id",
					accessToken: "fb-token",
					auth: "auth-digest",
					gender: nil,
					firstName: nil,
					lastName: nil,
					email: nil,
				)
			}
		}
	}
}
