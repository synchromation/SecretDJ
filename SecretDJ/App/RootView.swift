import Observability
import SecretDJAPI
import SharedFeatures
import SwiftUI

/// The app's root: what a freshly created account still owes takes priority
/// over everything else — a social route's screen-name step first (its
/// `applesignin`/`facebooksignin` call signs the session in before that step
/// has run), then S4.5's onboarding flow; otherwise it gates on whether a
/// session was restored at launch — no session shows the login flow, an
/// existing one shows the real three-tab shell (S5.2).
struct RootView: View {
	let sessionStore: SessionStore
	let apiClient: APIClient
	let locationService: LocationService
	let previewPlayerModel: PreviewPlayerModel
	let observability: ObservabilityPipeline

	@State private var appleAuthorizing = ASAuthorizationControllerAppleAuthorizing()
	/// `nil` while ``FacebookConfiguration/isConfigured`` is `false` — no
	/// Facebook SDK type is ever touched in that case (S4.4).
	@State private var facebookAuthorizing: (any FacebookAuthorizing)? =
		FacebookConfiguration.isConfigured ? LoginManagerFacebookAuthorizing() : nil
	@State private var trackingAuthorizing = ATTrackingManagerTrackingAuthorizing()
	@State private var socialUsernameModel: SocialUsernameModel?
	/// Which onboarding route ``finishSocialUsernameStep()`` continues into
	/// — set alongside ``socialUsernameModel`` by whichever social sign-in
	/// route started this step (``SocialUsernameModel`` itself doesn't know
	/// or need to know which route it's serving).
	@State private var pendingOnboardingRoute = OnboardingRoute.apple
	@State private var onboardingModel: OnboardingModel?
	@State private var accountModel: AccountModel?

	var body: some View {
		if let socialUsernameModel {
			SocialUsernameView(model: socialUsernameModel, onComplete: finishSocialUsernameStep)
		} else if let onboardingModel {
			OnboardingFlowView(model: onboardingModel, onFinished: { self.onboardingModel = nil })
		} else if let accountModel {
			// Shown in place of `TabsView`, not as a sheet on top of it — see
			// `AccountFlowView`'s doc comment for why.
			AccountFlowView(model: accountModel, onFinished: { self.accountModel = nil })
		} else if sessionStore.isSignedIn {
			TabsView(
				sessionStore: sessionStore,
				apiClient: apiClient,
				locationService: locationService,
				previewPlayerModel: previewPlayerModel,
				onDeleteAccount: startAccountDeletion,
				observability: observability,
			)
		} else {
			LoginFlow(
				authService: APIClientAuthenticationService(client: apiClient),
				appleAuthorizing: appleAuthorizing,
				appleUserInfoStore: KeychainAppleUserInfoStore(),
				facebookAuthorizing: facebookAuthorizing,
				trackingAuthorizing: trackingAuthorizing,
				sessionStore: sessionStore,
				observability: observability,
				onAccountCreated: startOnboarding,
				onAppleAccountCreated: { startSocialUsernameStep(route: .apple) },
				onFacebookAccountCreated: { startSocialUsernameStep(route: .facebook) },
			)
		}
	}

	private func startSocialUsernameStep(route: OnboardingRoute) {
		guard let user = sessionStore.user, let credential = sessionStore.credential else {
			return
		}

		pendingOnboardingRoute = route
		socialUsernameModel = SocialUsernameModel(
			personId: user.personId,
			credential: credential,
			usernameService: APIClientSocialUsernameService(client: apiClient),
			sessionStore: sessionStore,
			observability: observability,
		)
	}

	private func finishSocialUsernameStep() {
		socialUsernameModel = nil
		startOnboarding(route: pendingOnboardingRoute)
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

	private func startAccountDeletion() {
		guard let user = sessionStore.user, let credential = sessionStore.credential else {
			return
		}

		accountModel = AccountModel(
			personId: user.personId,
			credential: credential,
			accountService: APIClientAccountService(client: apiClient),
			sessionStore: sessionStore,
			observability: observability,
		)
	}
}
