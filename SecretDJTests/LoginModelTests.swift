import Observability
import SecretDJAPI
import Testing

@testable import SecretDJ

@MainActor
enum LoginModelTests {
	private static func makeSessionStore() -> SessionStore {
		SessionStore(snapshotStore: InMemorySessionSnapshotStore(), credentialStore: InMemoryCredentialStore())
	}

	struct `Starting up` {
		@Test func `cannot sign in with empty fields`() {
			let model = LoginModel(
				authService: InMemoryAuthenticationService(),
				sessionStore: LoginModelTests.makeSessionStore(),
			)

			#expect(model.canSignIn == false)
		}
	}

	struct `Enabling sign in` {
		@Test func `cannot sign in with a short password`() {
			let model = LoginModel(
				authService: InMemoryAuthenticationService(),
				sessionStore: LoginModelTests.makeSessionStore(),
			)

			model.updateScreenName("TurboTim")
			model.updatePassword("1234")

			#expect(model.canSignIn == false)
		}

		@Test func `cannot sign in with an empty screen name`() {
			let model = LoginModel(
				authService: InMemoryAuthenticationService(),
				sessionStore: LoginModelTests.makeSessionStore(),
			)

			model.updatePassword("12345")

			#expect(model.canSignIn == false)
		}

		@Test func `can sign in once the screen name is set and the password reaches five characters`() {
			let model = LoginModel(
				authService: InMemoryAuthenticationService(),
				sessionStore: LoginModelTests.makeSessionStore(),
			)

			model.updateScreenName("TurboTim")
			model.updatePassword("12345")

			#expect(model.canSignIn == true)
		}
	}

	struct `Signing in` {
		@Test func `sends the screen name and the SHA-1 password hash`() async {
			let authService = InMemoryAuthenticationService(
				signInResult: .success(AuthenticatedSession(
					personId: "41",
					screenName: "TurboTim",
					rotatedToken: "tok",
				)),
			)
			let model = LoginModel(authService: authService, sessionStore: LoginModelTests.makeSessionStore())
			model.updateScreenName("TurboTim")
			model.updatePassword("hunter2")

			await model.signIn()

			let invocation = try? #require(authService.signInInvocations.first)
			#expect(invocation?.screenName == "TurboTim")
			#expect(invocation?.passwordHash == "f3bbbd66a63d4bf1747940578ec3d0103530e21d")
		}

		@Test func `does nothing when the fields don't allow signing in`() async {
			let authService = InMemoryAuthenticationService()
			let model = LoginModel(authService: authService, sessionStore: LoginModelTests.makeSessionStore())

			await model.signIn()

			#expect(authService.signInInvocations.isEmpty)
		}

		@Test func `signs the session in on success`() async {
			let sessionStore = LoginModelTests.makeSessionStore()
			let authService = InMemoryAuthenticationService(
				signInResult: .success(AuthenticatedSession(
					personId: "41",
					screenName: "TurboTim",
					rotatedToken: "tok",
				)),
			)
			let model = LoginModel(authService: authService, sessionStore: sessionStore)
			model.updateScreenName("TurboTim")
			model.updatePassword("12345")

			await model.signIn()

			#expect(sessionStore.user == SessionUser(personId: "41", screenName: "TurboTim"))
			#expect(sessionStore.credential?.token == "tok")
			#expect(sessionStore.isSignedIn == true)
		}

		@Test func `clears any previous error on success`() async {
			let authService = InMemoryAuthenticationService(
				signInResult: .success(AuthenticatedSession(
					personId: "41",
					screenName: "TurboTim",
					rotatedToken: "tok",
				)),
			)
			let model = LoginModel(authService: authService, sessionStore: LoginModelTests.makeSessionStore())
			model.updateScreenName("TurboTim")
			model.updatePassword("12345")

			await model.signIn()

			#expect(model.errorMessage == nil)
		}

		@Test func `surfaces the server's message on failure`() async {
			let sessionStore = LoginModelTests.makeSessionStore()
			let authService = InMemoryAuthenticationService(signInResult: .failure(.server(message: "Wrong password.")))
			let model = LoginModel(authService: authService, sessionStore: sessionStore)
			model.updateScreenName("TurboTim")
			model.updatePassword("12345")

			await model.signIn()

			#expect(model.errorMessage == "Wrong password.")
			#expect(sessionStore.isSignedIn == false)
		}

		@Test func `surfaces a fallback message on a connection failure`() async {
			let authService = InMemoryAuthenticationService(signInResult: .failure(.connection))
			let model = LoginModel(authService: authService, sessionStore: LoginModelTests.makeSessionStore())
			model.updateScreenName("TurboTim")
			model.updatePassword("12345")

			await model.signIn()

			#expect(model.errorMessage != nil)
		}
	}

	struct Instrumentation {
		@Test func `signing in leaves an interaction breadcrumb`() async {
			let recorder = RecordingDestination()
			let authService = InMemoryAuthenticationService(
				signInResult: .success(AuthenticatedSession(
					personId: "41",
					screenName: "TurboTim",
					rotatedToken: "tok",
				)),
			)
			let model = LoginModel(
				authService: authService,
				sessionStore: LoginModelTests.makeSessionStore(),
				observability: ObservabilityPipeline(destinations: [recorder]),
			)
			model.updateScreenName("TurboTim")
			model.updatePassword("12345")

			await model.signIn()

			#expect(recorder.breadcrumbs.contains(.interaction(description: "signIn")))
		}

		@Test func `a failed sign-in is reported, without logging the screen name or password`() async {
			let recorder = RecordingDestination()
			let authService = InMemoryAuthenticationService(signInResult: .failure(.server(message: "Wrong password.")))
			let model = LoginModel(
				authService: authService,
				sessionStore: LoginModelTests.makeSessionStore(),
				observability: ObservabilityPipeline(destinations: [recorder]),
			)
			model.updateScreenName("SensitiveScreenName")
			model.updatePassword("hunter2")

			await model.signIn()

			let diagnostics = recorder.events.compactMap { event -> String? in
				guard case .diagnostic(let diagnostic) = event else { return nil }
				return diagnostic.message
			}
			#expect(diagnostics.contains { $0.contains("SensitiveScreenName") } == false)
			#expect(diagnostics.contains { $0.contains("hunter2") } == false)
		}
	}
}
