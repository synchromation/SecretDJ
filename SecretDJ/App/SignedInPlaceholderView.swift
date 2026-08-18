import DesignSystem
import Observability
import SecretDJAPI
import SwiftUI

/// A themed placeholder for the signed-in state: the session's screen name
/// plus a way to sign out. S5 replaces this with the real three-tab shell.
struct SignedInPlaceholderView: View {
	let sessionStore: SessionStore

	@Environment(\.observability) private var observability

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
				observability.interaction("signOut")
				sessionStore.signOut()
			}
			.buttonStyle(.secondary)
		}
		.padding(Spacing.large)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(Theme.ColorRole.background.color)
		.tracksScreen("SignedInPlaceholder")
	}
}

#Preview("Signed in") {
	SignedInPlaceholderView(sessionStore: {
		let store = SessionStore(
			snapshotStore: InMemorySessionSnapshotStore(),
			credentialStore: InMemoryCredentialStore(),
		)
		store.signIn(
			user: SessionUser(personId: "41", screenName: "TurboTim"),
			venue: nil,
			credential: APICredential(token: "tok", passwordHash: "hash"),
		)
		return store
	}())
}

#Preview("Accessibility text size") {
	SignedInPlaceholderView(sessionStore: {
		let store = SessionStore(
			snapshotStore: InMemorySessionSnapshotStore(),
			credentialStore: InMemoryCredentialStore(),
		)
		store.signIn(
			user: SessionUser(personId: "41", screenName: "TurboTim"),
			venue: nil,
			credential: APICredential(token: "tok", passwordHash: "hash"),
		)
		return store
	}())
		.environment(\.dynamicTypeSize, .accessibility5)
}
