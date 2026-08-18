import SecretDJAPI
import SwiftUI

/// The onboarding navigation shell: shows ``model``'s current step and
/// calls `onFinished` once every step is done. No push/pop navigation is
/// needed — progression through ``OnboardingRoute/steps`` is one-directional
/// and irreversible, matching legacy's non-back-navigable overlay flow
/// (LEGACY.md "Login, sign-up, onboarding").
struct OnboardingFlowView: View {
	let model: OnboardingModel
	let onFinished: () -> Void

	var body: some View {
		Group {
			switch model.currentStep {
			case .genderSelection:
				GenderStepView(model: model)

			case .photo:
				PhotoStepView(model: model)

			case nil:
				EmptyView()
			}
		}
		.onChange(of: model.isComplete) { _, complete in
			if complete {
				onFinished()
			}
		}
	}
}

#Preview("Apple route — gender step") {
	OnboardingFlowView(
		model: OnboardingModel(
			route: .apple,
			personId: "9",
			credential: APICredential(token: "tok", passwordHash: "hash"),
			onboardingService: InMemoryOnboardingService(),
			sessionStore: PreviewSessionStore.signedOut(),
		),
		onFinished: {},
	)
}

#Preview("Native route — photo step") {
	OnboardingFlowView(
		model: OnboardingModel(
			route: .native,
			personId: "9",
			credential: APICredential(token: "tok", passwordHash: "hash"),
			onboardingService: InMemoryOnboardingService(),
			sessionStore: PreviewSessionStore.signedOut(),
		),
		onFinished: {},
	)
}
