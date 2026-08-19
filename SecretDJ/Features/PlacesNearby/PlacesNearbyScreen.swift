import DesignSystem
import FeedUI
import Observability
import SwiftUI

/// Tab 1 (LEGACY.md "Tab 1 — Places Nearby"): the nearby-venues feed over
/// ``FeedUI/FeedScreen``, auto-refreshing at the legacy cadence
/// (``FeedUI/FeedConfiguration/AutoRefresh``'s default, tightened until the
/// first GPS fix via ``LocationService``'s ``FeedUI/GPSFixAgeProviding``
/// conformance), the permission-denied overlay the placeholder screen
/// already established, and a map bar button
/// (``PlacesNearbyMapConfiguration``) pushing ``VenueMapScreen``. Tap
/// outcomes and the venue map's own annotation taps both route through the
/// same ``TabRouter``.
struct PlacesNearbyScreen: View {
	let locationService: LocationService
	let router: TabRouter
	let toastQueue: ToastQueue

	@Environment(\.scenePhase) private var scenePhase
	@Environment(\.observability) private var observability

	@State private var model: FeedScreenModel
	@State private var isShowingMap = false

	init(
		loader: any FeedLoading,
		locationService: LocationService,
		router: TabRouter,
		toastQueue: ToastQueue,
		installedApps: any InstalledApps = URLSchemeInstalledApps(),
	) {
		self.locationService = locationService
		self.router = router
		self.toastQueue = toastQueue
		_model = State(initialValue: FeedScreenModel(
			loader: loader,
			router: FeedActionRouter(installedApps: installedApps),
			configuration: FeedConfiguration(
				autoRefresh: FeedConfiguration.AutoRefresh(),
				paginationEnabled: false,
				changePolicy: .surfaceChange,
			),
			gpsFixAge: locationService,
		))
	}

	var body: some View {
		Group {
			if locationService.authorizationStatus == .denied || locationService.authorizationStatus == .restricted {
				LocationPermissionDeniedView()
			} else {
				FeedScreen(
					model: model,
					copy: Self.copy,
					onOutcome: router.handle(outcome:),
					onJukeboxChanged: handleJukeboxChanged,
				)
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(Theme.ColorRole.background.color)
		.navigationTitle(Text("Places Nearby", comment: "Navigation title of the Places Nearby tab."))
		.toolbar {
			if PlacesNearbyMapConfiguration.isMapEnabled {
				ToolbarItem(placement: .topBarTrailing) {
					Button("Map", systemImage: Theme.Icon.map.systemName, action: openMap)
				}
			}
		}
		.navigationDestination(isPresented: $isShowingMap) {
			VenueMapScreen(
				model: VenueMapScreenModel(sections: model.visibleSections),
				locationService: locationService,
				router: router,
			)
		}
		.task {
			locationService.requestAuthorizationIfNeeded()
			locationService.requestLocation()
		}
		.onChange(of: scenePhase) { _, newPhase in
			guard newPhase == .active else { return }

			locationService.refreshAuthorizationStatus()
		}
		.tracksScreen("PlacesNearby")
	}

	private func openMap() {
		observability.interaction("openVenueMap")
		isShowingMap = true
	}

	/// The legacy "jukebox changed" toast (`kJukeboxUpdatedText`) — purely
	/// client-side copy, not server-delivered, so it goes through
	/// `String(localized:)` rather than a server string
	/// (``DesignSystem/ToastItem/message``'s doc comment).
	private func handleJukeboxChanged() {
		toastQueue.enqueue(ToastItem(message: String(
			localized: "Jukebox Updated",
			comment: "Toast shown when a paginated feed's content changed underneath the user (LEGACY.md's kJukeboxUpdatedText).",
		)))
	}

	private static var copy: FeedScreenCopy {
		FeedScreenCopy(
			emptySystemImage: Theme.Icon.emptyState.systemName,
			emptyTitle: Text(
				"No Venues Nearby",
				comment: "Title shown on the Places Nearby feed when no venues are nearby.",
			),
			emptyMessage: Text(
				"We couldn't find any Secret DJ venues near you right now — check back soon.",
				comment: "Body shown on the Places Nearby feed when no venues are nearby.",
			),
			errorTitle: Text(
				"Something Went Wrong",
				comment: "Title shown on the Places Nearby feed when it fails to load.",
			),
			errorMessage: Text(
				"Sorry, we couldn't load the venues near you.\n\nPlease check that you have a good connection to your cellular data or WiFi network.",
				comment: "Body shown on the Places Nearby feed when it fails to load.",
			),
			offlineTitle: Text(
				"You're Offline",
				comment: "Title shown on the Places Nearby feed when the device has no internet connection.",
			),
			offlineMessage: Text(
				"Check your connection and try again.",
				comment: "Body shown on the Places Nearby feed when the device has no internet connection.",
			),
			retryTitle: Text(
				"Try Again",
				comment: "Button that retries loading the Places Nearby feed after a failure.",
			),
		)
	}
}

#Preview("Loaded") {
	NavigationStack {
		PlacesNearbyScreen(
			loader: PreviewPlacesNearbyLoading.loaded(),
			locationService: PreviewLocationService.authorized(),
			router: TabRouter(),
			toastQueue: ToastQueue(),
		)
	}
}

#Preview("Empty") {
	NavigationStack {
		PlacesNearbyScreen(
			loader: PreviewPlacesNearbyLoading.empty(),
			locationService: PreviewLocationService.authorized(),
			router: TabRouter(),
			toastQueue: ToastQueue(),
		)
	}
}

#Preview("Location denied") {
	NavigationStack {
		PlacesNearbyScreen(
			loader: PreviewPlacesNearbyLoading.loaded(),
			locationService: PreviewLocationService.denied(),
			router: TabRouter(),
			toastQueue: ToastQueue(),
		)
	}
}

#Preview("Accessibility text size") {
	NavigationStack {
		PlacesNearbyScreen(
			loader: PreviewPlacesNearbyLoading.loaded(),
			locationService: PreviewLocationService.authorized(),
			router: TabRouter(),
			toastQueue: ToastQueue(),
		)
	}
	.environment(\.dynamicTypeSize, .accessibility5)
}
