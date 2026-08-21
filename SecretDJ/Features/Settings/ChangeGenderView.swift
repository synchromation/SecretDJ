import DesignSystem
import Observability
import SecretDJAPI
import SecretDJDomain
import SwiftUI

/// Settings' change-gender screen (S6.11) — see ``ChangeGenderModel``'s doc
/// comment for exactly what's ported from the legacy UIKit Settings gender
/// flow. Reuses ``GenderPicker`` (shared with the Onboarding gender step)
/// but, unlike that step, submits the instant an option is tapped rather
/// than waiting for a separate `Continue`.
struct ChangeGenderView: View {
	let model: ChangeGenderModel

	@Environment(\.dismiss) private var dismiss

	var body: some View {
		ScrollView {
			GenderPicker(selected: model.selectedGender, onSelect: select, isDisabled: model.isSaving)
				.padding(Spacing.large)
		}
		.themedScreen()
		.navigationTitle(Text("Gender", comment: "Navigation title of Settings' change-gender screen."))
		.tracksScreen("SettingsChangeGender")
		.onChange(of: model.didSucceed) { _, succeeded in
			if succeeded {
				dismiss()
			}
		}
	}

	private func select(_ gender: Gender) {
		Task {
			await model.selectGender(gender)
		}
	}
}

#Preview("Fresh") {
	NavigationStack {
		ChangeGenderView(model: ChangeGenderModel(
			personId: "9",
			credential: APICredential(token: "tok", passwordHash: "hash"),
			onboardingService: InMemoryOnboardingService(),
			sessionStore: PreviewSessionStore.signedIn(),
			toastQueue: ToastQueue(),
		))
	}
}

#Preview("Accessibility text size") {
	NavigationStack {
		ChangeGenderView(model: ChangeGenderModel(
			personId: "9",
			credential: APICredential(token: "tok", passwordHash: "hash"),
			onboardingService: InMemoryOnboardingService(),
			sessionStore: PreviewSessionStore.signedIn(),
			toastQueue: ToastQueue(),
		))
	}
	.environment(\.dynamicTypeSize, .accessibility5)
}
