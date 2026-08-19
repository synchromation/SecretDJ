import DesignSystem
import Observability
import SecretDJAPI
import SwiftUI

/// Every route's final, mandatory onboarding step: a profile photo, picked
/// from the library or captured with the camera (LEGACY.md "Login, sign-up,
/// onboarding" — `secretdjv3/LoginProfilePictureViewController.swift`,
/// always constructed with `photoIsOptional: false`, so — unlike legacy's
/// interactive pinch/pan crop — this step never offers a skip; uploading
/// starts automatically once a photo is chosen). The picker/camera pair
/// itself is ``AvatarPickerButtons`` (shared with S6.3b's pic-for-credits
/// upsell, `secretdjv3/ProfilePicForCreditsViewController.swift`'s "yes"
/// branch) — this view only supplies the step's own framing copy and hands
/// its processed image straight to ``OnboardingModel/uploadPhoto(_:)``.
struct PhotoStepView: View {
	let model: OnboardingModel

	@State private var toastQueue = DesignSystem.ToastQueue()

	var body: some View {
		ScrollView {
			VStack(spacing: Spacing.large) {
				Text("Add a profile picture", comment: "Title of the mandatory onboarding photo step.")
					.font(Theme.TextStyle.screenTitle.font)
					.foregroundStyle(Theme.ColorRole.primaryText.color)

				Text(
					"Everyone signing up needs one — it's how people recognize you.",
					comment: "Body of the mandatory onboarding photo step.",
				)
				.font(Theme.TextStyle.body.font)
				.foregroundStyle(Theme.ColorRole.secondaryText.color)
				.multilineTextAlignment(.center)

				AvatarPickerButtons(isSubmitting: model.isSubmitting, onImageData: uploadPhoto)

				if model.isSubmitting {
					ProgressView()
				}

				if let errorMessage = model.errorMessage {
					errorText(errorMessage)
				}
			}
			.padding(Spacing.large)
		}
		.background(Theme.ColorRole.background.color)
		.tracksScreen("OnboardingPhoto")
		.toastPresenter(queue: toastQueue)
		.onChange(of: model.rewardMessage) { _, newValue in
			if let newValue {
				toastQueue.enqueue(ToastItem(message: newValue))
			}
		}
	}

	private func errorText(_ message: String) -> some View {
		Text(message)
			.font(Theme.TextStyle.body.font)
			.foregroundStyle(Theme.ColorRole.danger.color)
			.multilineTextAlignment(.center)
			.accessibilityAddTraits(.updatesFrequently)
	}

	private func uploadPhoto(_ data: Data) {
		Task {
			await model.uploadPhoto(data)
		}
	}
}

#Preview("Fresh") {
	PhotoStepView(model: OnboardingModel(
		route: .native,
		personId: "9",
		credential: APICredential(token: "tok", passwordHash: "hash"),
		onboardingService: InMemoryOnboardingService(),
		sessionStore: PreviewSessionStore.signedOut(),
	))
}

#Preview("Uploading") {
	let model = OnboardingModel(
		route: .native,
		personId: "9",
		credential: APICredential(token: "tok", passwordHash: "hash"),
		onboardingService: InMemoryOnboardingService(),
		sessionStore: PreviewSessionStore.signedOut(),
	)
	return PhotoStepView(model: model)
}

#Preview("Error") {
	PhotoStepView(model: OnboardingModel(
		route: .native,
		personId: "9",
		credential: APICredential(token: "tok", passwordHash: "hash"),
		onboardingService: InMemoryOnboardingService(
			uploadAvatarResult: .failure(.server(message: "That image is too large.")),
		),
		sessionStore: PreviewSessionStore.signedOut(),
	))
}

#Preview("Accessibility text size") {
	PhotoStepView(model: OnboardingModel(
		route: .native,
		personId: "9",
		credential: APICredential(token: "tok", passwordHash: "hash"),
		onboardingService: InMemoryOnboardingService(),
		sessionStore: PreviewSessionStore.signedOut(),
	))
	.environment(\.dynamicTypeSize, .accessibility5)
}
