import Observability
import SecretDJAPI
import SwiftUI

/// The login flow's navigation shell — the SwiftUI replacement for the
/// legacy overlay-window `LoginFlowController`
/// (LEGACY.md "Login, sign-up, onboarding"): native sign-in at the root of
/// a `NavigationStack`, with sign-up pushed and forgotten-password
/// presented as a sheet.
struct LoginFlow: View {
	let authService: any AuthenticationServicing
	let sessionStore: SessionStore
	let observability: ObservabilityPipeline
	let onAccountCreated: (OnboardingRoute) -> Void

	@State private var loginModel: LoginModel
	@State private var showsSignUp = false
	@State private var showsForgottenPassword = false

	init(
		authService: any AuthenticationServicing,
		sessionStore: SessionStore,
		observability: ObservabilityPipeline = .disabled,
		onAccountCreated: @escaping (OnboardingRoute) -> Void,
	) {
		self.authService = authService
		self.sessionStore = sessionStore
		self.observability = observability
		self.onAccountCreated = onAccountCreated
		_loginModel = State(initialValue: LoginModel(
			authService: authService,
			sessionStore: sessionStore,
			observability: observability,
		))
	}

	var body: some View {
		NavigationStack {
			LoginView(
				model: loginModel,
				onSignUp: { showsSignUp = true },
				onForgotPassword: { showsForgottenPassword = true },
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
