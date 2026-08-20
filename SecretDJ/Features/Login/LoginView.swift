import DesignSystem
import Observability
import SecretDJAPI
import SwiftUI

/// Native sign-in: screen name and password, with Sign in with Apple and
/// routes to sign-up and forgotten password
/// (`secretdjv3/LoginViewController.swift`).
struct LoginView: View {
	let model: LoginModel
	let appleModel: AppleSignInModel
	/// `nil` while ``FacebookConfiguration/isConfigured`` is `false` — the
	/// Facebook button doesn't render at all in that case (S4.4).
	let facebookModel: FacebookSignInModel?
	let onSignUp: () -> Void
	let onForgotPassword: () -> Void
	/// Called when Sign in with Apple created a brand-new account, which
	/// still owes a screen name before onboarding (``AppleSignInModel``'s
	/// `didCreateAccount`). An existing account needs nothing here — the
	/// session is already signed in.
	let onAppleAccountCreated: () -> Void
	/// The Facebook equivalent of ``onAppleAccountCreated``
	/// (``FacebookSignInModel``'s `didCreateAccount`).
	let onFacebookAccountCreated: () -> Void

	@FocusState private var focusedField: Field?

	private enum Field {
		case screenName
		case password
	}

	var body: some View {
		ScrollView {
			VStack(spacing: Spacing.large) {
				Text("Welcome Back")
					.font(Theme.TextStyle.screenTitle.font)
					.foregroundStyle(Theme.ColorRole.primaryText.color)

				fields

				signInButton

				if let errorMessage = model.errorMessage {
					errorText(errorMessage)
				}

				appleSignIn

				if let facebookModel {
					facebookSignIn(facebookModel)
				}

				Button("Forgotten Your Password?", action: onForgotPassword)
					.font(Theme.TextStyle.body.font)
					.foregroundStyle(Theme.ColorRole.accent.color)
					.frame(minHeight: 44)

				signUpPrompt
			}
			.padding(Spacing.large)
		}
		.scrollDismissesKeyboard(.interactively)
		.background(Theme.ColorRole.background.color)
		.tracksScreen("Login")
		.onChange(of: appleModel.didCreateAccount) { _, created in
			if created {
				onAppleAccountCreated()
			}
		}
		.onChange(of: facebookModel?.didCreateAccount) { _, created in
			if created == true {
				onFacebookAccountCreated()
			}
		}
	}

	private var fields: some View {
		VStack(spacing: Spacing.medium) {
			TextField("Your screen name", text: Binding(get: { model.screenName }, set: model.updateScreenName))
				.textContentType(.username)
				.textInputAutocapitalization(.never)
				.autocorrectionDisabled()
				.focused($focusedField, equals: .screenName)
				.submitLabel(.next)
				.onSubmit { focusedField = .password }
				.padding()
				.frame(minHeight: 44)
				.background(Theme.ColorRole.cellSurface.color, in: .rect(cornerRadius: 12))

			// S8.2-FOLLOWUP: performAccessibilityAudit() flags this field's
			// text as possibly clipped at larger Dynamic Type sizes
			// (SwiftUI.UIKitTextField). The plain TextField immediately
			// above shares identical layout (no fixed frame, same padding)
			// and passes clean, so this looks like SecureField's own
			// UIKit-bridged implementation rather than app layout — confirm
			// with Accessibility Inspector on a real device at AX5 before
			// attempting a fix.
			SecureField("Your password", text: Binding(get: { model.password }, set: model.updatePassword))
				.textContentType(.password)
				.focused($focusedField, equals: .password)
				.submitLabel(.go)
				.onSubmit(signIn)
				.padding()
				.frame(minHeight: 44)
				.background(Theme.ColorRole.cellSurface.color, in: .rect(cornerRadius: 12))
		}
	}

	private var signInButton: some View {
		Button(action: signIn) {
			Group {
				if model.isSigningIn {
					Text("SIGNING IN...")
				} else {
					Text("SIGN IN")
				}
			}
			.frame(maxWidth: .infinity)
		}
		.buttonStyle(.primary)
		.disabled(!model.canSignIn)
	}

	private var appleSignIn: some View {
		VStack(spacing: Spacing.small) {
			AppleSignInButton(action: signInWithApple)
				.disabled(appleModel.isSigningIn)

			if let errorMessage = appleModel.errorMessage {
				errorText(errorMessage)
			}
		}
	}

	private func facebookSignIn(_ facebookModel: FacebookSignInModel) -> some View {
		VStack(spacing: Spacing.small) {
			FacebookSignInButton(action: { signInWithFacebook(facebookModel) })
				.disabled(!facebookModel.canSignIn)

			if let errorMessage = facebookModel.errorMessage {
				errorText(errorMessage)
			}
		}
	}

