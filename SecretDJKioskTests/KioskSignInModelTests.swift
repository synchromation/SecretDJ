import Observability
import SecretDJAPI
import Testing

@testable import SecretDJKiosk

/// Covers ``KioskSignInModel`` — the kiosk's venue sign-in, over
/// ``InMemoryKioskSignInService`` (ios-architecture: models are tested
/// without networking). Mirrors the shape of the consumer's
/// `LoginModelTests`, minus every consumer-only concern (no minimum
/// password length, no sign-up/social routes — LEGACY.md's kiosk login is
/// screen name + password only).
@MainActor
enum KioskSignInModelTests {
	private static func makeSessionStore() -> SessionStore {
		SessionStore(snapshotStore: InMemorySessionSnapshotStore(), credentialStore: InMemoryCredentialStore())
	}

	struct `Starting up` {
		@Test func `cannot sign in with empty fields`() {
			let model = KioskSignInModel(
				signInService: InMemoryKioskSignInService(),
				sessionStore: KioskSignInModelTests.makeSessionStore(),
			)

			#expect(model.canSignIn == false)
		}

		@Test func `can sign in once both fields are non-empty, with no minimum password length`() {
			let model = KioskSignInModel(
				signInService: InMemoryKioskSignInService(),
				sessionStore: KioskSignInModelTests.makeSessionStore(),
			)

			model.updateScreenName("TheDuke")
			model.updatePassword("ab")

			#expect(model.canSignIn == true)
		}
	}

	struct `Signing in` {
		@Test func `sends the screen name and the SHA-1 password hash`() async {
			let signInService = InMemoryKioskSignInService(
				signInResult: .success(KioskAuthenticatedSession(
					personId: "41",
					screenName: "TheDuke",
					forcedVenueId: "v1",
					rotatedToken: "tok",
				)),
			)
			let model = KioskSignInModel(
				signInService: signInService,
				sessionStore: KioskSignInModelTests.makeSessionStore(),
			)
			model.updateScreenName("TheDuke")
			model.updatePassword("hunter2")

			await model.signIn()

			let invocation = try? #require(signInService.signInInvocations.first)
			#expect(invocation?.screenName == "TheDuke")
			#expect(invocation?.passwordHash == "f3bbbd66a63d4bf1747940578ec3d0103530e21d")
		}

		@Test func `does nothing when the fields don't allow signing in`() async {
			let signInService = InMemoryKioskSignInService()
			let model = KioskSignInModel(
				signInService: signInService,
				sessionStore: KioskSignInModelTests.makeSessionStore(),
			)

			await model.signIn()

			#expect(signInService.signInInvocations.isEmpty)
		}

		@Test func `signs the session in with the forced venue on success`() async {
			let sessionStore = KioskSignInModelTests.makeSessionStore()
			let signInService = InMemoryKioskSignInService(
				signInResult: .success(KioskAuthenticatedSession(
					personId: "41",
					screenName: "TheDuke",
					forcedVenueId: "00002162_f22f602a",
					rotatedToken: "tok",
				)),
			)
			let model = KioskSignInModel(signInService: signInService, sessionStore: sessionStore)
			model.updateScreenName("TheDuke")
			model.updatePassword("hunter2")

			await model.signIn()

			#expect(sessionStore.user == SessionUser(personId: "41", screenName: "TheDuke"))
			#expect(sessionStore.venue?.venueId == "00002162_f22f602a")
			#expect(sessionStore.isSignedIn == true)
		}

		@Test func `surfaces the server's message on failure`() async {
			let sessionStore = KioskSignInModelTests.makeSessionStore()
			let signInService = InMemoryKioskSignInService(signInResult: .failure(.server(message: "Wrong password.")))
			let model = KioskSignInModel(signInService: signInService, sessionStore: sessionStore)
			model.updateScreenName("TheDuke")
			model.updatePassword("hunter2")

			await model.signIn()

			#expect(model.errorMessage == "Wrong password.")
			#expect(sessionStore.isSignedIn == false)
		}

		@Test func `surfaces a fallback message on a connection failure`() async {
			let signInService = InMemoryKioskSignInService(signInResult: .failure(.connection))
			let model = KioskSignInModel(
				signInService: signInService,
				sessionStore: KioskSignInModelTests.makeSessionStore(),
			)
			model.updateScreenName("TheDuke")
			model.updatePassword("hunter2")

			await model.signIn()

			#expect(model.errorMessage != nil)
		}

		@Test func `surfaces a dedicated message when the account isn't a venue account`() async {
			let signInService = InMemoryKioskSignInService(signInResult: .failure(.notAVenueAccount))
			let model = KioskSignInModel(
				signInService: signInService,
				sessionStore: KioskSignInModelTests.makeSessionStore(),
			)
			model.updateScreenName("TheDuke")
			model.updatePassword("hunter2")

			await model.signIn()

			#expect(model.errorMessage != nil)
		}
	}

	struct Instrumentation {
		@Test func `signing in leaves an interaction breadcrumb`() async {
			let recorder = RecordingDestination()
			let signInService = InMemoryKioskSignInService(
				signInResult: .success(KioskAuthenticatedSession(
					personId: "41",
					screenName: "TheDuke",
					forcedVenueId: "v1",
					rotatedToken: "tok",
				)),
			)
			let model = KioskSignInModel(
				signInService: signInService,
				sessionStore: KioskSignInModelTests.makeSessionStore(),
				observability: ObservabilityPipeline(destinations: [recorder]),
			)
			model.updateScreenName("TheDuke")
			model.updatePassword("hunter2")

			await model.signIn()

			#expect(recorder.breadcrumbs.contains(.interaction(description: "signIn")))
		}
	}
}
