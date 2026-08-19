import DesignSystem
import Observability
import SecretDJAPI
import SwiftUI

/// The account-deletion confirmation screen: full, sober, unambiguous copy
/// about what deletion means (localization skill: account deletion is a
/// "plain and unambiguous" context — no cheek), then a native destructive
/// confirmation dialog as the second step before `requestdeleteaccount`
/// actually fires (HIG: a destructive action confirms with a
/// system-styled dialog, not a custom button).
struct DeleteAccountView: View {
	let model: AccountModel
	let onCancel: () -> Void

	@State private var isConfirmingDeletion = false

	var body: some View {
		ScrollView {
			VStack(spacing: Spacing.large) {
				Text("Delete Account")
					.font(Theme.TextStyle.screenTitle.font)
					.foregroundStyle(Theme.ColorRole.primaryText.color)

				Text(
					"""
					Deleting your account asks us to permanently remove your profile, your credits, and your activity. \
					Once you confirm this, we can't undo it from the app — you won't be able to sign back in with this account.
					""",
				)
				.font(Theme.TextStyle.body.font)
				.foregroundStyle(Theme.ColorRole.secondaryText.color)
				.multilineTextAlignment(.center)

				if let errorMessage = model.errorMessage {
					errorText(errorMessage)
				}

				deleteButton

				Button("Cancel", action: onCancel)
					.buttonStyle(.secondary)
					.disabled(model.isSubmittingDeletion)
			}
			.padding(Spacing.large)
		}
		.background(Theme.ColorRole.background.color)
		.tracksScreen("DeleteAccount")
		.confirmationDialog(
			"Delete Account?",
			isPresented: $isConfirmingDeletion,
			titleVisibility: .visible,
		) {
			Button("Delete Account", role: .destructive, action: confirmDeletion)
			Button("Cancel", role: .cancel) {}
		} message: {
			Text("This can't be undone.")
		}
	}

	private var deleteButton: some View {
		Button {
			isConfirmingDeletion = true
		} label: {
			Group {
				if model.isSubmittingDeletion {
					Text("DELETING YOUR ACCOUNT...")
				} else {
					Text("DELETE ACCOUNT")
				}
			}
			.frame(maxWidth: .infinity)
		}
		.buttonStyle(.primary)
		.disabled(model.isSubmittingDeletion)
	}

	private func errorText(_ message: String) -> some View {
		Text(message)
			.font(Theme.TextStyle.body.font)
			.foregroundStyle(Theme.ColorRole.danger.color)
			.multilineTextAlignment(.center)
			.accessibilityAddTraits(.updatesFrequently)
	}

	private func confirmDeletion() {
		Task {
			await model.requestDeletion()
		}
	}
}

#Preview("Fresh") {
	DeleteAccountView(
		model: AccountModel(
			personId: "9",
			credential: APICredential(token: "tok", passwordHash: "hash"),
			accountService: InMemoryAccountService(),
			sessionStore: PreviewSessionStore.signedIn(),
		),
		onCancel: {},
	)
}

#Preview("Error") {
	DeleteAccountView(
		model: AccountModel(
			personId: "9",
			credential: APICredential(token: "tok", passwordHash: "hash"),
			accountService: InMemoryAccountService(
				requestDeleteAccountResult: .failure(.server(message: "Sorry, something went wrong.")),
			),
			sessionStore: PreviewSessionStore.signedIn(),
		),
		onCancel: {},
	)
}

#Preview("Accessibility text size") {
	DeleteAccountView(
		model: AccountModel(
			personId: "9",
			credential: APICredential(token: "tok", passwordHash: "hash"),
			accountService: InMemoryAccountService(),
			sessionStore: PreviewSessionStore.signedIn(),
		),
		onCancel: {},
	)
	.environment(\.dynamicTypeSize, .accessibility5)
}
