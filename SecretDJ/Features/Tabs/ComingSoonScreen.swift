import DesignSystem
import Observability
import SwiftUI

/// A themed stand-in for a destination S6 hasn't built yet
/// (``AppDestination``, PLAN.md S5.2) — pushed by ``TabRouter`` so every
/// navigational feed outcome is exercisable today, even before its real
/// screen exists.
struct ComingSoonScreen: View {
	let destination: AppDestination

	var body: some View {
		EmptyStateView(systemImage: Theme.Icon.emptyState.systemName, title: title, message: message)
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.themedScreen()
			.tracksScreen(destination.screenTrackingName)
	}

	private var title: Text {
		switch destination {
		case .song,
		     .songsForArtist:
			Text("Song", comment: "Title of the coming-soon placeholder shown in place of the song screen.")

		case .venue:
			Text("Venue", comment: "Title of the coming-soon placeholder shown in place of a venue's screen.")

		case .nowPlaying:
			Text(
				"Now Playing",
				comment: "Title of the coming-soon placeholder shown in place of a venue's now-playing screen.",
			)

		case .person:
			Text("Profile", comment: "Title of the coming-soon placeholder shown in place of a person's profile.")

		case .jukebox:
			Text("Jukebox", comment: "Title of the coming-soon placeholder shown in place of a jukebox's song list.")

		case .topUps:
			Text("Top Up", comment: "Title of the coming-soon placeholder shown in place of the credits top-up screen.")

		case .search:
			Text("Search", comment: "Title of the coming-soon placeholder shown in place of the search screen.")

		// Unreachable in practice — TabsView renders the real `SettingsScreen`
		// for `.settings` directly, never falling through to this default
		// case; kept only for this switch's exhaustiveness.
		case .settings:
			Text("Settings", comment: "Title of the coming-soon placeholder shown in place of the Settings screen.")
		}
	}

	private var message: Text {
		Text(
			"We're still building this screen — check back soon.",
			comment: "Body of the coming-soon placeholder shown for any screen not built yet.",
		)
	}
}

#Preview("Venue") {
	NavigationStack {
		ComingSoonScreen(destination: .venue(venueId: "v1"))
	}
}

#Preview("Accessibility text size") {
	NavigationStack {
		ComingSoonScreen(destination: .venue(venueId: "v1"))
	}
	.environment(\.dynamicTypeSize, .accessibility5)
}