	private func errorText(_ message: String) -> some View {
		Text(message)
			.font(Theme.TextStyle.body.font)
			.foregroundStyle(Theme.ColorRole.danger.color)
			.multilineTextAlignment(.center)
			.accessibilityAddTraits(.updatesFrequently)
	}

	private var signUpPrompt: some View {
		VStack(spacing: Spacing.small) {
			Text("IT'S MY FIRST TIME")
				.font(Theme.TextStyle.caption.font)
				.foregroundStyle(Theme.ColorRole.secondaryText.color)

			Button("SIGN ME UP", action: onSignUp)
				.buttonStyle(.secondary)
				.frame(maxWidth: .infinity)
		}
	}

	private func signIn() {
		focusedField = nil
		Task {
			await model.signIn()
		}
	}

	private func signInWithApple() {
		focusedField = nil
		Task {
			await appleModel.signInWithApple()
		}
	}

	private func signInWithFacebook(_ facebookModel: FacebookSignInModel) {
		focusedField = nil
		Task {
			await facebookModel.signInWithFacebook()
		}
	}
}

#Preview("Fresh") {
	LoginView(
		model: LoginModel(authService: InMemoryAuthenticationService(), sessionStore: PreviewSessionStore.signedOut()),
		appleModel: AppleSignInModel.preview(),
		facebookModel: FacebookSignInModel.preview(),
		onSignUp: {},
		onForgotPassword: {},
		onAppleAccountCreated: {},
		onFacebookAccountCreated: {},
	)
}

#Preview("Sign-in error") {
	let model = LoginModel(
		authService: InMemoryAuthenticationService(signInResult: .failure(.server(message: "Wrong password."))),
		sessionStore: PreviewSessionStore.signedOut(),
	)
	model.updateScreenName("TurboTim")
	model.updatePassword("wrongpass")
	return LoginView(
		model: model,
		appleModel: AppleSignInModel.preview(),
		facebookModel: FacebookSignInModel.preview(),
		onSignUp: {},
		onForgotPassword: {},
		onAppleAccountCreated: {},
		onFacebookAccountCreated: {},
	)
}

#Preview("Facebook not configured") {
	LoginView(
		model: LoginModel(authService: InMemoryAuthenticationService(), sessionStore: PreviewSessionStore.signedOut()),
		appleModel: AppleSignInModel.preview(),
		facebookModel: nil,
		onSignUp: {},
		onForgotPassword: {},
		onAppleAccountCreated: {},
		onFacebookAccountCreated: {},
	)
}

#Preview("Facebook tracking denied") {
	LoginView(
		model: LoginModel(authService: InMemoryAuthenticationService(), sessionStore: PreviewSessionStore.signedOut()),
		appleModel: AppleSignInModel.preview(),
		facebookModel: FacebookSignInModel.preview(trackingStatus: .denied),
		onSignUp: {},
		onForgotPassword: {},
		onAppleAccountCreated: {},
		onFacebookAccountCreated: {},
	)
}

#Preview("Accessibility text size") {
	LoginView(
		model: LoginModel(authService: InMemoryAuthenticationService(), sessionStore: PreviewSessionStore.signedOut()),
		appleModel: AppleSignInModel.preview(),
		facebookModel: FacebookSignInModel.preview(),
		onSignUp: {},
		onForgotPassword: {},
		onAppleAccountCreated: {},
		onFacebookAccountCreated: {},
	)
	.environment(\.dynamicTypeSize, .accessibility5)
}

extension AppleSignInModel {
	/// Previews only — never production (previews always inject fakes, per
	/// swiftui-views).
	fileprivate static func preview() -> AppleSignInModel {
		AppleSignInModel(
			appleAuthorizing: InMemoryAppleAuthorizing(),
			appleUserInfoStore: InMemoryAppleUserInfoStore(),
			authService: InMemoryAuthenticationService(),
			sessionStore: PreviewSessionStore.signedOut(),
		)
	}
}

extension FacebookSignInModel {
	/// Previews only — never production (previews always inject fakes, per
	/// swiftui-views).
	fileprivate static func preview(trackingStatus: TrackingAuthorizationStatus = .authorized) -> FacebookSignInModel {
		FacebookSignInModel(
			trackingAuthorizing: InMemoryTrackingAuthorizing(status: trackingStatus),
			facebookAuthorizing: InMemoryFacebookAuthorizing(),
			authService: InMemoryAuthenticationService(),
			sessionStore: PreviewSessionStore.signedOut(),
		)
	}
}
