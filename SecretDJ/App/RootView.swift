import Observability
import SecretDJAPI
import SwiftUI

/// The app's root: what a freshly created account still owes takes priority
/// over everything else — the Apple route's screen-name step first (its
/// `applesignin` call signs the session in before that step has run), then
/// S4.5's onboarding flow; otherwise it gates on whether a session was
/// restored at launch — no session shows the login flow, an existing one
/// shows a placeholder for the signed-in state (S5 replaces this with the
/// real three-tab shell).
struct RootView: View {
	let sessionStore: SessionStore
	let apiClient: APIClient
	let observability: ObservabilityPipeline

	@State private var appleAuthorizing = ASAuthorizationControllerAppleAuthorizing()
	@State private var appleUsernameModel: AppleUsernameModel?
	@State private var onboardingModel: OnboardingModel?

	var body: some View {
		if let appleUsernameModel {
			AppleUsernameView(model: appleUsernameModel, onComplete: finishAppleUsernameStep)
		} else if let onboardingModel {
			OnboardingFlowView(model: onboardingModel, onFinished: { self.onboardingModel = nil })
		} else if sessionStore.isSignedIn {
			SignedInPlaceholderView(sessionStore: sessionStore)
		} else {
			LoginFlow(
				authService: APIClientAuthenticationService(client: apiClient),
				appleAuthorizing: appleAuthorizing,
				appleUserInfoStore: KeychainAppleUserInfoStore(),
				sessionStore: sessionStore,
				observability: observability,
				onAccountCreated: startOnboarding,
				onAppleAccountCreated: startAppleUsernameStep,
			)
		}
	}

	private func startAppleUsernameStep() {
		guard let user = sessionStore.user, let credential = sessionStore.credential else {
			return
		}

		appleUsernameModel = AppleUsernameModel(
			personId: user.personId,
			credential: credential,
			usernameService: APIClientAppleUsernameService(client: apiClient),
			sessionStore: sessionStore,
			observability: observability,
		)
	}

	private func finishAppleUsernameStep() {
		appleUsernameModel = nil
		startOnboarding(route: .apple)
	}

	private func startOnboarding(route: OnboardingRoute) {
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
	}
}
