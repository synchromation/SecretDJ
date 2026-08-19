import DesignSystem
import Observability
import SecretDJAPI
import SecretDJDomain
import Testing

@testable import SecretDJ

@MainActor
enum ChangeGenderModelTests {
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
		onboardingService: InMemoryOnboardingService = InMemoryOnboardingService(),
		sessionStore: SessionStore? = nil,
		toastQueue: ToastQueue = ToastQueue(clock: ManualToastClock()),
		observability: ObservabilityPipeline = .disabled,
	) -> (model: ChangeGenderModel, sessionStore: SessionStore, toastQueue: ToastQueue) {
		let sessionStore = sessionStore ?? makeSessionStore()
		let model = ChangeGenderModel(
			personId: "9",
			credential: APICredential(token: "tok", passwordHash: "hash"),
			onboardingService: onboardingService,
			sessionStore: sessionStore,
			toastQueue: toastQueue,
			observability: observability,
		)
		return (model, sessionStore, toastQueue)
	}

	struct `Starting up` {
		@Test func `has no selection and no in-flight work`() {
			let (model, _, _) = ChangeGenderModelTests.makeModel()

			#expect(model.selectedGender == nil)
			#expect(model.isSaving == false)
			#expect(model.didSucceed == false)
		}
	}

	struct `Selecting a gender` {
		@Test func `calls setGender with the tapped gender`() async {
			let service = InMemoryOnboardingService(
				setGenderResult: .success(OnboardingUpdateOutcome(succeeded: true, message: nil, rotatedToken: nil)),
			)
			let (model, _, _) = ChangeGenderModelTests.makeModel(onboardingService: service)

			await model.selectGender(.female)

			let invocation = try? #require(service.setGenderInvocations.first)
			#expect(invocation?.userId == "9")
			#expect(invocation?.gender == .female)
			#expect(invocation?.credential == APICredential(token: "tok", passwordHash: "hash"))
		}

		@Test func `tracks the tapped gender as the selection`() async {
			let service = InMemoryOnboardingService(
				setGenderResult: .success(OnboardingUpdateOutcome(succeeded: true, message: nil, rotatedToken: nil)),
			)
			let (model, _, _) = ChangeGenderModelTests.makeModel(onboardingService: service)

			await model.selectGender(.male)

			#expect(model.selectedGender == .male)
		}

		@Test func `marks success and toasts a confirmation on success`() async {
			let service = InMemoryOnboardingService(
				setGenderResult: .success(OnboardingUpdateOutcome(succeeded: true, message: nil, rotatedToken: nil)),
			)
			let toastQueue = ToastQueue(clock: ManualToastClock())
			let (model, _, _) = ChangeGenderModelTests.makeModel(onboardingService: service, toastQueue: toastQueue)

			await model.selectGender(.female)

			#expect(model.didSucceed == true)
			#expect(toastQueue.current != nil)
		}

		@Test func `rotates the session token when the response carries one`() async {
			let service = InMemoryOnboardingService(
				setGenderResult: .success(OnboardingUpdateOutcome(
					succeeded: true,
					message: nil,
					rotatedToken: "new-token",
				)),
			)
			let (model, sessionStore, _) = ChangeGenderModelTests.makeModel(onboardingService: service)

			await model.selectGender(.female)

			#expect(sessionStore.credential?.token == "new-token")
		}

		@Test func `does not mark success on a server failure and toasts the server's message`() async {
			let service = InMemoryOnboardingService(
				setGenderResult: .success(OnboardingUpdateOutcome(
					succeeded: false,
					message: "Sorry, something went wrong.",
					rotatedToken: nil,
				)),
			)
			let toastQueue = ToastQueue(clock: ManualToastClock())
			let (model, _, _) = ChangeGenderModelTests.makeModel(onboardingService: service, toastQueue: toastQueue)

			await model.selectGender(.female)

			#expect(model.didSucceed == false)
			#expect(toastQueue.current?.message == "Sorry, something went wrong.")
		}

		@Test func `toasts a fallback message on a thrown connection error`() async {
			let service = InMemoryOnboardingService(setGenderResult: .failure(.connection))
			let toastQueue = ToastQueue(clock: ManualToastClock())
			let (model, _, _) = ChangeGenderModelTests.makeModel(onboardingService: service, toastQueue: toastQueue)

			await model.selectGender(.female)

			#expect(toastQueue.current != nil)
			#expect(model.didSucceed == false)
		}
	}

	struct Instrumentation {
		@Test func `tracks genderChanged on success`() async {
			let recorder = RecordingDestination()
			let service = InMemoryOnboardingService(
				setGenderResult: .success(OnboardingUpdateOutcome(succeeded: true, message: nil, rotatedToken: nil)),
			)
			let (model, _, _) = ChangeGenderModelTests.makeModel(
				onboardingService: service,
				observability: ObservabilityPipeline(destinations: [recorder]),
			)

			await model.selectGender(.female)

			#expect(recorder.analytics.contains(AnalyticsPayload(name: "genderChanged", parameters: [:])))
		}

		@Test func `tracks genderChangeFailed on failure`() async {
			let recorder = RecordingDestination()
			let service = InMemoryOnboardingService(setGenderResult: .failure(.connection))
			let (model, _, _) = ChangeGenderModelTests.makeModel(
				onboardingService: service,
				observability: ObservabilityPipeline(destinations: [recorder]),
			)

			await model.selectGender(.female)

			#expect(recorder.analytics.contains(AnalyticsPayload(name: "genderChangeFailed", parameters: [:])))
		}

		@Test func `selecting leaves an interaction breadcrumb`() async {
			let recorder = RecordingDestination()
			let service = InMemoryOnboardingService(
				setGenderResult: .success(OnboardingUpdateOutcome(succeeded: true, message: nil, rotatedToken: nil)),
			)
			let (model, _, _) = ChangeGenderModelTests.makeModel(
				onboardingService: service,
				observability: ObservabilityPipeline(destinations: [recorder]),
			)

			await model.selectGender(.female)

			#expect(recorder.breadcrumbs.contains(.interaction(description: "changeGender")))
		}
	}
}
