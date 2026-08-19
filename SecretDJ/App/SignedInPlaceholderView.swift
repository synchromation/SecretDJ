import DesignSystem
import Observability
import SecretDJAPI
import SwiftUI

/// A themed placeholder for the signed-in state: the session's screen name,
/// a way to sign out, and the entry point into account deletion
/// (`// S6.11:` relocates that entry point into Settings). S5 replaces this
/// with the real three-tab shell.
struct SignedInPlaceholderView: View {
	let sessionStore: SessionStore
	/// Starts the ``AccountFlowView`` delete-account flow, owned by
	/// `RootView` — see its doc comment for why that flow isn't simply
	/// presented as a sheet from here.
	let onDeleteAccount: () -> Void

	@Environment(\.observability) private var observability

	@State private var isConfirmingSignOut = false

	var body: some View {
		VStack(spacing: Spacing.large) {
			Text("You're signed in")
				.font(Theme.TextStyle.screenTitle.font)
				.foregroundStyle(Theme.ColorRole.primaryText.color)

			if let screenName = sessionStore.user?.screenName {
				Text("Signed in as \(screenName)")
					.font(Theme.TextStyle.body.font)
					.foregroundStyle(Theme.ColorRole.secondaryText.color)
			}

			Button("Sign Out") {
				isConfirmingSignOut = true
			}
			.buttonStyle(.secondary)

			// S6.11: relocate this entry point into Settings.
			Button("Delete Account", action: onDeleteAccount)
				.font(Theme.TextStyle.body.font)
				.foregroundStyle(Theme.ColorRole.danger.color)
				.frame(minHeight: 44)
		}
		.padding(Spacing.large)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(Theme.ColorRole.background.color)
		.tracksScreen("SignedInPlaceholder")
		.confirmationDialog(
			"Sign Out?",
			isPresented: $isConfirmingSignOut,
			titleVisibility: .visible,
		) {
			Button("Sign Out", role: .destructive, action: signOut)
			Button("Cancel", role: .cancel) {}
		}
	}

	private func signOut() {
		observability.interaction("signOut")
		sessionStore.signOut()
	}
}

#Preview("Signed in") {
	SignedInPlaceholderView(sessionStore: PreviewSessionStore.signedIn(), onDeleteAccount: {})
}

#Preview("Accessibility text size") {
	SignedInPlaceholderView(sessionStore: PreviewSessionStore.signedIn(), onDeleteAccount: {})
		.environment(\.dynamicTypeSize, .accessibility5)
}
