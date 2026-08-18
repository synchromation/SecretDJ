import Observability
import SecretDJAPI
import Testing

@testable import SecretDJ

@MainActor
enum AppleUsernameModelTests {
	private static func makeSessionStore() -> SessionStore {
		let store = SessionStore(
			snapshotStore: InMemorySessionSnapshotStore(),
			credentialStore: InMemoryCredentialStore(),
		)
		store.signIn(
			user: SessionUser(personId: "9", screenName: "TurboTim"),
			venue: nil,
			credential: APICredential(token: "tok", passwordHash: "hash"),
		)
		return store
	}

	private static func makeModel(
		usernameService: InMemoryAppleUsernameService = InMemoryAppleUsernameService(),
		sessionStore: SessionStore? = nil,
		observability: ObservabilityPipeline = .disabled,
	) -> AppleUsernameModel {
		AppleUsernameModel(
			personId: "9",
			credential: APICredential(token: "tok", passwordHash: "hash"),
			usernameService: usernameService,
			sessionStore: sessionStore ?? makeSessionStore(),
			observability: observability,
		)
	}

	struct `Starting up` {
		@Test func `starts with an empty screen name, unable to submit, and no error`() {
			let model = AppleUsernameModelTests.makeModel()

			#expect(model.screenName.isEmpty)
			#expect(model.canSubmit == false)
			#expect(model.isComplete == false)
			#expect(model.errorMessage == nil)
		}
	}

	struct `Validating the screen name` {
		@Test func `canSubmit becomes true once a valid screen name is set`() {
			let model = AppleUsernameModelTests.makeModel()

			model.updateScreenName("TurboTim")

			#expect(model.canSubmit == true)
		}

		@Test func `canSubmit stays false for a screen name that's too short`() {
			let model = AppleUsernameModelTests.makeModel()

			model.updateScreenName("Tim")

			#expect(model.canSubmit == false)
		}

		@Test func `canSubmit stays false for an empty screen name`() {
			let model = AppleUsernameModelTests.makeModel()

			#expect(model.canSubmit == false)
		}
	}

	struct Submitting {
		@Test func `does nothing when the screen name is invalid, but records the submit attempt`() async {
			let service = InMemoryAppleUsernameService()
			let model = AppleUsernameModelTests.makeModel(usernameService: service)

			await model.submit()

			#expect(service.setScreenNameInvocations.isEmpty)
			#expect(model.hasAttemptedSubmit == true)
		}

		@Test func `calls setScreenName with the right userId, screenName, and credential, and completes on success`(
		) async {
			let service = InMemoryAppleUsernameService(
				setScreenNameResult: .success(ScreenNameUpdateOutcome(
					succeeded: true,
					message: nil,
					rotatedToken: nil,
				)),
			)
			let model = AppleUsernameModelTests.makeModel(usernameService: service)
			model.updateScreenName("TurboTim")

			await model.submit()

			let invocation = try? #require(service.setScreenNameInvocations.first)
			#expect(invocation?.userId == "9")
			#expect(invocation?.screenName == "TurboTim")
			#expect(invocation?.credential == APICredential(token: "tok", passwordHash: "hash"))
			#expect(model.isComplete == true)
			#expect(model.errorMessage == nil)
		}

		@Test func `surfaces the server's message on a failed outcome and does not complete`() async {
			let service = InMemoryAppleUsernameService(
				setScreenNameResult: .success(ScreenNameUpdateOutcome(
					succeeded: false,
					message: "That screen name is taken.",
					rotatedToken: nil,
				)),
			)
			let model = AppleUsernameModelTests.makeModel(usernameService: service)
			model.updateScreenName("TurboTim")

			await model.submit()

			#expect(model.errorMessage == "That screen name is taken.")
			#expect(model.isComplete == false)
		}

		@Test func `surfaces the server's message on a thrown server error`() async {
			let service = InMemoryAppleUsernameService(
				setScreenNameResult: .failure(.server(message: "That screen name is taken.")),
			)
			let model = AppleUsernameModelTests.makeModel(usernameService: service)
			model.updateScreenName("TurboTim")

			await model.submit()

			#expect(model.errorMessage == "That screen name is taken.")
			#expect(model.isComplete == false)
		}

		@Test func `surfaces a fallback message on a thrown connection error`() async {
			let service = InMemoryAppleUsernameService(setScreenNameResult: .failure(.connection))
			let model = AppleUsernameModelTests.makeModel(usernameService: service)
			model.updateScreenName("TurboTim")

			await model.submit()

			#expect(model.errorMessage != nil)
			#expect(model.isComplete == false)
		}

		@Test func `rotates the session's token when the outcome carries one`() async {
			let service = InMemoryAppleUsernameService(
				setScreenNameResult: .success(ScreenNameUpdateOutcome(
					succeeded: true,
					message: nil,
					rotatedToken: "new-tok",
				)),
			)
			let sessionStore = AppleUsernameModelTests.makeSessionStore()
			let model = AppleUsernameModelTests.makeModel(usernameService: service, sessionStore: sessionStore)
			model.updateScreenName("TurboTim")

			await model.submit()

			#expect(sessionStore.credential?.token == "new-tok")
		}
	}

	struct Instrumentation {
		@Test func `a successful submit leaves a setAppleScreenName interaction breadcrumb`() async {
			let recorder = RecordingDestination()
			let service = InMemoryAppleUsernameService(
				setScreenNameResult: .success(ScreenNameUpdateOutcome(
					succeeded: true,
					message: nil,
					rotatedToken: nil,
				)),
			)
			let model = AppleUsernameModelTests.makeModel(
				usernameService: service,
				observability: ObservabilityPipeline(destinations: [recorder]),
			)
			model.updateScreenName("TurboTim")

			await model.submit()

			#expect(recorder.breadcrumbs.contains(.interaction(description: "setAppleScreenName")))
		}

		@Test func `a failed submit is reported, without leaking the screen name into diagnostic messages`() async {
			let recorder = RecordingDestination()
			let service = InMemoryAppleUsernameService(
				setScreenNameResult: .failure(.server(message: "That screen name is taken.")),
			)
			let model = AppleUsernameModelTests.makeModel(
				usernameService: service,
				observability: ObservabilityPipeline(destinations: [recorder]),
			)
			model.updateScreenName("SensitiveScreenName")

			await model.submit()

			let diagnostics = recorder.events.compactMap { event -> String? in
				guard case .diagnostic(let diagnostic) = event else { return nil }
				return diagnostic.message
			}
			#expect(diagnostics.contains { $0.contains("SensitiveScreenName") } == false)
		}
	}
}
