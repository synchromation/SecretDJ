import Foundation
import Observability
import SecretDJAPI
import SecretDJDomain
import SharedFeatures
import Testing

@testable import SecretDJ

/// ``ProfileScreenModel`` (S6.6, LEGACY.md "Tab 3 — Profile"): own-vs-other
/// derivation (legacy's `person.personId == userManager.currentUser?.personId`
/// check, `secretdjv3/SupplementaryViewProvider.swift`), the person's own
/// ``OptimisticLikeModel`` — constructed only for someone else's profile,
/// since legacy hides the like button's whole containing view on your own
/// profile (you can't like yourself) — and the avatar-change flow, which
/// reuses Onboarding's upload seam (``OnboardingServicing``) exactly like
/// ``AddProfilePictureForCreditsModel`` does for the same `newavatar` call.
@MainActor
enum ProfileScreenModelTests {
	private static func makeSessionStore(personId: String = "9", screenName: String = "TurboTim") -> SessionStore {
		let store = SessionStore(
			snapshotStore: InMemorySessionSnapshotStore(),
			credentialStore: InMemoryCredentialStore(),
		)
		store.signIn(
			user: SessionUser(personId: personId, screenName: screenName),
			venue: nil,
			credential: APICredential(token: "tok", passwordHash: "hash"),
		)
		return store
	}

	private static func makeModel(
		personId: String,
		sessionStore: SessionStore? = nil,
		likeToggling: any LikeToggling = InMemoryLikeToggling(),
		onboardingService: InMemoryOnboardingService = InMemoryOnboardingService(),
		observability: ObservabilityPipeline = .disabled,
	) -> ProfileScreenModel {
		ProfileScreenModel(
			personId: personId,
			sessionStore: sessionStore ?? makeSessionStore(),
			likeToggling: likeToggling,
			onboardingService: onboardingService,
			observability: observability,
		)
	}

	private static func makePerson(
		personId: String = "41",
		likeInfo: LikeInfo = LikeInfo(likedByYou: false, info: ""),
	) -> Person {
		Person(
			personId: personId,
			screenName: "Someone Else",
			gender: .unisex,
			likeInfo: likeInfo,
			email: nil,
			firstName: nil,
			lastName: nil,
			text: "",
			sortIndex: 0,
			action: nil,
			actions: [],
		)
	}

	struct `Own-vs-other derivation` {
		@Test func `is own profile when personId matches the session's own`() {
			let model = ProfileScreenModelTests.makeModel(
				personId: "9",
				sessionStore: ProfileScreenModelTests.makeSessionStore(personId: "9"),
			)

			#expect(model.isOwnProfile == true)
		}

		@Test func `is not own profile when personId differs from the session's own`() {
			let model = ProfileScreenModelTests.makeModel(
				personId: "41",
				sessionStore: ProfileScreenModelTests.makeSessionStore(personId: "9"),
			)

			#expect(model.isOwnProfile == false)
		}

		@Test func `is not own profile when no one is signed in`() {
			let model = ProfileScreenModelTests.makeModel(personId: "9", sessionStore: SessionStore(
				snapshotStore: InMemorySessionSnapshotStore(),
				credentialStore: InMemoryCredentialStore(),
			))

			#expect(model.isOwnProfile == false)
		}
	}

	struct `Like reconciliation` {
		@Test func `constructs a like model from the first payload on someone else's profile`() {
			let model = ProfileScreenModelTests.makeModel(
				personId: "41",
				sessionStore: ProfileScreenModelTests.makeSessionStore(personId: "9"),
			)
			let person = ProfileScreenModelTests.makePerson(
				personId: "41",
				likeInfo: LikeInfo(likedByYou: true, info: "3 people buzzed this"),
			)

			model.personDetailsChanged(person)

			#expect(model.likeModel?.likeInfo == LikeInfo(likedByYou: true, info: "3 people buzzed this"))
		}

		@Test func `reconciles the same like model instance on a later payload, rather than replacing it`() {
			let model = ProfileScreenModelTests.makeModel(
				personId: "41",
				sessionStore: ProfileScreenModelTests.makeSessionStore(personId: "9"),
			)
			model.personDetailsChanged(ProfileScreenModelTests.makePerson(
				personId: "41",
				likeInfo: LikeInfo(likedByYou: false, info: ""),
			))
			let firstLikeModel = model.likeModel

			model.personDetailsChanged(ProfileScreenModelTests.makePerson(
				personId: "41",
				likeInfo: LikeInfo(likedByYou: true, info: "4 people buzzed this"),
			))

			#expect(model.likeModel === firstLikeModel)
			#expect(model.likeModel?.likeInfo == LikeInfo(likedByYou: true, info: "4 people buzzed this"))
		}

		@Test func `never constructs a like model for your own profile`() {
			let model = ProfileScreenModelTests.makeModel(
				personId: "9",
				sessionStore: ProfileScreenModelTests.makeSessionStore(personId: "9"),
			)

			model.personDetailsChanged(ProfileScreenModelTests.makePerson(personId: "9"))

			#expect(model.likeModel == nil)
		}

		@Test func `does nothing when the payload is nil`() {
			let model = ProfileScreenModelTests.makeModel(
				personId: "41",
				sessionStore: ProfileScreenModelTests.makeSessionStore(personId: "9"),
			)

			model.personDetailsChanged(nil)

			#expect(model.likeModel == nil)
		}
	}

