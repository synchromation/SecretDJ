import DesignSystem
import Observability
import SecretDJAPI
import Testing

@testable import SecretDJ

@MainActor
enum ChangePasswordModelTests {
	private static func makeSessionStore() -> SessionStore {
		let store = SessionStore(
			snapshotStore: InMemorySessionSnapshotStore(),
			credentialStore: InMemoryCredentialStore(),
		)
		store.signIn(
			user: SessionUser(personId: "9", screenName: "TurboTim"),
			venue: nil,
			credential: APICredential(token: "tok", passwordHash: PasswordHashing.sha1Hex("hunter2")),
		)
		return store
	}

	private static func makeModel(
		settingsService: InMemorySettingsService = InMemorySettingsService(),
		sessionStore: SessionStore? = nil,
		toastQueue: ToastQueue = ToastQueue(clock: ManualToastClock()),
		observability: ObservabilityPipeline = .disabled,
	) -> (model: ChangePasswordModel, sessionStore: SessionStore, toastQueue: ToastQueue) {
		let sessionStore = sessionStore ?? makeSessionStore()
		let model = ChangePasswordModel(
			personId: "9",
			credential: APICredential(token: "tok", passwordHash: PasswordHashing.sha1Hex("hunter2")),
			settingsService: settingsService,
			sessionStore: sessionStore,
			toastQueue: toastQueue,
			observability: observability,
		)
		return (model, sessionStore, toastQueue)
	}

	struct `Starting up` {
		@Test func `has empty fields and no in-flight work`() {
			let (model, _, _) = ChangePasswordModelTests.makeModel()

			#expect(model.currentPassword.isEmpty)
			#expect(model.newPassword.isEmpty)
			#expect(model.isSaving == false)
			#expect(model.didSucceed == false)
			#expect(model.currentPasswordIsIncorrect == false)
		}
	}

	struct Validation {
		@Test func `cannot save with an empty current password`() {
			let (model, _, _) = ChangePasswordModelTests.makeModel()
			model.updateNewPassword("newpass")

			#expect(model.canSave == false)
		}

		@Test func `cannot save with a too-short new password`() {
			let (model, _, _) = ChangePasswordModelTests.makeModel()
			model.updateCurrentPassword("hunter2")
			model.updateNewPassword("abc")

			#expect(model.canSave == false)
		}

		@Test func `can save once both fields are valid`() {
			let (model, _, _) = ChangePasswordModelTests.makeModel()
			model.updateCurrentPassword("hunter2")
			model.updateNewPassword("newpass")

			#expect(model.canSave == true)
		}
	}

	struct Saving {
		@Test func `flags an incorrect current password locally without calling the service`() async {
			let service = InMemorySettingsService()
			let (model, _, _) = ChangePasswordModelTests.makeModel(settingsService: service)
			model.updateCurrentPassword("wrong-password")
			model.updateNewPassword("newpass")

			await model.save()

			#expect(model.currentPasswordIsIncorrect == true)
			#expect(service.changePasswordInvocations.isEmpty)
		}

		@Test func `calls changePassword with the new password's hash when the current password matches`() async {
			let service = InMemorySettingsService(
				changePasswordResult: .success(SettingsUpdateOutcome(succeeded: true, message: nil, rotatedToken: nil)),
			)
			let (model, _, _) = ChangePasswordModelTests.makeModel(settingsService: service)
			model.updateCurrentPassword("hunter2")
			model.updateNewPassword("newpass")

			await model.save()

			let invocation = try? #require(service.changePasswordInvocations.first)
			#expect(invocation?.userId == "9")
			#expect(invocation?.newPasswordHash == PasswordHashing.sha1Hex("newpass"))
		}

		@Test func `updates the session's password hash on success`() async {
			let service = InMemorySettingsService(
				changePasswordResult: .success(SettingsUpdateOutcome(succeeded: true, message: nil, rotatedToken: nil)),
			)
			let (model, sessionStore, _) = ChangePasswordModelTests.makeModel(settingsService: service)
			model.updateCurrentPassword("hunter2")
			model.updateNewPassword("newpass")

			await model.save()

			#expect(sessionStore.credential?.passwordHash == PasswordHashing.sha1Hex("newpass"))
		}

