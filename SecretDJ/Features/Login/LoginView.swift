import DesignSystem
import Observability
import SwiftUI

/// Native sign-in: screen name and password, with routes to sign-up and
/// forgotten password (`secretdjv3/LoginViewController.swift`).
struct LoginView: View {
	let model: LoginModel
	let onSignUp: () -> Void
	let onForgotPassword: () -> Void

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
}

#Preview("Fresh") {
	LoginView(
		model: LoginModel(authService: InMemoryAuthenticationService(), sessionStore: PreviewSessionStore.signedOut()),
		onSignUp: {},
		onForgotPassword: {},
	)
}

#Preview("Sign-in error") {
	let model = LoginModel(
		authService: InMemoryAuthenticationService(signInResult: .failure(.server(message: "Wrong password."))),
		sessionStore: PreviewSessionStore.signedOut(),
	)
	model.updateScreenName("TurboTim")
	model.updatePassword("wrongpass")
	return LoginView(model: model, onSignUp: {}, onForgotPassword: {})
}

#Preview("Accessibility text size") {
	LoginView(
		model: LoginModel(authService: InMemoryAuthenticationService(), sessionStore: PreviewSessionStore.signedOut()),
		onSignUp: {},
		onForgotPassword: {},
	)
	.environment(\.dynamicTypeSize, .accessibility5)
}
