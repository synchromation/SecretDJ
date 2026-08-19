import DesignSystem
import Observability
import SecretDJAPI
import SecretDJDomain
import SwiftUI

/// The Apple route's onboarding step: pick a gender, then continue
/// (LEGACY.md "Login, sign-up, onboarding" — `secretdjv3/LoginGenderViewController.swift`).
struct GenderStepView: View {
	let model: OnboardingModel

	var body: some View {
		ScrollView {
			VStack(spacing: Spacing.large) {
				Text("What's your gender?")
					.font(Theme.TextStyle.screenTitle.font)
					.foregroundStyle(Theme.ColorRole.primaryText.color)

				GenderPicker(selected: model.gender, onSelect: model.updateGender)

				continueButton

				if let errorMessage = model.errorMessage {
					errorText(errorMessage)
				}
			}
			.padding(Spacing.large)
		}
		.background(Theme.ColorRole.background.color)
		.tracksScreen("OnboardingGender")
	}

	private var continueButton: some View {
		Button(action: submit) {
			Text("Continue")
				.frame(maxWidth: .infinity)
		}
		.buttonStyle(.primary)
		.disabled(model.isSubmitting)
	}

	private func errorText(_ message: String) -> some View {
		Text(message)
			.font(Theme.TextStyle.body.font)
			.foregroundStyle(Theme.ColorRole.danger.color)
			.multilineTextAlignment(.center)
			.accessibilityAddTraits(.updatesFrequently)
	}

	private func submit() {
		Task {
			await model.submitGender()
		}
	}
}

#Preview("Fresh") {
	GenderStepView(model: OnboardingModel(
		route: .apple,
		personId: "9",
		credential: APICredential(token: "tok", passwordHash: "hash"),
		onboardingService: InMemoryOnboardingService(),
		sessionStore: PreviewSessionStore.signedOut(),
	))
}

#Preview("Error") {
	GenderStepView(model: OnboardingModel(
		route: .apple,
		personId: "9",
		credential: APICredential(token: "tok", passwordHash: "hash"),
		onboardingService: InMemoryOnboardingService(
			setGenderResult: .failure(.server(message: "Sorry, something went wrong.")),
		),
		sessionStore: PreviewSessionStore.signedOut(),
	))
}

#Preview("Accessibility text size") {
	GenderStepView(model: OnboardingModel(
		route: .apple,
		personId: "9",
		credential: APICredential(token: "tok", passwordHash: "hash"),
		onboardingService: InMemoryOnboardingService(),
		sessionStore: PreviewSessionStore.signedOut(),
	))
	.environment(\.dynamicTypeSize, .accessibility5)
}
