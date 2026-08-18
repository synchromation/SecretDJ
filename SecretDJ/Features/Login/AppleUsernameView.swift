import DesignSystem
import Observability
import SecretDJAPI
import SwiftUI

/// The Apple sign-up route's screen-name step: the one field
/// `setuserdetails` needs before onboarding's gender and photo steps
/// (LEGACY.md "Login, sign-up, onboarding": Apple → username → gender →
/// photo).
struct AppleUsernameView: View {
	let model: AppleUsernameModel
	let onComplete: () -> Void

	@FocusState private var isScreenNameFocused: Bool

	var body: some View {
		ScrollView {
			VStack(spacing: Spacing.large) {
				Text("Pick your screen name")
					.font(Theme.TextStyle.screenTitle.font)
					.foregroundStyle(Theme.ColorRole.primaryText.color)
					.multilineTextAlignment(.center)
					.accessibilityAddTraits(.isHeader)

				Text("It's the name everyone else sees. Your real name stays private.")
					.font(Theme.TextStyle.body.font)
					.foregroundStyle(Theme.ColorRole.secondaryText.color)
					.multilineTextAlignment(.center)

				screenNameField

				continueButton

				if let errorMessage = model.errorMessage {
					errorText(errorMessage)
				}
			}
			.padding(Spacing.large)
		}
		.scrollDismissesKeyboard(.interactively)
		.background(Theme.ColorRole.background.color)
		.tracksScreen("AppleUsername")
		.onChange(of: model.isComplete) { _, complete in
			if complete {
				onComplete()
			}
		}
	}

	private var screenNameField: some View {
		VStack(alignment: .leading, spacing: Spacing.extraSmall) {
			TextField("Pick a screen name", text: Binding(get: { model.screenName }, set: model.updateScreenName))
				.textContentType(.username)
				.textInputAutocapitalization(.never)
				.autocorrectionDisabled()
				.focused($isScreenNameFocused)
				.submitLabel(.go)
				.onSubmit(submit)
				.padding()
				.frame(minHeight: 44)
				.background(Theme.ColorRole.cellSurface.color, in: .rect(cornerRadius: 12))

			screenNameErrorText
		}
	}

	@ViewBuilder
	private var screenNameErrorText: some View {
		if model.hasAttemptedSubmit, let error = model.screenNameError {
			switch error {
			case .missing:
				fieldError("Please pick a screen name.")

			case .invalidCharacters,
			     .tooShort:
				fieldError("Screen names are 5-30 characters — letters, numbers, hyphens, apostrophes and dots only.")
			}
		}
	}

	private func fieldError(_ text: LocalizedStringResource) -> some View {
		Text(text)
			.font(Theme.TextStyle.caption.font)
			.foregroundStyle(Theme.ColorRole.danger.color)
	}

	private var continueButton: some View {
		Button(action: submit) {
			Text("Continue")
				.frame(maxWidth: .infinity)
		}
		.buttonStyle(.primary)
		.disabled(model.isSubmitting)
	}

	private func errorText(_ message: String) -> some View {
		Text(message)
			.font(Theme.TextStyle.body.font)
			.foregroundStyle(Theme.ColorRole.danger.color)
			.multilineTextAlignment(.center)
			.accessibilityAddTraits(.updatesFrequently)
	}

	private func submit() {
		isScreenNameFocused = false
		Task {
			await model.submit()
		}
	}
}

#Preview("Fresh") {
	AppleUsernameView(model: AppleUsernameModel.preview(), onComplete: {})
}

#Preview("Validation error") {
	let model = AppleUsernameModel.preview()
	model.updateScreenName("Tim")
	return AppleUsernameView(model: model, onComplete: {})
}

#Preview("Server error") {
	AppleUsernameView(
		model: AppleUsernameModel.preview(
			usernameService: InMemoryAppleUsernameService(
				setScreenNameResult: .failure(.server(message: "That screen name is taken.")),
			),
		),
		onComplete: {},
	)
}

#Preview("Accessibility text size") {
	AppleUsernameView(model: AppleUsernameModel.preview(), onComplete: {})
		.environment(\.dynamicTypeSize, .accessibility5)
}

extension AppleUsernameModel {
	/// Previews only — never production (previews always inject fakes, per
	/// swiftui-views).
	fileprivate static func preview(
		usernameService: InMemoryAppleUsernameService = InMemoryAppleUsernameService(),
	) -> AppleUsernameModel {
		AppleUsernameModel(
			personId: "9",
			credential: APICredential(token: "tok", passwordHash: "hash"),
			usernameService: usernameService,
			sessionStore: PreviewSessionStore.signedOut(),
		)
	}
}
