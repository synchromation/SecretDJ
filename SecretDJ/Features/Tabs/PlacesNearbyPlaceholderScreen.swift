import DesignSystem
import Observability
import SwiftUI

/// The Places Nearby tab's root, until S6.1 lands the real nearby-venues
/// feed (LEGACY.md "Tab 1 — Places Nearby").
struct PlacesNearbyPlaceholderScreen: View {
	var body: some View {
		EmptyStateView(
			systemImage: Theme.Icon.venue.systemName,
			title: Text("Places Nearby", comment: "Navigation title of the Places Nearby tab."),
			message: Text(
				"We're still finding the venues near you — check back soon.",
				comment: "Body of the Places Nearby tab's placeholder, shown before the real feed exists.",
			),
		)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(Theme.ColorRole.background.color)
		.navigationTitle(Text("Places Nearby", comment: "Navigation title of the Places Nearby tab."))
		.tracksScreen("PlacesNearby")
	}
}

#Preview("Placeholder") {
	NavigationStack {
		PlacesNearbyPlaceholderScreen()
	}
}

#Preview("Accessibility text size") {
	NavigationStack {
		PlacesNearbyPlaceholderScreen()
	}
	.environment(\.dynamicTypeSize, .accessibility5)
}
