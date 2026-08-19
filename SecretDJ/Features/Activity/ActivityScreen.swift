import DesignSystem
import FeedUI
import Observability
import SecretDJDomain
import SwiftUI

/// Tab 2 (LEGACY.md "Tab 2 — Activity feed"): the "rabbit feed" of
/// check-ins, requests, awards, and people over ``FeedUI/FeedScreen`` —
/// S6.5's deliberately smallest reuse of the S6.1 pattern
/// (``PlacesNearbyScreen``). `ActivityFeedDataProvider` auto-refreshes but
/// never overrides `fetchNextFeedPage`, so it inherits
/// `FeedDataProvider`'s no-content default (`secretdjv3/FeedDataProvider.swift`)
/// — no pagination, matching Places Nearby. Every content kind already
/// renders through the S3.2 cell library
/// (``FeedUI/FeedCellProps``'s `.person`/`.event` mapping) with no
/// screen-level work needed, and every tap already routes through the same
/// ``FeedUI/FeedActionRouter``/``AppDestination`` machinery Places Nearby
/// uses (person → ``AppDestination/person(personId:)``, venue-shaped
/// award/check-in rows → ``AppDestination/venue(venueId:)``).
struct ActivityScreen: View {
	let router: TabRouter
	let toastQueue: ToastQueue

	@Environment(\.observability) private var observability
	@Environment(\.openURL) private var openURL

	@State private var model: FeedScreenModel

	init(
		loader: any FeedLoading,
		locationService: LocationService,
		router: TabRouter,
		toastQueue: ToastQueue,
		installedApps: any InstalledApps = URLSchemeInstalledApps(),
	) {
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
			// Every legacy auto-refreshing feed screen tightens its cadence
			// until the app's first GPS fix, not just the screens that use
			// location for their own content (bug #181 — the doc comment on
			// `APIClientFeedLoading.sessionFeed` explains the same
			// "every fetch requests a location regardless" rule).
			gpsFixAge: locationService,
		))
	}

	var body: some View {
		FeedScreen(
			model: model,
			copy: Self.copy,
			onOutcome: handle(outcome:),
			onJukeboxChanged: handleJukeboxChanged,
		)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(Theme.ColorRole.background.color)
		.navigationTitle(Text("Activity", comment: "Navigation title of the Activity tab."))
		.toolbar {
			FeedActionBarButtons(actions: model.actionButtons, onTap: handleBarButtonTap)
		}
		.tracksScreen("Activity")
	}

	/// ``HailRideOutcomeHandling`` intercepts a hail-ride hand-off first
	/// (S6.10); every other outcome routes through ``TabRouter`` exactly as
	/// before.
	private func handle(outcome: FeedActionOutcome) {
		guard !HailRideOutcomeHandling.handle(outcome, openURL: openURL, observability: observability) else { return }
		router.handle(outcome: outcome)
	}

	/// A server-driven nav-bar action button tap (S6.12) — routed through
	/// this screen's own ``handle(outcome:)`` exactly like a cell tap.
	private func handleBarButtonTap(_ action: Action) {
		guard let outcome = model.outcome(forBarButton: action) else { return }
		handle(outcome: outcome)
	}

	/// The legacy "jukebox changed" toast (`kJukeboxUpdatedText`), inherited
	/// from the shell's shared ``DesignSystem/ToastQueue`` exactly as
	/// ``PlacesNearbyScreen`` wires it — purely client-side copy, so it goes
	/// through `String(localized:)` rather than a server string
	/// (``DesignSystem/ToastItem/message``'s doc comment). Pagination is
	/// disabled here, so this event never actually fires in practice; kept
	/// wired for parity with every other S6 feed screen and in case that
	/// changes.
	private func handleJukeboxChanged() {
		toastQueue.enqueue(ToastItem(message: String(
			localized: "Jukebox Updated",
			comment: "Toast shown when a paginated feed's content changed underneath the user (LEGACY.md's kJukeboxUpdatedText).",
		)))
	}

	private static var copy: FeedScreenCopy {
		FeedScreenCopy(
			emptySystemImage: Theme.Icon.activity.systemName,
			emptyTitle: Text(
				"No Activity Yet",
				comment: "Title shown on the Activity feed when there's no activity yet.",
			),
			emptyMessage: Text(
				"Your check-ins, requests, and awards will show up here as they happen.",
				comment: "Body shown on the Activity feed when there's no activity yet.",
			),
			errorTitle: Text(
				"Something Went Wrong",
				comment: "Title shown on the Activity feed when it fails to load.",
			),
			errorMessage: Text(
				"Sorry, we couldn't load your activity.\n\nPlease check that you have a good connection to your cellular data or WiFi network.",
				comment: "Body shown on the Activity feed when it fails to load.",
			),
			offlineTitle: Text(
				"You're Offline",
				comment: "Title shown on the Activity feed when the device has no internet connection.",
			),
			offlineMessage: Text(
				"Check your connection and try again.",
				comment: "Body shown on the Activity feed when the device has no internet connection.",
			),
			retryTitle: Text(
				"Try Again",
				comment: "Button that retries loading the Activity feed after a failure.",
			),
		)
	}
}

#Preview("Loaded") {
	NavigationStack {
		ActivityScreen(
			loader: PreviewActivityLoading.loaded(),
			locationService: PreviewLocationService.authorized(),
			router: TabRouter(),
			toastQueue: ToastQueue(),
		)
	}
}

#Preview("Empty") {
	NavigationStack {
		ActivityScreen(
			loader: PreviewActivityLoading.empty(),
			locationService: PreviewLocationService.authorized(),
			router: TabRouter(),
			toastQueue: ToastQueue(),
		)
	}
}

#Preview("Accessibility text size") {
	NavigationStack {
		ActivityScreen(
			loader: PreviewActivityLoading.loaded(),
			locationService: PreviewLocationService.authorized(),
			router: TabRouter(),
			toastQueue: ToastQueue(),
		)
	}
	.environment(\.dynamicTypeSize, .accessibility5)
}
