import DesignSystem
import Observability
import SecretDJDomain
import SwiftUI

/// The sign-up details form: first/last name, gender, email, screen name,
/// and password — the fields `createuser` needs in one screen (the
/// dedicated gender/photo onboarding screens are S4.5; see
/// ``SignUpModel``'s doc comment).
struct SignUpView: View {
	let model: SignUpModel

	@FocusState private var focusedField: Field?

	private enum Field {
		case firstName
		case lastName
		case email
		case screenName
		case password
	}

	var body: some View {
		ScrollView {
			VStack(spacing: Spacing.large) {
				Text("Create Your Account")
					.font(Theme.TextStyle.screenTitle.font)
					.foregroundStyle(Theme.ColorRole.primaryText.color)

				nameFields
				genderPicker
				emailField
				screenNameField
				passwordField
				submitButton

				if let errorMessage = model.errorMessage {
					errorText(errorMessage)
				}
			}
			.padding(Spacing.large)
		}
		.scrollDismissesKeyboard(.interactively)
		.background(Theme.ColorRole.background.color)
		.tracksScreen("SignUp")
	}

	private var nameFields: some View {
		VStack(spacing: Spacing.medium) {
			VStack(alignment: .leading, spacing: Spacing.extraSmall) {
				TextField("Your first name", text: Binding(get: { model.firstName }, set: model.updateFirstName))
					.textContentType(.givenName)
					.focused($focusedField, equals: .firstName)
					.submitLabel(.next)
					.onSubmit { focusedField = .lastName }
					.fieldStyle()
				firstNameErrorText
			}

			VStack(alignment: .leading, spacing: Spacing.extraSmall) {
				TextField("Your last name", text: Binding(get: { model.lastName }, set: model.updateLastName))
					.textContentType(.familyName)
					.focused($focusedField, equals: .lastName)
					.submitLabel(.next)
					.onSubmit { focusedField = .email }
					.fieldStyle()
				lastNameErrorText
			}
		}
	}

	private var genderPicker: some View {
		Picker("Gender", selection: Binding(get: { model.gender }, set: model.updateGender)) {
			Text("Female").tag(Gender.female)
			Text("Male").tag(Gender.male)
			Text("Prefer Not To Say").tag(Gender.unisex)
		}
		.pickerStyle(.segmented)
	}

	private var emailField: some View {
		VStack(alignment: .leading, spacing: Spacing.extraSmall) {
			TextField("Your email", text: Binding(get: { model.email }, set: model.updateEmail))
				.textContentType(.emailAddress)
				.keyboardType(.emailAddress)
				.textInputAutocapitalization(.never)
				.autocorrectionDisabled()
				.focused($focusedField, equals: .email)
				.submitLabel(.next)
				.onSubmit { focusedField = .screenName }
				.fieldStyle()
			emailErrorText
		}
	}

	private var screenNameField: some View {
		VStack(alignment: .leading, spacing: Spacing.extraSmall) {
			TextField("Pick a screen name", text: Binding(get: { model.screenName }, set: model.updateScreenName))
				.textContentType(.username)
				.textInputAutocapitalization(.never)
				.autocorrectionDisabled()
				.focused($focusedField, equals: .screenName)
				.submitLabel(.next)
				.onSubmit { focusedField = .password }
				.fieldStyle()
			screenNameErrorText
		}
	}

	private var passwordField: some View {
		VStack(alignment: .leading, spacing: Spacing.extraSmall) {
			SecureField("Pick a password", text: Binding(get: { model.password }, set: model.updatePassword))
				.textContentType(.newPassword)
				.focused($focusedField, equals: .password)
				.submitLabel(.go)
				.onSubmit(submit)
				.fieldStyle()
			passwordErrorText
		}
	}

	private var submitButton: some View {
		Button(action: submit) {
			Group {
				if model.isSubmitting {
					Text("CREATING ACCOUNT...")
				} else {
					Text("CREATE ACCOUNT")
				}
			}
			.frame(maxWidth: .infinity)
		}
		.buttonStyle(.primary)
		.disabled(!model.canSubmit)
	}

	private func errorText(_ message: String) -> some View {
		Text(message)
			.font(Theme.TextStyle.body.font)
			.foregroundStyle(Theme.ColorRole.danger.color)
			.multilineTextAlignment(.center)
			.accessibilityAddTraits(.updatesFrequently)
	}

	@ViewBuilder
	private var firstNameErrorText: some View {
		if model.hasAttemptedSubmit, let error = model.firstNameError {
			switch error {
			case .missing:
				fieldError("Please tell us your first name.")

			case .invalidCharacters,
			     .tooShort:
				fieldError("First names can only contain letters, numbers, hyphens and apostrophes.")
			}
		}
	}

	@ViewBuilder
	private var lastNameErrorText: some View {
		if model.hasAttemptedSubmit, let error = model.lastNameError {
			switch error {
			case .missing:
				fieldError("Please tell us your last name.")

			case .invalidCharacters,
			     .tooShort:
				fieldError("Last names can only contain letters, numbers, hyphens and apostrophes.")
			}
		}
	}

	@ViewBuilder
	private var emailErrorText: some View {
		if model.hasAttemptedSubmit, model.emailError != nil {
			fieldError("That doesn't look like a valid email address.")
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

	@ViewBuilder
	private var passwordErrorText: some View {
		if model.hasAttemptedSubmit, let error = model.passwordError {
			switch error {
			case .missing:
				fieldError("Please pick a password.")

			case .invalidCharacters,
			     .tooShort:
				fieldError("Passwords need at least 5 characters.")
			}
		}
	}

	private func fieldError(_ text: LocalizedStringResource) -> some View {
		Text(text)
			.font(Theme.TextStyle.caption.font)
			.foregroundStyle(Theme.ColorRole.danger.color)
	}

	private func submit() {
		focusedField = nil
		Task {
			await model.submit()
		}
	}
}

extension View {
	fileprivate func fieldStyle() -> some View {
		padding()
			.frame(minHeight: 44)
			.background(Theme.ColorRole.cellSurface.color, in: .rect(cornerRadius: 12))
	}
}

#Preview("Fresh") {
	SignUpView(model: SignUpModel(
		authService: InMemoryAuthenticationService(),
		sessionStore: PreviewSessionStore.signedOut(),
	))
}

#Preview("Validation errors") {
	let model = SignUpModel(authService: InMemoryAuthenticationService(), sessionStore: PreviewSessionStore.signedOut())
	model.updateEmail("not-an-email")
	return SignUpView(model: model)
}

#Preview("Sign-up error") {
	let model = SignUpModel(
		authService: InMemoryAuthenticationService(
			createUserResult: .failure(.server(message: "That screen name is taken.")),
		),
		sessionStore: PreviewSessionStore.signedOut(),
	)
	model.updateFirstName("Tim")
	model.updateLastName("Harrison")
	model.updateEmail("tim@example.com")
	model.updateScreenName("TurboTim")
	model.updatePassword("hunter2")
	return SignUpView(model: model)
}

#Preview("Accessibility text size") {
	SignUpView(model: SignUpModel(
		authService: InMemoryAuthenticationService(),
		sessionStore: PreviewSessionStore.signedOut(),
	))
	.environment(\.dynamicTypeSize, .accessibility5)
}
