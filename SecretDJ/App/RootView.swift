import Observability
import SecretDJAPI
import SwiftUI

/// The app's root: a freshly created account takes priority and shows S4.5's
/// onboarding flow before anything else; otherwise gates on whether a
/// session was restored at launch — no session shows the login flow, an
/// existing one shows a placeholder for the signed-in state (S5 replaces
/// this with the real three-tab shell).
struct RootView: View {
	let sessionStore: SessionStore
	let apiClient: APIClient
	let observability: ObservabilityPipeline

	@State private var onboardingModel: OnboardingModel?

	var body: some View {
		if let onboardingModel {
			OnboardingFlowView(model: onboardingModel, onFinished: { self.onboardingModel = nil })
		} else if sessionStore.isSignedIn {
			SignedInPlaceholderView(sessionStore: sessionStore)
		} else {
			LoginFlow(
				authService: APIClientAuthenticationService(client: apiClient),
				sessionStore: sessionStore,
				observability: observability,
				onAccountCreated: { route in
					guard let user = sessionStore.user, let credential = sessionStore.credential else {
						return
					}

					onboardingModel = OnboardingModel(
						route: route,
						personId: user.personId,
						credential: credential,
						onboardingService: APIClientOnboardingService(client: apiClient),
						sessionStore: sessionStore,
						observability: observability,
					)
				},
			)
		}
	}
}
