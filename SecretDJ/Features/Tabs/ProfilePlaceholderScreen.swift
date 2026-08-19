import DesignSystem
import Observability
import SecretDJAPI
import SwiftUI

/// The Profile tab's root, until S6.6 lands the real own-profile feed
/// (LEGACY.md "Tab 3 — Profile"). Carries the session's screen name and the
/// sign-out/delete-account entry points S5's pre-tabs signed-in placeholder
/// used to host (`// S6.11:` relocates delete-account into Settings).
struct ProfilePlaceholderScreen: View {
	let sessionStore: SessionStore
	/// Starts the ``AccountFlowView`` delete-account flow, owned by
	/// `RootView` — see its doc comment for why that flow isn't simply
	/// presented as a sheet from here.
	let onDeleteAccount: () -> Void

	@Environment(\.observability) private var observability

	@State private var isConfirmingSignOut = false

	var body: some View {
		VStack(spacing: Spacing.large) {
			Image(systemName: Theme.Icon.profile.systemName)
				.font(.system(size: 40))
				.foregroundStyle(Theme.ColorRole.secondaryText.color)
				.accessibilityHidden(true)

			if let screenName = sessionStore.user?.screenName {
				Text("Signed in as \(screenName)", comment: "Shows the current user's screen name on the Profile tab.")
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
		.navigationTitle(Text("Profile", comment: "Navigation title of the Profile tab."))
		.tracksScreen("Profile")
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
	NavigationStack {
		ProfilePlaceholderScreen(sessionStore: PreviewSessionStore.signedIn(), onDeleteAccount: {})
	}
}

#Preview("Accessibility text size") {
	NavigationStack {
		ProfilePlaceholderScreen(sessionStore: PreviewSessionStore.signedIn(), onDeleteAccount: {})
	}
	.environment(\.dynamicTypeSize, .accessibility5)
}
