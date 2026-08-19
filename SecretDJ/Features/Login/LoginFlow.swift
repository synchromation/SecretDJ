import Observability
import SecretDJAPI
import SwiftUI

/// The login flow's navigation shell — the SwiftUI replacement for the
/// legacy overlay-window `LoginFlowController`
/// (LEGACY.md "Login, sign-up, onboarding"): native sign-in, Sign in with
/// Apple, and Facebook sign-in at the root of a `NavigationStack`, with
/// sign-up pushed and forgotten-password presented as a sheet.
///
/// Neither social route's own screen-name step lives here: `applesignin`/
/// `facebooksignin` sign the session in the moment they succeed, so
/// everything a brand-new social account still owes is driven from
/// `RootView`, which outranks the signed-in state (`onAppleAccountCreated`/
/// `onFacebookAccountCreated`).
struct LoginFlow: View {
	let authService: any AuthenticationServicing
	let sessionStore: SessionStore
	let observability: ObservabilityPipeline
	let onAccountCreated: (OnboardingRoute) -> Void
	let onAppleAccountCreated: () -> Void
	let onFacebookAccountCreated: () -> Void

	@State private var loginModel: LoginModel
	@State private var appleSignInModel: AppleSignInModel
	@State private var facebookSignInModel: FacebookSignInModel?
	@State private var showsSignUp = false
	@State private var showsForgottenPassword = false

	/// `facebookAuthorizing` is `nil` while
	/// ``FacebookConfiguration/isConfigured`` is `false` — no
	/// `FacebookSignInModel` is constructed, so `LoginView` never shows the
	/// Facebook button (S4.4: the app must run fully without a real client
	/// token).
	init(
		authService: any AuthenticationServicing,
		appleAuthorizing: any AppleAuthorizing,
		appleUserInfoStore: any AppleUserInfoStoring,
		facebookAuthorizing: (any FacebookAuthorizing)?,
		trackingAuthorizing: any TrackingAuthorizing,
		sessionStore: SessionStore,
		observability: ObservabilityPipeline = .disabled,
		onAccountCreated: @escaping (OnboardingRoute) -> Void,
		onAppleAccountCreated: @escaping () -> Void,
		onFacebookAccountCreated: @escaping () -> Void,
	) {
		self.authService = authService
		self.sessionStore = sessionStore
		self.observability = observability
		self.onAccountCreated = onAccountCreated
		self.onAppleAccountCreated = onAppleAccountCreated
		self.onFacebookAccountCreated = onFacebookAccountCreated
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
		_facebookSignInModel = State(initialValue: facebookAuthorizing.map { facebookAuthorizing in
			FacebookSignInModel(
				trackingAuthorizing: trackingAuthorizing,
				facebookAuthorizing: facebookAuthorizing,
				authService: authService,
				sessionStore: sessionStore,
				observability: observability,
			)
		})
	}

	var body: some View {
		NavigationStack {
			LoginView(
				model: loginModel,
				appleModel: appleSignInModel,
				facebookModel: facebookSignInModel,
				onSignUp: { showsSignUp = true },
				onForgotPassword: { showsForgottenPassword = true },
				onAppleAccountCreated: onAppleAccountCreated,
				onFacebookAccountCreated: onFacebookAccountCreated,
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
