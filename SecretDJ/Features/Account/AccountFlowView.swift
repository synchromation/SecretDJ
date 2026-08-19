import SecretDJAPI
import SwiftUI

/// The account-management shell reached from the Profile tab's placeholder
/// (`// S6.11:` relocates the entry point into Settings): shows the
/// delete-account confirmation screen, then swaps to the terminal
/// "deletion requested" screen once ``AccountModel/requestDeletion()``
/// succeeds.
///
/// `RootView` shows this in place of ``TabsView`` — not as a sheet on top of
/// it — because a successful deletion signs the session out mid-flow; a
/// sheet presented from the now-hidden tab shell would be torn down along
/// with it the moment `RootView` reacted to `sessionStore.isSignedIn` going
/// false, taking the calm terminal screen down with it.
struct AccountFlowView: View {
	let model: AccountModel
	let onFinished: () -> Void

	var body: some View {
		if model.isDeletionRequested {
			AccountDeletionRequestedView(onClose: onFinished)
		} else {
			DeleteAccountView(model: model, onCancel: onFinished)
		}
	}
}

#Preview("Confirming") {
	AccountFlowView(
		model: AccountModel(
			personId: "9",
			credential: APICredential(token: "tok", passwordHash: "hash"),
			accountService: InMemoryAccountService(),
			sessionStore: PreviewSessionStore.signedIn(),
		),
		onFinished: {},
	)
}

#Preview("Accessibility text size") {
	AccountFlowView(
		model: AccountModel(
			personId: "9",
			credential: APICredential(token: "tok", passwordHash: "hash"),
			accountService: InMemoryAccountService(),
			sessionStore: PreviewSessionStore.signedIn(),
		),
		onFinished: {},
	)
	.environment(\.dynamicTypeSize, .accessibility5)
}
