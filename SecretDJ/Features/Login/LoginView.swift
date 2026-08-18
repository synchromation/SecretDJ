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
	let onSignUp: () -> Void
	let onForgotPassword: () -> Void
	/// Called when Sign in with Apple created a brand-new account, which
	/// still owes a screen name before onboarding (``AppleSignInModel``'s
	/// `didCreateAccount`). An existing account needs nothing here — the
	/// session is already signed in.
	let onAppleAccountCreated: () -> Void

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
}

#Preview("Fresh") {
	LoginView(
		model: LoginModel(authService: InMemoryAuthenticationService(), sessionStore: PreviewSessionStore.signedOut()),
		appleModel: AppleSignInModel.preview(),
		onSignUp: {},
		onForgotPassword: {},
		onAppleAccountCreated: {},
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
		onSignUp: {},
		onForgotPassword: {},
		onAppleAccountCreated: {},
	)
}

#Preview("Accessibility text size") {
	LoginView(
		model: LoginModel(authService: InMemoryAuthenticationService(), sessionStore: PreviewSessionStore.signedOut()),
		appleModel: AppleSignInModel.preview(),
		onSignUp: {},
		onForgotPassword: {},
		onAppleAccountCreated: {},
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
