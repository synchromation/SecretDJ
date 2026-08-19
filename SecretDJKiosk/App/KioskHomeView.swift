import DesignSystem
import Observability
import SecretDJAPI
import SwiftUI

/// The kiosk's signed-in home screen — a placeholder ``KioskRootView``
/// shows once a venue has signed in, standing in until S7.2 (skin), S7.3
/// (attract/idle), S7.4 (now playing + jukebox digest), and S7.5
/// (controls) replace it feature by feature (PLAN.md S7.1's scope is only
/// the shell). Confirms sign-in worked by naming the venue.
struct KioskHomeView: View {
	let sessionStore: SessionStore

	var body: some View {
		VStack(spacing: Spacing.large) {
			Text("Welcome", comment: "Placeholder kiosk home screen heading, shown once a venue has signed in.")
				.font(Theme.TextStyle.screenTitle.font)
				.foregroundStyle(Theme.ColorRole.primaryText.color)
				.accessibilityAddTraits(.isHeader)

			if let venue = sessionStore.venue {
				// The venue's display name isn't known at sign-in time yet
				// (SessionStore+KioskAuthenticatedSession's doc comment) — this
				// shows the id, honestly, rather than a name it doesn't have;
				// S7.4's kiosk feeds resolve the real one.
				Text(venue.name)
					.font(Theme.TextStyle.sectionHeader.font)
					.foregroundStyle(Theme.ColorRole.secondaryText.color)
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(Theme.ColorRole.background.color)
		.tracksScreen("KioskHome")
	}
}

#Preview("Signed in") {
	KioskHomeView(sessionStore: PreviewKioskSessionStore.signedIn())
}

#Preview("Accessibility text size") {
	KioskHomeView(sessionStore: PreviewKioskSessionStore.signedIn())
		.environment(\.dynamicTypeSize, .accessibility5)
}
