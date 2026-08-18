import Observability
import SecretDJAPI
import SwiftUI

/// The login flow's navigation shell — the SwiftUI replacement for the
/// legacy overlay-window `LoginFlowController`
/// (LEGACY.md "Login, sign-up, onboarding"): native sign-in and Sign in with
/// Apple at the root of a `NavigationStack`, with sign-up pushed and
/// forgotten-password presented as a sheet.
///
/// The Apple route's own screen-name step doesn't live here: `applesignin`
/// signs the session in the moment it succeeds, so everything a brand-new
/// Apple account still owes is driven from `RootView`, which outranks the
/// signed-in state (`onAppleAccountCreated`).
struct LoginFlow: View {
	let authService: any AuthenticationServicing
	let sessionStore: SessionStore
	let observability: ObservabilityPipeline
	let onAccountCreated: (OnboardingRoute) -> Void
	let onAppleAccountCreated: () -> Void

	@State private var loginModel: LoginModel
	@State private var appleSignInModel: AppleSignInModel
	@State private var showsSignUp = false
	@State private var showsForgottenPassword = false

	init(
		authService: any AuthenticationServicing,
		appleAuthorizing: any AppleAuthorizing,
		appleUserInfoStore: any AppleUserInfoStoring,
		sessionStore: SessionStore,
		observability: ObservabilityPipeline = .disabled,
		onAccountCreated: @escaping (OnboardingRoute) -> Void,
		onAppleAccountCreated: @escaping () -> Void,
	) {
		self.authService = authService
		self.sessionStore = sessionStore
		self.observability = observability
		self.onAccountCreated = onAccountCreated
		self.onAppleAccountCreated = onAppleAccountCreated
		_loginModel = State(initialValue: LoginModel(
			authService: authService,
			sessionStore: sessionStore,
			observability: observability,
		))
		_appleSignInModel = State(initialValue: AppleSignInModel(
			appleAuthorizing: appleAuthorizing,
			appleUserInfoStore: appleUserInfoStore,
			authService: authService,
			sessionStore: sessionStore,
			observability: observability,
		))
	}

	var body: some View {
		NavigationStack {
			LoginView(
				model: loginModel,
				appleModel: appleSignInModel,
				onSignUp: { showsSignUp = true },
				onForgotPassword: { showsForgottenPassword = true },
				onAppleAccountCreated: onAppleAccountCreated,
			)
			.navigationDestination(isPresented: $showsSignUp) {
				SignUpView(
					model: SignUpModel(
						authService: authService,
						sessionStore: sessionStore,
						observability: observability,
					),
					onAccountCreated: onAccountCreated,
				)
			}
		}
		.sheet(isPresented: $showsForgottenPassword) {
			NavigationStack {
				ForgottenPasswordView(model: ForgottenPasswordModel(
					authService: authService,
					observability: observability,
				))
			}
		}
	}
}
