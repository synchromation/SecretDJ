import DesignSystem
import Observability
import SecretDJAPI
import SecretDJDomain
import Testing

@testable import SecretDJ

@MainActor
enum ChangeDetailsModelTests {
	private static func makePerson(
		firstName: String? = "Tim",
		lastName: String? = "Harrison",
		screenName: String = "TurboTim",
		email: String? = "tim@example.com",
	) -> Person {
		Person(
			personId: "9",
			screenName: screenName,
			gender: .unisex,
			likeInfo: LikeInfo(likedByYou: false, info: ""),
			email: email,
			firstName: firstName,
			lastName: lastName,
			text: screenName,
			sortIndex: 0,
			action: nil,
			actions: [],
		)
	}

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
		settingsService: InMemorySettingsService = InMemorySettingsService(),
		sessionStore: SessionStore? = nil,
		toastQueue: ToastQueue = ToastQueue(clock: ManualToastClock()),
		observability: ObservabilityPipeline = .disabled,
	) -> (model: ChangeDetailsModel, sessionStore: SessionStore, toastQueue: ToastQueue) {
		let sessionStore = sessionStore ?? makeSessionStore()
		let model = ChangeDetailsModel(
			personId: "9",
			credential: APICredential(token: "tok", passwordHash: "hash"),
			settingsService: settingsService,
			sessionStore: sessionStore,
			toastQueue: toastQueue,
			observability: observability,
		)
		return (model, sessionStore, toastQueue)
	}

	struct `Starting up` {
		@Test func `has empty fields and no in-flight work`() {
			let (model, _, _) = ChangeDetailsModelTests.makeModel()

			#expect(model.firstName.isEmpty)
			#expect(model.lastName.isEmpty)
			#expect(model.screenName.isEmpty)
			#expect(model.email.isEmpty)
			#expect(model.isLoading == false)
			#expect(model.isSaving == false)
			#expect(model.didSucceed == false)
		}
	}

	struct Loading {
		@Test func `fetches details with the right userId and credential`() async {
			let service = InMemorySettingsService(fetchDetailsResult: .success(ChangeDetailsModelTests.makePerson()))
			let (model, _, _) = ChangeDetailsModelTests.makeModel(settingsService: service)

			await model.load()

			let invocation = try? #require(service.fetchDetailsInvocations.first)
			#expect(invocation?.userId == "9")
			#expect(invocation?.credential == APICredential(token: "tok", passwordHash: "hash"))
		}

		@Test func `prefills every field from the fetched person`() async {
			let person = ChangeDetailsModelTests.makePerson(
				firstName: "Tim",
				lastName: "Harrison",
				screenName: "TurboTim",
				email: "tim@example.com",
			)
			let service = InMemorySettingsService(fetchDetailsResult: .success(person))
			let (model, _, _) = ChangeDetailsModelTests.makeModel(settingsService: service)

			await model.load()

			#expect(model.firstName == "Tim")
			#expect(model.lastName == "Harrison")
			#expect(model.screenName == "TurboTim")
			#expect(model.email == "tim@example.com")
		}

		@Test func `prefills empty strings for fields the server sent as nil`() async {
			let person = ChangeDetailsModelTests.makePerson(firstName: nil, lastName: nil, email: nil)
			let service = InMemorySettingsService(fetchDetailsResult: .success(person))
			let (model, _, _) = ChangeDetailsModelTests.makeModel(settingsService: service)

			await model.load()

			#expect(model.firstName.isEmpty)
			#expect(model.lastName.isEmpty)
			#expect(model.email.isEmpty)
		}

		@Test func `toasts a fallback message when the fetch fails`() async {
			let service = InMemorySettingsService(fetchDetailsResult: .failure(.connection))
			let toastQueue = ToastQueue(clock: ManualToastClock())
			let (model, _, _) = ChangeDetailsModelTests.makeModel(settingsService: service, toastQueue: toastQueue)

			await model.load()

			#expect(toastQueue.current != nil)
		}
	}

	struct Validation {
		@Test func `cannot save with an invalid field`() {
			let (model, _, _) = ChangeDetailsModelTests.makeModel()
			model.updateFirstName("Tim")
			model.updateLastName("Harrison")
			model.updateScreenName("Tim")
			model.updateEmail("not-an-email")

			#expect(model.canSave == false)
		}

		@Test func `can save once every field is valid`() {
			let (model, _, _) = ChangeDetailsModelTests.makeModel()
			model.updateFirstName("Tim")
			model.updateLastName("Harrison")
			model.updateScreenName("TurboTim")
			model.updateEmail("tim@example.com")

			#expect(model.canSave == true)
		}
	}

	struct Saving {
		private static func makeValidModel(
			settingsService: InMemorySettingsService = InMemorySettingsService(),
			sessionStore: SessionStore? = nil,
			toastQueue: ToastQueue = ToastQueue(clock: ManualToastClock()),
			observability: ObservabilityPipeline = .disabled,
		) -> (model: ChangeDetailsModel, sessionStore: SessionStore, toastQueue: ToastQueue) {
			let made = ChangeDetailsModelTests.makeModel(
				settingsService: settingsService,
				sessionStore: sessionStore,
				toastQueue: toastQueue,
				observability: observability,
			)
			made.model.updateFirstName("Tim")
			made.model.updateLastName("Harrison")
			made.model.updateScreenName("TurboTim")
			made.model.updateEmail("tim@example.com")
			return made
		}

		@Test func `does not call the service while a field is invalid`() async {
			let service = InMemorySettingsService()
			let (model, _, _) = ChangeDetailsModelTests.makeModel(settingsService: service)

			await model.save()

			#expect(service.changeDetailsInvocations.isEmpty)
		}

		@Test func `calls changeDetails with the edited fields`() async {
			let service = InMemorySettingsService(
				changeDetailsResult: .success(SettingsUpdateOutcome(succeeded: true, message: nil, rotatedToken: nil)),
			)
			let (model, _, _) = Saving.makeValidModel(settingsService: service)

			await model.save()

			let invocation = try? #require(service.changeDetailsInvocations.first)
			#expect(invocation?.userId == "9")
			#expect(invocation?.firstName == "Tim")
			#expect(invocation?.lastName == "Harrison")
			#expect(invocation?.screenName == "TurboTim")
			#expect(invocation?.email == "tim@example.com")
		}

		@Test func `updates the session's screen name on success`() async {
			let service = InMemorySettingsService(
				changeDetailsResult: .success(SettingsUpdateOutcome(succeeded: true, message: nil, rotatedToken: nil)),
			)
			let (model, sessionStore, _) = Saving.makeValidModel(settingsService: service)

			await model.save()

			#expect(sessionStore.user?.screenName == "TurboTim")
		}

		@Test func `marks success and dismisses on success`() async {
			let service = InMemorySettingsService(
				changeDetailsResult: .success(SettingsUpdateOutcome(succeeded: true, message: nil, rotatedToken: nil)),
			)
			let (model, _, _) = Saving.makeValidModel(settingsService: service)

			await model.save()

			#expect(model.didSucceed == true)
		}

		@Test func `rotates the session token when the response carries one`() async {
			let service = InMemorySettingsService(
				changeDetailsResult: .success(SettingsUpdateOutcome(
					succeeded: true,
					message: nil,
					rotatedToken: "new-token",
				)),
			)
			let (model, sessionStore, _) = Saving.makeValidModel(settingsService: service)

			await model.save()

			#expect(sessionStore.credential?.token == "new-token")
		}

		@Test func `does not mark success or update the session on a server failure`() async {
			let service = InMemorySettingsService(
				changeDetailsResult: .success(SettingsUpdateOutcome(
					succeeded: false,
					message: "That screen name is taken.",
					rotatedToken: nil,
				)),
			)
			let (model, sessionStore, _) = Saving.makeValidModel(settingsService: service)

			await model.save()

			#expect(model.didSucceed == false)
			#expect(sessionStore.user?.screenName == "TurboTim")
		}

		@Test func `toasts the server's failure message`() async {
			let service = InMemorySettingsService(
				changeDetailsResult: .success(SettingsUpdateOutcome(
					succeeded: false,
					message: "That screen name is taken.",
					rotatedToken: nil,
				)),
			)
			let toastQueue = ToastQueue(clock: ManualToastClock())
			let (model, _, _) = Saving.makeValidModel(settingsService: service, toastQueue: toastQueue)

			await model.save()

			#expect(toastQueue.current?.message == "That screen name is taken.")
		}

		@Test func `toasts a fallback message on a thrown connection error`() async {
			let service = InMemorySettingsService(changeDetailsResult: .failure(.connection))
			let toastQueue = ToastQueue(clock: ManualToastClock())
			let (model, _, _) = Saving.makeValidModel(settingsService: service, toastQueue: toastQueue)

			await model.save()

			#expect(toastQueue.current != nil)
			#expect(model.didSucceed == false)
		}
	}

	struct Instrumentation {
		@Test func `tracks detailsChanged on success`() async {
			let recorder = RecordingDestination()
			let service = InMemorySettingsService(
				changeDetailsResult: .success(SettingsUpdateOutcome(succeeded: true, message: nil, rotatedToken: nil)),
			)
			let (model, _, _) = ChangeDetailsModelTests.makeModel(
				settingsService: service,
				observability: ObservabilityPipeline(destinations: [recorder]),
			)
			model.updateFirstName("Tim")
			model.updateLastName("Harrison")
			model.updateScreenName("TurboTim")
			model.updateEmail("tim@example.com")

			await model.save()

			#expect(recorder.analytics.contains(AnalyticsPayload(name: "detailsChanged", parameters: [:])))
		}

		@Test func `tracks detailsChangeFailed on failure`() async {
			let recorder = RecordingDestination()
			let service = InMemorySettingsService(changeDetailsResult: .failure(.connection))
			let (model, _, _) = ChangeDetailsModelTests.makeModel(
				settingsService: service,
				observability: ObservabilityPipeline(destinations: [recorder]),
			)
			model.updateFirstName("Tim")
			model.updateLastName("Harrison")
			model.updateScreenName("TurboTim")
			model.updateEmail("tim@example.com")

			await model.save()

			#expect(recorder.analytics.contains(AnalyticsPayload(name: "detailsChangeFailed", parameters: [:])))
		}

		@Test func `saving leaves an interaction breadcrumb`() async {
			let recorder = RecordingDestination()
			let service = InMemorySettingsService(
				changeDetailsResult: .success(SettingsUpdateOutcome(succeeded: true, message: nil, rotatedToken: nil)),
			)
			let (model, _, _) = ChangeDetailsModelTests.makeModel(
				settingsService: service,
				observability: ObservabilityPipeline(destinations: [recorder]),
			)
			model.updateFirstName("Tim")
			model.updateLastName("Harrison")
			model.updateScreenName("TurboTim")
			model.updateEmail("tim@example.com")

			await model.save()

			#expect(recorder.breadcrumbs.contains(.interaction(description: "changeDetails")))
		}
	}
}
