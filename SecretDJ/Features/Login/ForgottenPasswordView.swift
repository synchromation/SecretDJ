import DesignSystem
import Observability
import SwiftUI

/// Forgotten password: one input for a screen name or email, routed to
/// `resetpassword` (``ForgottenPasswordModel``'s doc comment), showing the
/// server's own confirmation or error message afterwards.
struct ForgottenPasswordView: View {
	let model: ForgottenPasswordModel

	@Environment(\.dismiss) private var dismiss
	@FocusState private var isInputFocused: Bool

	var body: some View {
		ScrollView {
			VStack(spacing: Spacing.large) {
				Text("Forgotten Your Password?")
					.font(Theme.TextStyle.screenTitle.font)
					.foregroundStyle(Theme.ColorRole.primaryText.color)
					.multilineTextAlignment(.center)

				Text("Enter your screen name or email and we'll help you reset your password.")
					.font(Theme.TextStyle.body.font)
					.foregroundStyle(Theme.ColorRole.secondaryText.color)
					.multilineTextAlignment(.center)

				TextField("Screen name or email", text: Binding(get: { model.input }, set: model.updateInput))
					.textContentType(.username)
					.textInputAutocapitalization(.never)
					.autocorrectionDisabled()
					.focused($isInputFocused)
					.submitLabel(.send)
					.onSubmit(submit)
					.padding()
					.frame(minHeight: 44)
					.background(Theme.ColorRole.cellSurface.color, in: .rect(cornerRadius: 12))

				sendButton

				if let resultMessage = model.resultMessage {
					Text(resultMessage)
						.font(Theme.TextStyle.body.font)
						.foregroundStyle(model.didSucceed ? Theme.ColorRole.success.color : Theme.ColorRole.danger
							.color)
						.multilineTextAlignment(.center)
						.accessibilityAddTraits(.updatesFrequently)
				}
			}
			.padding(Spacing.large)
		}
		.scrollDismissesKeyboard(.interactively)
		.background(Theme.ColorRole.background.color)
		.tracksScreen("ForgottenPassword")
		.toolbar {
			ToolbarItem(placement: .cancellationAction) {
				Button("Close") {
					dismiss()
				}
			}
		}
	}

	private var sendButton: some View {
		Button(action: submit) {
			Group {
				if model.isSubmitting {
					Text("SENDING...")
				} else {
					Text("SEND")
				}
			}
			.frame(maxWidth: .infinity)
		}
		.buttonStyle(.primary)
		.disabled(!model.canSubmit)
	}

	private func submit() {
		isInputFocused = false
		Task {
			await model.submit()
		}
	}
}

#Preview("Fresh") {
	NavigationStack {
		ForgottenPasswordView(model: ForgottenPasswordModel(authService: InMemoryAuthenticationService()))
	}
}

#Preview("Success") {
	let model = ForgottenPasswordModel(
		authService: InMemoryAuthenticationService(
			resetPasswordResult: .success(PasswordResetOutcome(
				succeeded: true,
				message: "Check your email, TurboTim.",
			)),
		),
	)
	model.updateInput("TurboTim")
	return NavigationStack {
		ForgottenPasswordView(model: model)
	}
}

#Preview("Failure") {
	let model = ForgottenPasswordModel(
		authService: InMemoryAuthenticationService(
			resetPasswordResult: .success(PasswordResetOutcome(
				succeeded: false,
				message: "Sorry, you must enter either the username or email associated with your account.",
			)),
		),
	)
	model.updateInput("nobody")
	return NavigationStack {
		ForgottenPasswordView(model: model)
	}
}

#Preview("Accessibility text size") {
	NavigationStack {
		ForgottenPasswordView(model: ForgottenPasswordModel(authService: InMemoryAuthenticationService()))
	}
	.environment(\.dynamicTypeSize, .accessibility5)
}
