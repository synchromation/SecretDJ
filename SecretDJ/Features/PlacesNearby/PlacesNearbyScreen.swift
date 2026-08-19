import DesignSystem
import FeedUI
import Observability
import SecretDJAPI
import SecretDJDomain
import SwiftUI

/// Tab 1 (LEGACY.md "Tab 1 — Places Nearby"): the nearby-venues feed over
/// ``FeedUI/FeedScreen``, auto-refreshing at the legacy cadence
/// (``FeedUI/FeedConfiguration/AutoRefresh``'s default, tightened until the
/// first GPS fix via ``LocationService``'s ``FeedUI/GPSFixAgeProviding``
/// conformance), the permission-denied overlay the placeholder screen
/// already established, and a map bar button
/// (``PlacesNearbyMapConfiguration``) pushing ``VenueMapScreen``. Tap
/// outcomes and the venue map's own annotation taps both route through the
/// same ``TabRouter``. Also hosts the extra-content ticker (PLAN.md S6.9,
/// `screenid` 1) — see ``TickerView``.
struct PlacesNearbyScreen: View {
	let locationService: LocationService
	let router: TabRouter
	let toastQueue: ToastQueue
	/// Jumps to the Activity tab — a person ticker entry's tap destination
	/// (``ExtraContentTapRoute/activity``).
	let onShowActivity: () -> Void

	@Environment(\.scenePhase) private var scenePhase
	@Environment(\.observability) private var observability
	@Environment(\.openURL) private var openURL

	@State private var model: FeedScreenModel
	@State private var extraContentModel: ExtraContentModel
	@State private var isShowingMap = false

	init(
		loader: any FeedLoading,
		locationService: LocationService,
		router: TabRouter,
		toastQueue: ToastQueue,
		extraContentLoading: any ExtraContentLoading,
		onShowActivity: @escaping () -> Void,
		observability: ObservabilityPipeline = .disabled,
		installedApps: any InstalledApps = URLSchemeInstalledApps(),
	) {
		self.locationService = locationService
		self.router = router
		self.toastQueue = toastQueue
		self.onShowActivity = onShowActivity
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
		_extraContentModel = State(initialValue: ExtraContentModel(
			screen: .placesNearby,
			hostVenueId: nil,
			loading: extraContentLoading,
			observability: observability,
		))
	}

	var body: some View {
		ZStack(alignment: .bottom) {
			Group {
				if locationService.authorizationStatus == .denied || locationService
					.authorizationStatus == .restricted
				{
					LocationPermissionDeniedView()
				} else {
					FeedScreen(
						model: model,
						copy: Self.copy,
						onOutcome: handle(outcome:),
						onJukeboxChanged: handleJukeboxChanged,
						onScrollDirectionChange: extraContentModel.handleScrollDirectionChange,
					)
				}
			}

			if let currentEntry = extraContentModel.currentEntry {
				TickerView(entry: currentEntry, isVisible: extraContentModel.isVisible, onTap: handleTickerTap)
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
			FeedActionBarButtons(actions: model.actionButtons, onTap: handleBarButtonTap)
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
		.task {
			await extraContentModel.fetch()
		}
		.onChange(of: scenePhase) { _, newPhase in
			guard newPhase == .active else { return }

			locationService.refreshAuthorizationStatus()
		}
		.onDisappear {
			extraContentModel.stop()
		}
		.tracksScreen("PlacesNearby")
	}

	private func openMap() {
		observability.interaction("openVenueMap")
		isShowingMap = true
	}

	/// Routes the ticker's current entry (``ExtraContentModel/tapCurrentEntry()``)
	/// — a song always resolves to `nil` on this screen (no venue context,
	/// see ``ExtraContentEntry/tapRoute(hostVenueId:)``), so only a person
	/// entry (jump to Activity) is ever reachable here in practice; the
	/// `.nowPlaying` case is still handled for symmetry with ``VenueScreen``.
	private func handleTickerTap() {
		switch extraContentModel.tapCurrentEntry() {
		case .nowPlaying(let venueId):
			router.push(.nowPlaying(venueId: venueId))

		case .activity:
			onShowActivity()

		case nil:
			break
		}
	}

	/// ``HailRideOutcomeHandling`` intercepts a hail-ride hand-off first
	/// (S6.10); every other outcome routes through ``TabRouter`` exactly as
	/// before.
	private func handle(outcome: FeedActionOutcome) {
		guard !HailRideOutcomeHandling.handle(outcome, openURL: openURL, observability: observability) else { return }
		router.handle(outcome: outcome)
	}

	/// A server-driven nav-bar action button tap (S6.12) — routed through
	/// the same ``FeedUI/FeedActionRouter`` mapping and ``handle(outcome:)``
	/// every cell tap already uses, so hail-taxi's breadcrumb and every
	/// other outcome-specific side effect apply unchanged.
	private func handleBarButtonTap(_ action: Action) {
		guard let outcome = model.outcome(forBarButton: action) else { return }
		handle(outcome: outcome)
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
			extraContentLoading: InMemoryExtraContentLoading(),
			onShowActivity: {},
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
			extraContentLoading: InMemoryExtraContentLoading(),
			onShowActivity: {},
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
			extraContentLoading: InMemoryExtraContentLoading(),
			onShowActivity: {},
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
			extraContentLoading: InMemoryExtraContentLoading(),
			onShowActivity: {},
		)
	}
	.environment(\.dynamicTypeSize, .accessibility5)
}
