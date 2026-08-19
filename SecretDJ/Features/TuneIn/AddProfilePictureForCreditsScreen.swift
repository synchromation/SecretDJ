import DesignSystem
import Observability
import SecretDJAPI
import SwiftUI

/// The "yes" branch of LEGACY.md business rule 5's out-of-credits funnel —
/// legacy's `secretdjv3/LoginProfilePictureViewController.swift`, reused
/// here via ``AvatarPickerButtons`` rather than duplicated. Presented as a
/// sheet from ``ResolvedTuneInScreen``; on a successful upload the caller
/// dismisses it and shows the server's reward text as a toast, then the
/// user lands back on TuneIn with the request button available again — "the
/// re-offer" LEGACY.md's `onSuccess` pop-back achieves via `UIKit`
/// navigation, this rewrite achieves via sheet dismissal instead.
struct AddProfilePictureForCreditsScreen: View {
	let model: AddProfilePictureForCreditsModel
	let onSuccess: (String?) -> Void

	@Environment(\.dismiss) private var dismiss

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(spacing: Spacing.large) {
					Text("Add a profile picture", comment: "Title of the pic-for-credits upsell screen.")
						.font(Theme.TextStyle.screenTitle.font)
						.foregroundStyle(Theme.ColorRole.primaryText.color)

					Text(
						"Add a profile picture now and we'll top up your credits as a thank you.",
						comment: "Body of the pic-for-credits upsell screen.",
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
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button(action: dismissScreen) {
						Text(
							"Cancel",
							comment: "Button that dismisses the pic-for-credits upsell screen without uploading anything.",
						)
					}
				}
			}
			.tracksScreen("TuneInAddProfilePictureForCredits")
		}
		.onChange(of: model.didSucceed) { _, succeeded in
			guard succeeded else { return }
			onSuccess(model.rewardMessage)
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

	private func dismissScreen() {
		dismiss()
	}
}

#Preview("Fresh") {
	AddProfilePictureForCreditsScreen(
		model: AddProfilePictureForCreditsModel(
			personId: "9",
			credential: APICredential(token: "tok", passwordHash: "hash"),
			onboardingService: InMemoryOnboardingService(),
			sessionStore: PreviewSessionStore.signedIn(),
		),
		onSuccess: { _ in },
	)
}

#Preview("Error") {
	AddProfilePictureForCreditsScreen(
		model: AddProfilePictureForCreditsModel(
			personId: "9",
			credential: APICredential(token: "tok", passwordHash: "hash"),
			onboardingService: InMemoryOnboardingService(
				uploadAvatarResult: .failure(.server(message: "That image is too large.")),
			),
			sessionStore: PreviewSessionStore.signedIn(),
		),
		onSuccess: { _ in },
	)
}

#Preview("Accessibility text size") {
	AddProfilePictureForCreditsScreen(
		model: AddProfilePictureForCreditsModel(
			personId: "9",
			credential: APICredential(token: "tok", passwordHash: "hash"),
			onboardingService: InMemoryOnboardingService(),
			sessionStore: PreviewSessionStore.signedIn(),
		),
		onSuccess: { _ in },
	)
	.environment(\.dynamicTypeSize, .accessibility5)
}