	struct `Avatar-change flow` {
		@Test func `uploadAvatar calls uploadAvatar with the right args and raises an event with the reward message on success`(
		) async {
			let service = InMemoryOnboardingService(
				uploadAvatarResult: .success(AvatarUploadOutcome(
					rewardMessage: "Thanks for the new photo!",
					rotatedToken: nil,
				)),
			)
			let model = ProfileScreenModelTests.makeModel(
				personId: "9",
				sessionStore: ProfileScreenModelTests.makeSessionStore(personId: "9"),
				onboardingService: service,
			)
			let imageData = Data([1, 2, 3])

			await model.uploadAvatar(imageData)

			let invocation = try? #require(service.uploadAvatarInvocations.first)
			#expect(invocation?.userId == "9")
			#expect(invocation?.imageData == imageData)
			#expect(invocation?.credential == APICredential(token: "tok", passwordHash: "hash"))
			#expect(model.avatarUploadEvent?.rewardMessage == "Thanks for the new photo!")
			#expect(model.avatarUploadFailureMessage == nil)
		}

		@Test func `is a no-op on someone else's profile`() async {
			let service = InMemoryOnboardingService(
				uploadAvatarResult: .success(AvatarUploadOutcome(rewardMessage: nil, rotatedToken: nil)),
			)
			let model = ProfileScreenModelTests.makeModel(
				personId: "41",
				sessionStore: ProfileScreenModelTests.makeSessionStore(personId: "9"),
				onboardingService: service,
			)

			await model.uploadAvatar(Data([1]))

			#expect(service.uploadAvatarInvocations.isEmpty)
			#expect(model.avatarUploadEvent == nil)
		}

		@Test func `surfaces the server's message on failure and raises no event`() async {
			let service = InMemoryOnboardingService(
				uploadAvatarResult: .failure(.server(message: "That image is too large.")),
			)
			let model = ProfileScreenModelTests.makeModel(
				personId: "9",
				sessionStore: ProfileScreenModelTests.makeSessionStore(personId: "9"),
				onboardingService: service,
			)

			await model.uploadAvatar(Data([1]))

			#expect(model.avatarUploadFailureMessage == "That image is too large.")
			#expect(model.avatarUploadEvent == nil)
		}

		@Test func `surfaces a fallback message on a thrown connection error`() async {
			let service = InMemoryOnboardingService(uploadAvatarResult: .failure(.connection))
			let model = ProfileScreenModelTests.makeModel(
				personId: "9",
				sessionStore: ProfileScreenModelTests.makeSessionStore(personId: "9"),
				onboardingService: service,
			)

			await model.uploadAvatar(Data([1]))

			#expect(model.avatarUploadFailureMessage != nil)
		}

		@Test func `clears a previous failure message once a new attempt succeeds`() async {
			let service = InMemoryOnboardingService(uploadAvatarResult: .failure(.connection))
			let model = ProfileScreenModelTests.makeModel(
				personId: "9",
				sessionStore: ProfileScreenModelTests.makeSessionStore(personId: "9"),
				onboardingService: service,
			)
			await model.uploadAvatar(Data([1]))
			#expect(model.avatarUploadFailureMessage != nil)

			service.uploadAvatarResult = .success(AvatarUploadOutcome(rewardMessage: nil, rotatedToken: nil))
			await model.uploadAvatar(Data([1]))

			#expect(model.avatarUploadFailureMessage == nil)
		}

		@Test func `rotates the session's token when the outcome carries one`() async {
			let service = InMemoryOnboardingService(
				uploadAvatarResult: .success(AvatarUploadOutcome(rewardMessage: nil, rotatedToken: "new-tok")),
			)
			let sessionStore = ProfileScreenModelTests.makeSessionStore(personId: "9")
			let model = ProfileScreenModelTests.makeModel(
				personId: "9",
				sessionStore: sessionStore,
				onboardingService: service,
			)

			await model.uploadAvatar(Data([1]))

			#expect(sessionStore.credential?.token == "new-tok")
		}
	}

	struct Instrumentation {
		@Test func `uploading an avatar tracks avatarChanged on success`() async {
			let recorder = RecordingDestination()
			let service = InMemoryOnboardingService(
				uploadAvatarResult: .success(AvatarUploadOutcome(rewardMessage: nil, rotatedToken: nil)),
			)
			let model = ProfileScreenModelTests.makeModel(
				personId: "9",
				sessionStore: ProfileScreenModelTests.makeSessionStore(personId: "9"),
				onboardingService: service,
				observability: ObservabilityPipeline(destinations: [recorder]),
			)

			await model.uploadAvatar(Data([1]))

			#expect(recorder.analytics.contains(AnalyticsPayload(name: "avatarChanged", parameters: [:])))
		}

		@Test func `uploading an avatar tracks avatarChangeFailed on failure`() async {
			let recorder = RecordingDestination()
			let service = InMemoryOnboardingService(uploadAvatarResult: .failure(.connection))
			let model = ProfileScreenModelTests.makeModel(
				personId: "9",
				sessionStore: ProfileScreenModelTests.makeSessionStore(personId: "9"),
				onboardingService: service,
				observability: ObservabilityPipeline(destinations: [recorder]),
			)

			await model.uploadAvatar(Data([1]))

			#expect(recorder.analytics.contains(AnalyticsPayload(name: "avatarChangeFailed", parameters: [:])))
		}

		@Test func `uploading an avatar leaves an interaction breadcrumb`() async {
			let recorder = RecordingDestination()
			let service = InMemoryOnboardingService(
				uploadAvatarResult: .success(AvatarUploadOutcome(rewardMessage: nil, rotatedToken: nil)),
			)
			let model = ProfileScreenModelTests.makeModel(
				personId: "9",
				sessionStore: ProfileScreenModelTests.makeSessionStore(personId: "9"),
				onboardingService: service,
				observability: ObservabilityPipeline(destinations: [recorder]),
			)

			await model.uploadAvatar(Data([1]))

			#expect(recorder.breadcrumbs.contains(.interaction(description: "changeAvatar")))
		}
	}
}
