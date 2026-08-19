import DesignSystem
import Observability
import SwiftUI

/// The Activity tab's root, until S6.5 lands the real event-history feed
/// (LEGACY.md "Tab 2 — Activity feed" — check-ins, requests, awards, people).
struct ActivityPlaceholderScreen: View {
	var body: some View {
		EmptyStateView(
			systemImage: Theme.Icon.activity.systemName,
			title: Text("Activity", comment: "Navigation title of the Activity tab."),
			message: Text(
				"Check-ins, requests, and awards will show up here — check back soon.",
				comment: "Body of the Activity tab's placeholder, shown before the real feed exists.",
			),
		)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(Theme.ColorRole.background.color)
		.navigationTitle(Text("Activity", comment: "Navigation title of the Activity tab."))
		.tracksScreen("Activity")
	}
}

#Preview("Placeholder") {
	NavigationStack {
		ActivityPlaceholderScreen()
	}
}

#Preview("Accessibility text size") {
	NavigationStack {
		ActivityPlaceholderScreen()
	}
	.environment(\.dynamicTypeSize, .accessibility5)
}
