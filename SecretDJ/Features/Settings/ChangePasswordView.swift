import DesignSystem
import Observability
import SecretDJAPI
import SwiftUI

/// Settings' change-password form (S6.11) — see ``ChangePasswordModel``'s
/// doc comment for exactly what's ported from the refactor branch's
/// SwiftUI pilot.
struct ChangePasswordView: View {
	let model: ChangePasswordModel

	@Environment(\.dismiss) private var dismiss
	@FocusState private var focusedField: Field?

	private enum Field: Hashable {
		case currentPassword
		case newPassword
	}

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: Spacing.medium) {
				currentPasswordField
				newPasswordField
				saveButton
			}
			.padding(Spacing.large)
		}
		.scrollDismissesKeyboard(.interactively)
		.themedScreen()
		.navigationTitle(Text(
			"Change Password",
			comment: "Navigation title of Settings' change-password screen.",
		))
		.tracksScreen("SettingsChangePassword")
		.onChange(of: model.didSucceed) { _, succeeded in
			if succeeded {
				dismiss()
			}
		}
	}

	private var currentPasswordField: some View {
		VStack(alignment: .leading, spacing: Spacing.extraSmall) {
			SecureField(
				"Current password",
				text: Binding(get: { model.currentPassword }, set: model.updateCurrentPassword),
			)
			.textContentType(.password)
			.focused($focusedField, equals: .currentPassword)
			.submitLabel(.next)
			.onSubmit { focusedField = .newPassword }
			.fieldStyle()
			currentPasswordErrorText
		}
	}

	private var newPasswordField: some View {
		VStack(alignment: .leading, spacing: Spacing.extraSmall) {
			SecureField("New password", text: Binding(get: { model.newPassword }, set: model.updateNewPassword))
				.textContentType(.newPassword)
				.focused($focusedField, equals: .newPassword)
				.submitLabel(.done)
				.onSubmit(submit)
				.fieldStyle()
			newPasswordErrorText
		}
	}

	private var saveButton: some View {
		Button(action: submit) {
			Group {
				if model.isSaving {
					Text("UPDATING...")
				} else {
					Text("UPDATE PASSWORD")
				}
			}
			.frame(maxWidth: .infinity)
		}
		.buttonStyle(.primary)
		.disabled(model.hasAttemptedSubmit && !model.canSave)
	}

	@ViewBuilder
	private var currentPasswordErrorText: some View {
		if model.currentPasswordIsIncorrect {
			fieldError("Sorry, that's not your current password.")
		}
	}

	@ViewBuilder
	private var newPasswordErrorText: some View {
		if model.hasAttemptedSubmit, model.newPasswordError != nil {
			fieldError("Passwords need at least 5 characters.")
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
		ChangePasswordView(model: ChangePasswordModel(
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
		ChangePasswordView(model: ChangePasswordModel(
			personId: "9",
			credential: APICredential(token: "tok", passwordHash: "hash"),
			settingsService: InMemorySettingsService(),
			sessionStore: PreviewSessionStore.signedIn(),
			toastQueue: ToastQueue(),
		))
	}
	.environment(\.dynamicTypeSize, .accessibility5)
}
