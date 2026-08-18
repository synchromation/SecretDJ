import DesignSystem
import Observability
import SecretDJAPI
import SecretDJDomain
import SwiftUI

/// The Apple route's onboarding step: pick a gender, then continue
/// (LEGACY.md "Login, sign-up, onboarding" — `secretdjv3/LoginGenderViewController.swift`).
struct GenderStepView: View {
	let model: OnboardingModel

	@Environment(\.dynamicTypeSize) private var dynamicTypeSize

	var body: some View {
		ScrollView {
			VStack(spacing: Spacing.large) {
				Text("What's your gender?")
					.font(Theme.TextStyle.screenTitle.font)
					.foregroundStyle(Theme.ColorRole.primaryText.color)

				options

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

	private var options: some View {
		Group {
			if dynamicTypeSize.isAccessibilitySize {
				VStack(spacing: Spacing.small) {
					optionButtons
				}
			} else {
				HStack(spacing: Spacing.small) {
					optionButtons
				}
			}
		}
	}

	@ViewBuilder
	private var optionButtons: some View {
		option(title: "Female", gender: .female)
		option(title: "Male", gender: .male)
		option(title: "Prefer Not To Say", gender: .unisex)
	}

	private func option(title: LocalizedStringResource, gender: Gender) -> some View {
		let isSelected = model.gender == gender

		return Button {
			model.updateGender(gender)
		} label: {
			HStack(spacing: Spacing.extraSmall) {
				Text(title)
				if isSelected {
					Image(systemName: "checkmark.circle.fill")
						.accessibilityHidden(true)
				}
			}
			.frame(maxWidth: .infinity)
			.padding()
			.frame(minHeight: 44)
			.background(
				isSelected ? Theme.ColorRole.accent.color : Theme.ColorRole.cellSurface.color,
				in: .rect(cornerRadius: 12),
			)
			.foregroundStyle(isSelected ? Theme.ColorRole.accentText.color : Theme.ColorRole.primaryText.color)
		}
		.accessibilityAddTraits(isSelected ? [.isSelected] : [])
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
