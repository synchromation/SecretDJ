import Observability
import SecretDJAPI
import SecretDJDomain
import Testing

@testable import SecretDJ

@MainActor
enum SignUpModelTests {
	private static func makeSessionStore() -> SessionStore {
		SessionStore(snapshotStore: InMemorySessionSnapshotStore(), credentialStore: InMemoryCredentialStore())
	}

	private static func fillValidFields(on model: SignUpModel) {
		model.updateFirstName("Tim")
		model.updateLastName("Harrison")
		model.updateGender(.male)
		model.updateEmail("tim@example.com")
		model.updateScreenName("TurboTim")
		model.updatePassword("hunter2")
	}

	struct `Starting up` {
		@Test func `cannot submit with every field empty`() {
			let model = SignUpModel(
				authService: InMemoryAuthenticationService(),
				sessionStore: SignUpModelTests.makeSessionStore(),
			)

			#expect(model.canSubmit == false)
		}

		@Test func `defaults to unisex`() {
			let model = SignUpModel(
				authService: InMemoryAuthenticationService(),
				sessionStore: SignUpModelTests.makeSessionStore(),
			)

			#expect(model.gender == .unisex)
		}
	}

	struct `Field validation` {
		@Test func `can submit once every field is valid`() {
			let model = SignUpModel(
				authService: InMemoryAuthenticationService(),
				sessionStore: SignUpModelTests.makeSessionStore(),
			)

			SignUpModelTests.fillValidFields(on: model)

			#expect(model.canSubmit == true)
			#expect(model.firstNameError == nil)
			#expect(model.lastNameError == nil)
			#expect(model.emailError == nil)
			#expect(model.screenNameError == nil)
			#expect(model.passwordError == nil)
		}

		@Test func `flags an invalid email`() {
			let model = SignUpModel(
				authService: InMemoryAuthenticationService(),
				sessionStore: SignUpModelTests.makeSessionStore(),
			)

			SignUpModelTests.fillValidFields(on: model)
			model.updateEmail("not-an-email")

			#expect(model.emailError == .invalidCharacters)
			#expect(model.canSubmit == false)
		}

		@Test func `flags a screen name that's too short`() {
			let model = SignUpModel(
				authService: InMemoryAuthenticationService(),
				sessionStore: SignUpModelTests.makeSessionStore(),
			)

			SignUpModelTests.fillValidFields(on: model)
			model.updateScreenName("Fred")

			#expect(model.screenNameError == .invalidCharacters)
			#expect(model.canSubmit == false)
		}

		@Test func `flags a password that's too short`() {
			let model = SignUpModel(
				authService: InMemoryAuthenticationService(),
				sessionStore: SignUpModelTests.makeSessionStore(),
			)

			SignUpModelTests.fillValidFields(on: model)
			model.updatePassword("1234")

			#expect(model.passwordError == .tooShort)
			#expect(model.canSubmit == false)
		}
	}

	struct Submitting {
		@Test func `sends every field plus the SHA-1 password hash`() async {
			let authService = InMemoryAuthenticationService(
				createUserResult: .success(AuthenticatedSession(
					personId: "9",
					screenName: "TurboTim",
					rotatedToken: "tok",
				)),
			)
			let model = SignUpModel(authService: authService, sessionStore: SignUpModelTests.makeSessionStore())
			SignUpModelTests.fillValidFields(on: model)

			await model.submit()

			let invocation = try? #require(authService.createUserInvocations.first)
			#expect(invocation?.firstName == "Tim")
			#expect(invocation?.lastName == "Harrison")
			#expect(invocation?.gender == .male)
			#expect(invocation?.email == "tim@example.com")
			#expect(invocation?.screenName == "TurboTim")
			#expect(invocation?.passwordHash == "f3bbbd66a63d4bf1747940578ec3d0103530e21d")
		}

		@Test func `does nothing while any field is invalid`() async {
			let authService = InMemoryAuthenticationService()
			let model = SignUpModel(authService: authService, sessionStore: SignUpModelTests.makeSessionStore())

			await model.submit()

			#expect(authService.createUserInvocations.isEmpty)
		}

		@Test func `marks that submission was attempted even when validation blocks it`() async {
			let model = SignUpModel(
				authService: InMemoryAuthenticationService(),
				sessionStore: SignUpModelTests.makeSessionStore(),
			)

			await model.submit()

			#expect(model.hasAttemptedSubmit == true)
		}

