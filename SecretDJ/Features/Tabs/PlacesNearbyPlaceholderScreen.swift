import DesignSystem
import Observability
import SwiftUI

/// The Places Nearby tab's root, until S6.1 lands the real nearby-venues
/// feed (LEGACY.md "Tab 1 — Places Nearby"). Already carries the location
/// flow S6.1 inherits (S5.3): requests when-in-use authorization and a
/// first fix on appearing, re-checks authorization on every foreground
/// (legacy `updateViewForLocationPermission`), and swaps in
/// ``LocationPermissionDeniedView`` for denied/restricted rather than the
/// empty-state placeholder.
struct PlacesNearbyPlaceholderScreen: View {
	let locationService: LocationService

	@Environment(\.scenePhase) private var scenePhase

	var body: some View {
		Group {
			if locationService.authorizationStatus == .denied || locationService.authorizationStatus == .restricted {
				LocationPermissionDeniedView()
			} else {
				EmptyStateView(
					systemImage: Theme.Icon.venue.systemName,
					title: Text("Places Nearby", comment: "Navigation title of the Places Nearby tab."),
					message: Text(
						"We're still finding the venues near you — check back soon.",
						comment: "Body of the Places Nearby tab's placeholder, shown before the real feed exists.",
					),
				)
				.tracksScreen("PlacesNearby")
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(Theme.ColorRole.background.color)
		.navigationTitle(Text("Places Nearby", comment: "Navigation title of the Places Nearby tab."))
		.task {
			locationService.requestAuthorizationIfNeeded()
			locationService.requestLocation()
		}
		.onChange(of: scenePhase) { _, newPhase in
			guard newPhase == .active else { return }

			locationService.refreshAuthorizationStatus()
		}
	}
}

#Preview("Placeholder") {
	NavigationStack {
		PlacesNearbyPlaceholderScreen(locationService: PreviewLocationService.authorized())
	}
}

#Preview("Location denied") {
	NavigationStack {
		PlacesNearbyPlaceholderScreen(locationService: PreviewLocationService.denied())
	}
}

#Preview("Accessibility text size") {
	NavigationStack {
		PlacesNearbyPlaceholderScreen(locationService: PreviewLocationService.authorized())
	}
	.environment(\.dynamicTypeSize, .accessibility5)
}
