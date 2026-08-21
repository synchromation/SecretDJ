import DesignSystem
import Observability
import SecretDJAPI
import SwiftUI

/// Settings' change-details form (S6.11) — see ``ChangeDetailsModel``'s doc
/// comment for exactly what's ported from the refactor branch's SwiftUI
/// pilot. Field layout and error copy mirror ``SignUpView``'s own (the same
/// ``ProfileDetailsValidator`` rules, so the same messages apply).
struct ChangeDetailsView: View {
	let model: ChangeDetailsModel

	@Environment(\.dismiss) private var dismiss
	@FocusState private var focusedField: Field?

	private enum Field: Hashable {
		case firstName
		case lastName
		case screenName
		case email
	}

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: Spacing.medium) {
				firstNameField
				lastNameField
				screenNameField
				emailField
				saveButton
			}
			.padding(Spacing.large)
		}
		.scrollDismissesKeyboard(.interactively)
		.themedScreen()
		.navigationTitle(Text(
			"Change Details",
			comment: "Navigation title of Settings' change-details screen.",
		))
		.tracksScreen("SettingsChangeDetails")
		.task { await model.load() }
		.onChange(of: model.didSucceed) { _, succeeded in
			if succeeded {
				dismiss()
			}
		}
	}

	private var firstNameField: some View {
		VStack(alignment: .leading, spacing: Spacing.extraSmall) {
			TextField("Your first name", text: Binding(get: { model.firstName }, set: model.updateFirstName))
				.textContentType(.givenName)
				.focused($focusedField, equals: .firstName)
				.submitLabel(.next)
				.onSubmit { focusedField = .lastName }
				.fieldStyle()
			firstNameErrorText
		}
	}

	private var lastNameField: some View {
		VStack(alignment: .leading, spacing: Spacing.extraSmall) {
			TextField("Your last name", text: Binding(get: { model.lastName }, set: model.updateLastName))
				.textContentType(.familyName)
				.focused($focusedField, equals: .lastName)
				.submitLabel(.next)
				.onSubmit { focusedField = .screenName }
				.fieldStyle()
			lastNameErrorText
		}
	}

	private var screenNameField: some View {
		VStack(alignment: .leading, spacing: Spacing.extraSmall) {
			TextField("Your screen name", text: Binding(get: { model.screenName }, set: model.updateScreenName))
				.textContentType(.username)
				.textInputAutocapitalization(.never)
				.autocorrectionDisabled()
				.focused($focusedField, equals: .screenName)
				.submitLabel(.next)
				.onSubmit { focusedField = .email }
				.fieldStyle()
			screenNameErrorText
		}
	}

	private var emailField: some View {
		VStack(alignment: .leading, spacing: Spacing.extraSmall) {
			TextField("Your email", text: Binding(get: { model.email }, set: model.updateEmail))
				.textContentType(.emailAddress)
				.keyboardType(.emailAddress)
				.textInputAutocapitalization(.never)
				.autocorrectionDisabled()
				.focused($focusedField, equals: .email)
				.submitLabel(.done)
				.onSubmit { focusedField = nil }
				.fieldStyle()
			emailErrorText
		}
	}

	private var saveButton: some View {
		Button(action: submit) {
			Group {
				if model.isSaving {
					Text("SAVING...")
				} else {
					Text("SAVE CHANGES")
				}
			}
			.frame(maxWidth: .infinity)
		}
		.buttonStyle(.primary)
		.disabled(model.isLoading || (model.hasAttemptedSubmit && !model.canSave) || model.isSaving)
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
	private var emailErrorText: some View {
		if model.hasAttemptedSubmit, model.emailError != nil {
			fieldError("That doesn't look like a valid email address.")
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
			await model.save()
		}
	}
}

#Preview("Fresh") {
	NavigationStack {
		ChangeDetailsView(model: ChangeDetailsModel(
			personId: "9",
			credential: APICredential(token: "tok", passwordHash: "hash"),
			settingsService: InMemorySettingsService(),
			sessionStore: PreviewSessionStore.signedIn(),
			toastQueue: ToastQueue(),
		))
	}
}

#Preview("Accessibility text size") {
	NavigationStack {
		ChangeDetailsView(model: ChangeDetailsModel(
			personId: "9",
			credential: APICredential(token: "tok", passwordHash: "hash"),
			settingsService: InMemorySettingsService(),
			sessionStore: PreviewSessionStore.signedIn(),
			toastQueue: ToastQueue(),
		))
	}
	.environment(\.dynamicTypeSize, .accessibility5)
}