		@Test func `signs the session in on success`() async {
			let sessionStore = SignUpModelTests.makeSessionStore()
			let authService = InMemoryAuthenticationService(
				createUserResult: .success(AuthenticatedSession(
					personId: "9",
					screenName: "TurboTim",
					rotatedToken: "tok",
				)),
			)
			let model = SignUpModel(authService: authService, sessionStore: sessionStore)
			SignUpModelTests.fillValidFields(on: model)

			await model.submit()

			#expect(sessionStore.user == SessionUser(personId: "9", screenName: "TurboTim"))
			#expect(sessionStore.isSignedIn == true)
			#expect(model.errorMessage == nil)
		}

		@Test func `surfaces the server's message on failure`() async {
			let authService = InMemoryAuthenticationService(
				createUserResult: .failure(.server(message: "That screen name is taken.")),
			)
			let model = SignUpModel(authService: authService, sessionStore: SignUpModelTests.makeSessionStore())
			SignUpModelTests.fillValidFields(on: model)

			await model.submit()

			#expect(model.errorMessage == "That screen name is taken.")
		}

		@Test func `surfaces a fallback message on a connection failure`() async {
			let authService = InMemoryAuthenticationService(createUserResult: .failure(.connection))
			let model = SignUpModel(authService: authService, sessionStore: SignUpModelTests.makeSessionStore())
			SignUpModelTests.fillValidFields(on: model)

			await model.submit()

			#expect(model.errorMessage != nil)
		}

		@Test func `sets onboardingRoute to native on success`() async {
			let authService = InMemoryAuthenticationService(
				createUserResult: .success(AuthenticatedSession(
					personId: "9",
					screenName: "TurboTim",
					rotatedToken: "tok",
				)),
			)
			let model = SignUpModel(authService: authService, sessionStore: SignUpModelTests.makeSessionStore())
			SignUpModelTests.fillValidFields(on: model)

			await model.submit()

			#expect(model.onboardingRoute == .native)
		}

		@Test func `leaves onboardingRoute nil on failure`() async {
			let authService = InMemoryAuthenticationService(
				createUserResult: .failure(.server(message: "That screen name is taken.")),
			)
			let model = SignUpModel(authService: authService, sessionStore: SignUpModelTests.makeSessionStore())
			SignUpModelTests.fillValidFields(on: model)

			await model.submit()

			#expect(model.onboardingRoute == nil)
		}
	}

	struct Instrumentation {
		@Test func `submitting leaves an interaction breadcrumb`() async {
			let recorder = RecordingDestination()
			let authService = InMemoryAuthenticationService(
				createUserResult: .success(AuthenticatedSession(
					personId: "9",
					screenName: "TurboTim",
					rotatedToken: "tok",
				)),
			)
			let model = SignUpModel(
				authService: authService,
				sessionStore: SignUpModelTests.makeSessionStore(),
				observability: ObservabilityPipeline(destinations: [recorder]),
			)
			SignUpModelTests.fillValidFields(on: model)

			await model.submit()

			#expect(recorder.breadcrumbs.contains(.interaction(description: "signUp")))
		}

		@Test func `a new account tracks the accountCreated analytics event`() async {
			let recorder = RecordingDestination()
			let authService = InMemoryAuthenticationService(
				createUserResult: .success(AuthenticatedSession(
					personId: "9",
					screenName: "TurboTim",
					rotatedToken: "tok",
				)),
			)
			let model = SignUpModel(
				authService: authService,
				sessionStore: SignUpModelTests.makeSessionStore(),
				observability: ObservabilityPipeline(destinations: [recorder]),
			)
			SignUpModelTests.fillValidFields(on: model)

			await model.submit()

			#expect(recorder.analytics == [AnalyticsPayload(name: "accountCreated", parameters: [:])])
		}

		@Test func `a failed submission is reported without logging any field`() async {
			let recorder = RecordingDestination()
			let authService = InMemoryAuthenticationService(
				createUserResult: .failure(.server(message: "That screen name is taken.")),
			)
			let model = SignUpModel(
				authService: authService,
				sessionStore: SignUpModelTests.makeSessionStore(),
				observability: ObservabilityPipeline(destinations: [recorder]),
			)
			SignUpModelTests.fillValidFields(on: model)

			await model.submit()

			let diagnostics = recorder.events.compactMap { event -> String? in
				guard case .diagnostic(let diagnostic) = event else { return nil }
				return diagnostic.message
			}
			#expect(diagnostics.contains { $0.contains("TurboTim") } == false)
			#expect(diagnostics.contains { $0.contains("tim@example.com") } == false)
			#expect(diagnostics.contains { $0.contains("hunter2") } == false)
		}
	}
}
