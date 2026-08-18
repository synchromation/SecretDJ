import Foundation
import Observability
import SecretDJAPI
import SecretDJDomain
import Testing

@testable import SecretDJ

@MainActor
enum OnboardingModelTests {
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
		route: OnboardingRoute,
		onboardingService: InMemoryOnboardingService = InMemoryOnboardingService(),
		sessionStore: SessionStore? = nil,
		observability: ObservabilityPipeline = .disabled,
	) -> OnboardingModel {
		let sessionStore = sessionStore ?? makeSessionStore()
		return OnboardingModel(
			route: route,
			personId: "9",
			credential: APICredential(token: "tok", passwordHash: "hash"),
			onboardingService: onboardingService,
			sessionStore: sessionStore,
			observability: observability,
		)
	}

	struct `Starting up` {
		@Test func `native route starts at photo`() {
			let model = OnboardingModelTests.makeModel(route: .native)

			#expect(model.currentStep == .photo)
		}

		@Test func `apple route starts at gender selection`() {
			let model = OnboardingModelTests.makeModel(route: .apple)

			#expect(model.currentStep == .genderSelection)
		}

		@Test func `facebook route starts at photo`() {
			let model = OnboardingModelTests.makeModel(route: .facebook)

			#expect(model.currentStep == .photo)
		}

		@Test func `isComplete is false at start for every route`() {
			#expect(OnboardingModelTests.makeModel(route: .native).isComplete == false)
			#expect(OnboardingModelTests.makeModel(route: .apple).isComplete == false)
			#expect(OnboardingModelTests.makeModel(route: .facebook).isComplete == false)
		}

		@Test func `defaults to unisex gender`() {
			let model = OnboardingModelTests.makeModel(route: .apple)

			#expect(model.gender == .unisex)
		}
	}

	struct `Selecting a gender` {
		@Test func `submitGender calls setGender with the right userId, gender, and credential and advances on success`(
		) async {
			let service = InMemoryOnboardingService(
				setGenderResult: .success(OnboardingUpdateOutcome(succeeded: true, message: nil, rotatedToken: nil)),
			)
			let model = OnboardingModelTests.makeModel(route: .apple, onboardingService: service)
			model.updateGender(.female)

			await model.submitGender()

			let invocation = try? #require(service.setGenderInvocations.first)
			#expect(invocation?.userId == "9")
			#expect(invocation?.gender == .female)
			#expect(invocation?.credential == APICredential(token: "tok", passwordHash: "hash"))
			#expect(model.currentStep == .photo)
		}

		@Test func `submitGender does nothing when currentStep is not genderSelection`() async {
			let service = InMemoryOnboardingService(
				setGenderResult: .success(OnboardingUpdateOutcome(succeeded: true, message: nil, rotatedToken: nil)),
			)
			let model = OnboardingModelTests.makeModel(route: .native, onboardingService: service)

			await model.submitGender()

			#expect(service.setGenderInvocations.isEmpty)
			#expect(model.currentStep == .photo)
		}

		@Test func `surfaces the server's message on a failed outcome and does not advance`() async {
			let service = InMemoryOnboardingService(
				setGenderResult: .success(OnboardingUpdateOutcome(
					succeeded: false,
					message: "Please try again.",
					rotatedToken: nil,
				)),
			)
			let model = OnboardingModelTests.makeModel(route: .apple, onboardingService: service)

			await model.submitGender()

			#expect(model.errorMessage == "Please try again.")
			#expect(model.currentStep == .genderSelection)
		}

		@Test func `surfaces a fallback message and does not advance on a thrown connection error`() async {
			let service = InMemoryOnboardingService(setGenderResult: .failure(.connection))
			let model = OnboardingModelTests.makeModel(route: .apple, onboardingService: service)

			await model.submitGender()

			#expect(model.errorMessage != nil)
			#expect(model.currentStep == .genderSelection)
		}

		@Test func `rotates the session's token when the outcome carries one`() async {
			let service = InMemoryOnboardingService(
				setGenderResult: .success(OnboardingUpdateOutcome(
					succeeded: true,
					message: nil,
					rotatedToken: "new-tok",
				)),
			)
			let sessionStore = OnboardingModelTests.makeSessionStore()
			let model = OnboardingModelTests.makeModel(
				route: .apple,
				onboardingService: service,
				sessionStore: sessionStore,
			)

			await model.submitGender()

			#expect(sessionStore.credential?.token == "new-tok")
		}

		@Test func `rotates the session's token even when the outcome fails`() async {
			let service = InMemoryOnboardingService(
				setGenderResult: .success(OnboardingUpdateOutcome(
					succeeded: false,
					message: "Please try again.",
					rotatedToken: "new-tok",
				)),
			)
			let sessionStore = OnboardingModelTests.makeSessionStore()
			let model = OnboardingModelTests.makeModel(
				route: .apple,
				onboardingService: service,
				sessionStore: sessionStore,
			)

			await model.submitGender()

			#expect(sessionStore.credential?.token == "new-tok")
			#expect(model.currentStep == .genderSelection)
		}
	}

	struct `Uploading a photo` {
		@Test func `uploadPhoto calls uploadAvatar with the right args and completes when photo was the only remaining step`(
		) async {
			let service = InMemoryOnboardingService(
				uploadAvatarResult: .success(AvatarUploadOutcome(rewardMessage: nil, rotatedToken: nil)),
			)
			let model = OnboardingModelTests.makeModel(route: .native, onboardingService: service)
			let imageData = Data([1, 2, 3])

			await model.uploadPhoto(imageData)

			let invocation = try? #require(service.uploadAvatarInvocations.first)
			#expect(invocation?.userId == "9")
			#expect(invocation?.imageData == imageData)
			#expect(invocation?.credential == APICredential(token: "tok", passwordHash: "hash"))
			#expect(model.isComplete == true)
		}

		@Test func `on the apple route, uploadPhoto after a successful gender step completes onboarding`() async {
			let service = InMemoryOnboardingService(
				setGenderResult: .success(OnboardingUpdateOutcome(succeeded: true, message: nil, rotatedToken: nil)),
				uploadAvatarResult: .success(AvatarUploadOutcome(rewardMessage: nil, rotatedToken: nil)),
			)
			let model = OnboardingModelTests.makeModel(route: .apple, onboardingService: service)
			await model.submitGender()

			await model.uploadPhoto(Data([1]))

			#expect(model.isComplete == true)
		}

		@Test func `sets rewardMessage when the outcome carries one`() async {
			let service = InMemoryOnboardingService(
				uploadAvatarResult: .success(AvatarUploadOutcome(
					rewardMessage: "Thanks for the photo!",
					rotatedToken: nil,
				)),
			)
			let model = OnboardingModelTests.makeModel(route: .native, onboardingService: service)

			await model.uploadPhoto(Data([1]))

			#expect(model.rewardMessage == "Thanks for the photo!")
		}

		@Test func `leaves rewardMessage nil when the outcome doesn't carry one`() async {
			let service = InMemoryOnboardingService(
				uploadAvatarResult: .success(AvatarUploadOutcome(rewardMessage: nil, rotatedToken: nil)),
			)
			let model = OnboardingModelTests.makeModel(route: .native, onboardingService: service)

			await model.uploadPhoto(Data([1]))

			#expect(model.rewardMessage == nil)
		}

		@Test func `surfaces the server's message and does not advance on failure`() async {
			let service = InMemoryOnboardingService(
				uploadAvatarResult: .failure(.server(message: "That image is too large.")),
			)
			let model = OnboardingModelTests.makeModel(route: .native, onboardingService: service)

			await model.uploadPhoto(Data([1]))

			#expect(model.errorMessage == "That image is too large.")
			#expect(model.isComplete == false)
		}

		@Test func `surfaces a fallback message and does not advance on a thrown connection error`() async {
			let service = InMemoryOnboardingService(uploadAvatarResult: .failure(.connection))
			let model = OnboardingModelTests.makeModel(route: .native, onboardingService: service)

			await model.uploadPhoto(Data([1]))

			#expect(model.errorMessage != nil)
			#expect(model.isComplete == false)
		}
	}

	struct Instrumentation {
		@Test func `uploading a photo tracks avatarUploaded on success`() async {
			let recorder = RecordingDestination()
			let service = InMemoryOnboardingService(
				uploadAvatarResult: .success(AvatarUploadOutcome(rewardMessage: nil, rotatedToken: nil)),
			)
			let model = OnboardingModelTests.makeModel(
				route: .native,
				onboardingService: service,
				observability: ObservabilityPipeline(destinations: [recorder]),
			)

			await model.uploadPhoto(Data([1]))

			#expect(recorder.analytics.contains(AnalyticsPayload(name: "avatarUploaded", parameters: [:])))
		}

		@Test func `uploading a photo tracks avatarUploadFailed on failure`() async {
			let recorder = RecordingDestination()
			let service = InMemoryOnboardingService(uploadAvatarResult: .failure(.connection))
			let model = OnboardingModelTests.makeModel(
				route: .native,
				onboardingService: service,
				observability: ObservabilityPipeline(destinations: [recorder]),
			)

			await model.uploadPhoto(Data([1]))

			#expect(recorder.analytics.contains(AnalyticsPayload(name: "avatarUploadFailed", parameters: [:])))
		}

		@Test func `selecting a gender leaves an interaction breadcrumb`() async {
			let recorder = RecordingDestination()
			let service = InMemoryOnboardingService(
				setGenderResult: .success(OnboardingUpdateOutcome(succeeded: true, message: nil, rotatedToken: nil)),
			)
			let model = OnboardingModelTests.makeModel(
				route: .apple,
				onboardingService: service,
				observability: ObservabilityPipeline(destinations: [recorder]),
			)

			await model.submitGender()

			#expect(recorder.breadcrumbs.contains(.interaction(description: "selectGender")))
		}

		@Test func `uploading a photo leaves an interaction breadcrumb`() async {
			let recorder = RecordingDestination()
			let service = InMemoryOnboardingService(
				uploadAvatarResult: .success(AvatarUploadOutcome(rewardMessage: nil, rotatedToken: nil)),
			)
			let model = OnboardingModelTests.makeModel(
				route: .native,
				onboardingService: service,
				observability: ObservabilityPipeline(destinations: [recorder]),
			)

			await model.uploadPhoto(Data([1]))

			#expect(recorder.breadcrumbs.contains(.interaction(description: "uploadAvatar")))
		}
	}
}
