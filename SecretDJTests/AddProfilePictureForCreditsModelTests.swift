import Foundation
import SecretDJAPI
import Testing

@testable import SecretDJ

/// ``AddProfilePictureForCreditsModel`` — the "yes" branch of LEGACY.md
/// business rule 5's out-of-credits funnel, reusing
/// ``OnboardingServicing/uploadAvatar(userId:imageData:credential:)`` for a
/// single one-shot upload outside the sign-up sequence.
@MainActor
enum AddProfilePictureForCreditsModelTests {
	struct `Starting up` {
		@Test func `starts idle`() {
			let model = makeModel()

			#expect(!model.isSubmitting)
			#expect(model.errorMessage == nil)
			#expect(model.rewardMessage == nil)
			#expect(!model.didSucceed)
		}
	}

	struct `Uploading, on success` {
		@Test func `calls the service with the right userId, imageData, and credential`() async {
			let service = InMemoryOnboardingService(
				uploadAvatarResult: .success(AvatarUploadOutcome(rewardMessage: nil, rotatedToken: nil)),
			)
			let model = makeModel(personId: "9", onboardingService: service)
			let data = Data([0x01, 0x02])

			await model.uploadPhoto(data)

			let invocation = try? #require(service.uploadAvatarInvocations.first)
			#expect(invocation?.userId == "9")
			#expect(invocation?.imageData == data)
			#expect(invocation?.credential == APICredential(token: "tok", passwordHash: "hash"))
		}

		@Test func `surfaces the server's reward message`() async {
			let service = InMemoryOnboardingService(
				uploadAvatarResult: .success(AvatarUploadOutcome(
					rewardMessage: "You earned 5 credits!",
					rotatedToken: nil,
				)),
			)
			let model = makeModel(onboardingService: service)

			await model.uploadPhoto(Data())

			#expect(model.rewardMessage == "You earned 5 credits!")
		}

		@Test func `marks the upload as succeeded`() async {
			let service = InMemoryOnboardingService(
				uploadAvatarResult: .success(AvatarUploadOutcome(rewardMessage: nil, rotatedToken: nil)),
			)
			let model = makeModel(onboardingService: service)

			await model.uploadPhoto(Data())

			#expect(model.didSucceed)
		}

		@Test func `rotates the session's token when the outcome carries one`() async {
			let service = InMemoryOnboardingService(
				uploadAvatarResult: .success(AvatarUploadOutcome(rewardMessage: nil, rotatedToken: "new-tok")),
			)
			let sessionStore = makeSessionStore()
			let model = makeModel(onboardingService: service, sessionStore: sessionStore)

			await model.uploadPhoto(Data())

			#expect(sessionStore.credential == APICredential(token: "new-tok", passwordHash: "hash"))
		}
	}

	struct `Uploading, on failure` {
		@Test func `surfaces the server's error message`() async {
			let service = InMemoryOnboardingService(uploadAvatarResult: .failure(.server(message: "Too large")))
			let model = makeModel(onboardingService: service)

			await model.uploadPhoto(Data())

			#expect(model.errorMessage == "Too large")
			#expect(!model.didSucceed)
		}

		@Test func `surfaces a fallback message on a connection failure`() async {
			let service = InMemoryOnboardingService(uploadAvatarResult: .failure(.connection))
			let model = makeModel(onboardingService: service)

			await model.uploadPhoto(Data())

			#expect(model.errorMessage != nil)
			#expect(!model.didSucceed)
		}
	}
}

// MARK: - Fixtures

@MainActor
private func makeSessionStore() -> SessionStore {
	let store = SessionStore(snapshotStore: InMemorySessionSnapshotStore(), credentialStore: InMemoryCredentialStore())
	store.signIn(
		user: SessionUser(personId: "9", screenName: "TurboTim"),
		venue: nil,
		credential: APICredential(token: "tok", passwordHash: "hash"),
	)
	return store
}

@MainActor
private func makeModel(
	personId: String = "9",
	onboardingService: InMemoryOnboardingService = InMemoryOnboardingService(),
	sessionStore: SessionStore? = nil,
) -> AddProfilePictureForCreditsModel {
	AddProfilePictureForCreditsModel(
		personId: personId,
		credential: APICredential(token: "tok", passwordHash: "hash"),
		onboardingService: onboardingService,
		sessionStore: sessionStore ?? makeSessionStore(),
	)
}