		@Test func `marks success on success`() async {
			let service = InMemorySettingsService(
				changePasswordResult: .success(SettingsUpdateOutcome(succeeded: true, message: nil, rotatedToken: nil)),
			)
			let (model, _, _) = ChangePasswordModelTests.makeModel(settingsService: service)
			model.updateCurrentPassword("hunter2")
			model.updateNewPassword("newpass")

			await model.save()

			#expect(model.didSucceed == true)
		}

		@Test func `does not update the session's password hash on a server failure`() async {
			let service = InMemorySettingsService(
				changePasswordResult: .success(SettingsUpdateOutcome(
					succeeded: false,
					message: "Sorry, something went wrong.",
					rotatedToken: nil,
				)),
			)
			let (model, sessionStore, _) = ChangePasswordModelTests.makeModel(settingsService: service)
			model.updateCurrentPassword("hunter2")
			model.updateNewPassword("newpass")

			await model.save()

			#expect(model.didSucceed == false)
			#expect(sessionStore.credential?.passwordHash == PasswordHashing.sha1Hex("hunter2"))
		}

		@Test func `toasts the server's failure message`() async {
			let service = InMemorySettingsService(
				changePasswordResult: .success(SettingsUpdateOutcome(
					succeeded: false,
					message: "Sorry, something went wrong.",
					rotatedToken: nil,
				)),
			)
			let toastQueue = ToastQueue(clock: ManualToastClock())
			let (model, _, _) = ChangePasswordModelTests.makeModel(settingsService: service, toastQueue: toastQueue)
			model.updateCurrentPassword("hunter2")
			model.updateNewPassword("newpass")

			await model.save()

			#expect(toastQueue.current?.message == "Sorry, something went wrong.")
		}

		@Test func `toasts a fallback message on a thrown connection error`() async {
			let service = InMemorySettingsService(changePasswordResult: .failure(.connection))
			let toastQueue = ToastQueue(clock: ManualToastClock())
			let (model, _, _) = ChangePasswordModelTests.makeModel(settingsService: service, toastQueue: toastQueue)
			model.updateCurrentPassword("hunter2")
			model.updateNewPassword("newpass")

			await model.save()

			#expect(toastQueue.current != nil)
			#expect(model.didSucceed == false)
		}
	}

	struct Instrumentation {
		@Test func `tracks passwordChanged on success`() async {
			let recorder = RecordingDestination()
			let service = InMemorySettingsService(
				changePasswordResult: .success(SettingsUpdateOutcome(succeeded: true, message: nil, rotatedToken: nil)),
			)
			let (model, _, _) = ChangePasswordModelTests.makeModel(
				settingsService: service,
				observability: ObservabilityPipeline(destinations: [recorder]),
			)
			model.updateCurrentPassword("hunter2")
			model.updateNewPassword("newpass")

			await model.save()

			#expect(recorder.analytics.contains(AnalyticsPayload(name: "passwordChanged", parameters: [:])))
		}

		@Test func `tracks passwordChangeFailed on failure`() async {
			let recorder = RecordingDestination()
			let service = InMemorySettingsService(changePasswordResult: .failure(.connection))
			let (model, _, _) = ChangePasswordModelTests.makeModel(
				settingsService: service,
				observability: ObservabilityPipeline(destinations: [recorder]),
			)
			model.updateCurrentPassword("hunter2")
			model.updateNewPassword("newpass")

			await model.save()

			#expect(recorder.analytics.contains(AnalyticsPayload(name: "passwordChangeFailed", parameters: [:])))
		}

		@Test func `saving leaves an interaction breadcrumb`() async {
			let recorder = RecordingDestination()
			let service = InMemorySettingsService(
				changePasswordResult: .success(SettingsUpdateOutcome(succeeded: true, message: nil, rotatedToken: nil)),
			)
			let (model, _, _) = ChangePasswordModelTests.makeModel(
				settingsService: service,
				observability: ObservabilityPipeline(destinations: [recorder]),
			)
			model.updateCurrentPassword("hunter2")
			model.updateNewPassword("newpass")

			await model.save()

			#expect(recorder.breadcrumbs.contains(.interaction(description: "changePassword")))
		}
	}
}
