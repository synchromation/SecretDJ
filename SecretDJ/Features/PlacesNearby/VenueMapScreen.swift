import DesignSystem
import FeedUI
import MapKit
import Observability
import SwiftUI

/// The map behind Places Nearby's map bar button (LEGACY.md "Gaps and
/// cross-checks" — `VenueMapViewController`): a pin per venue from
/// ``VenueMapScreenModel``, a distinct pin for a venue with a jukebox, the
/// user's own location, and a camera fitted to every pin. An annotation tap
/// routes through the same ``TabRouter`` a feed row tap does — reusing
/// ``FeedActionOutcome/showVenue(venueId:)`` rather than inventing a second
/// navigation path for "go to this venue".
struct VenueMapScreen: View {
	let model: VenueMapScreenModel
	let locationService: LocationService
	let router: TabRouter

	@Environment(\.observability) private var observability

	@State private var cameraPosition: MapCameraPosition

	init(model: VenueMapScreenModel, locationService: LocationService, router: TabRouter) {
		self.model = model
		self.locationService = locationService
		self.router = router
		_cameraPosition = State(initialValue: model.fitRegion.map(MapCameraPosition.region) ?? .automatic)
	}

	var body: some View {
		content
			.navigationTitle(Text("Map", comment: "Navigation title of the Places Nearby venue map."))
			.tracksScreen("VenueMap")
	}

	@ViewBuilder
	private var content: some View {
		// Mirrors the tab's own gate (LocationPermissionDeniedView's doc
		// comment already anticipates this screen): a map's entire point is
		// showing where things are, so there's nothing useful to show
		// without location access either.
		if locationService.authorizationStatus == .denied || locationService.authorizationStatus == .restricted {
			LocationPermissionDeniedView()
		} else if model.annotations.isEmpty {
			EmptyStateView(
				systemImage: Theme.Icon.emptyState.systemName,
				title: Text(
					"No Venues to Show",
					comment: "Title shown on the venue map when there are no nearby venues to plot.",
				),
				message: Text(
					"We couldn't find any venues to show on the map right now.",
					comment: "Body shown on the venue map when there are no nearby venues to plot.",
				),
			)
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.themedScreen()
		} else {
			Map(position: $cameraPosition) {
				UserAnnotation()

				ForEach(model.annotations) { annotation in
					Annotation(annotation.title, coordinate: annotation.coordinate) {
						VenueMapPinButton(annotation: annotation, onSelect: { select(annotation) })
					}
					.annotationTitles(.hidden)
				}
			}
		}
	}

	private func select(_ annotation: VenueMapAnnotation) {
		observability.interaction("selectVenueMapPin")
		router.handle(outcome: .showVenue(venueId: annotation.venueId))
	}
}

/// One pin's tappable content — a separate view since it takes parameters
/// (swiftui-views).
private struct VenueMapPinButton: View {
	let annotation: VenueMapAnnotation
	let onSelect: () -> Void

	var body: some View {
		Button(action: onSelect) {
			Image(systemName: annotation.hasJukebox ? Theme.Icon.jukebox.systemName : Theme.Icon.venue.systemName)
				.font(.title3)
				.foregroundStyle(.white)
				.frame(minWidth: 44, minHeight: 44)
				.background(
					annotation.hasJukebox ? Theme.ColorRole.accent.color : Theme.ColorRole.secondaryText.color,
					in: Circle(),
				)
		}
		// A server-supplied venue name is never a String Catalog key
		// (lazy-sections' server-text rule) — `verbatim` keeps it out of
		// the catalog while still giving VoiceOver the real name.
		.accessibilityLabel(Text(verbatim: annotation.title))
		.accessibilityValue(
			annotation.hasJukebox
				? Text(
					"Has a jukebox",
					comment: "Accessibility value read for a Places Nearby map pin at a venue with a jukebox.",
				)
				: Text(verbatim: ""),
		)
	}
}

#Preview("Venues") {
	NavigationStack {
		VenueMapScreen(
			model: PreviewVenueMapScreenModel.sample(),
			locationService: PreviewLocationService.authorized(),
			router: TabRouter(),
		)
	}
}

#Preview("No venues") {
	NavigationStack {
		VenueMapScreen(
			model: VenueMapScreenModel(sections: []),
			locationService: PreviewLocationService.authorized(),
			router: TabRouter(),
		)
	}
}

#Preview("Location denied") {
	NavigationStack {
		VenueMapScreen(
			model: PreviewVenueMapScreenModel.sample(),
			locationService: PreviewLocationService.denied(),
			router: TabRouter(),
		)
	}
}

#Preview("Accessibility text size") {
	NavigationStack {
		VenueMapScreen(
			model: PreviewVenueMapScreenModel.sample(),
			locationService: PreviewLocationService.authorized(),
			router: TabRouter(),
		)
	}
	.environment(\.dynamicTypeSize, .accessibility5)
}
