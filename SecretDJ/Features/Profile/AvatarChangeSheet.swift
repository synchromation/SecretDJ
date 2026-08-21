import DesignSystem
import Observability
import SwiftUI

/// The own-profile avatar-change sheet — reuses ``AvatarPickerButtons``
/// exactly like Onboarding's photo step (``PhotoStepView``) and the
/// pic-for-credits upsell (``AddProfilePictureForCreditsScreen``), the
/// third call site for the same picker/camera pair. Presented from
/// ``ProfileScreen`` when the signed-in user taps their own avatar; the
/// caller owns the upload itself (``ProfileScreenModel/uploadAvatar(_:)``)
/// and dismisses this sheet once it succeeds — a failure stays inline here
/// instead (mirrors ``AddProfilePictureForCreditsScreen``'s own error
/// text), so the user can retry without losing their place.
struct AvatarChangeSheet: View {
	let isSubmitting: Bool
	let errorMessage: String?
	let onImageData: (Data) -> Void

	@Environment(\.dismiss) private var dismiss

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(spacing: Spacing.large) {
					AvatarPickerButtons(isSubmitting: isSubmitting, onImageData: onImageData)

					if isSubmitting {
						ProgressView()
					}

					if let errorMessage {
						errorText(errorMessage)
					}
				}
				.padding(Spacing.large)
			}
			.themedScreen()
			.navigationTitle(Text(
				"Change Photo",
				comment: "Navigation title of the sheet for changing your own profile picture.",
			))
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") { dismiss() }
				}
			}
			.tracksScreen("ProfileChangeAvatar")
		}
	}

	private func errorText(_ message: String) -> some View {
		Text(message)
			.font(Theme.TextStyle.body.font)
			.foregroundStyle(Theme.ColorRole.danger.color)
			.multilineTextAlignment(.center)
			.accessibilityAddTraits(.updatesFrequently)
	}
}

// MARK: - Previews

#Preview("Fresh") {
	AvatarChangeSheet(isSubmitting: false, errorMessage: nil, onImageData: { _ in })
}

#Preview("Submitting") {
	AvatarChangeSheet(isSubmitting: true, errorMessage: nil, onImageData: { _ in })
}

#Preview("Error") {
	AvatarChangeSheet(isSubmitting: false, errorMessage: "That image is too large.", onImageData: { _ in })
}

#Preview("Accessibility text size") {
	AvatarChangeSheet(isSubmitting: false, errorMessage: nil, onImageData: { _ in })
		.environment(\.dynamicTypeSize, .accessibility5)
}
