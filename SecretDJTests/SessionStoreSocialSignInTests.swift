import SecretDJAPI
import Testing

@testable import SecretDJ

@MainActor
enum SessionStoreSocialSignInTests {
	private static func makeSessionStore() -> SessionStore {
		SessionStore(snapshotStore: InMemorySessionSnapshotStore(), credentialStore: InMemoryCredentialStore())
	}

	struct `Signing in from a social session` {
		@Test func `signs the session in when both a rotated token and an issued credential are present`() {
			let sessionStore = SessionStoreSocialSignInTests.makeSessionStore()
			let session = SocialAuthenticatedSession(
				personId: "41",
				screenName: "TurboTim",
				created: true,
				issuedCredential: "issued-credential",
				rotatedToken: "tok",
			)

			let result = sessionStore.signIn(from: session)

			#expect(result == true)
			#expect(sessionStore.user == SessionUser(personId: "41", screenName: "TurboTim"))
			#expect(sessionStore.credential?.passwordHash == "issued-credential")
			#expect(sessionStore.credential?.token == "tok")
		}

		@Test func `leaves the venue nil on success`() {
			let sessionStore = SessionStoreSocialSignInTests.makeSessionStore()
			let session = SocialAuthenticatedSession(
				personId: "41",
				screenName: "TurboTim",
				created: true,
				issuedCredential: "issued-credential",
				rotatedToken: "tok",
			)

			sessionStore.signIn(from: session)

			#expect(sessionStore.venue == nil)
		}

		@Test func `returns false and leaves the session signed out when there is no rotated token`() {
			let sessionStore = SessionStoreSocialSignInTests.makeSessionStore()
			let session = SocialAuthenticatedSession(
				personId: "41",
				screenName: "TurboTim",
				created: true,
				issuedCredential: "issued-credential",
				rotatedToken: nil,
			)

			let result = sessionStore.signIn(from: session)

			#expect(result == false)
			#expect(sessionStore.isSignedIn == false)
		}

		@Test func `returns false and leaves the session signed out when there is no issued credential`() {
			let sessionStore = SessionStoreSocialSignInTests.makeSessionStore()
			let session = SocialAuthenticatedSession(
				personId: "41",
				screenName: "TurboTim",
				created: true,
				issuedCredential: nil,
				rotatedToken: "tok",
			)

			let result = sessionStore.signIn(from: session)

			#expect(result == false)
			#expect(sessionStore.isSignedIn == false)
		}
	}
}
