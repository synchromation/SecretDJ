import DesignSystem
import FeedUI
import Observability
import SwiftUI

/// The venue's now-playing/play-history feed (`playhistory`, LEGACY.md
/// "Now Playing / play history"), reached from ``VenueScreen``'s header —
/// S6.2's deliberately smallest reuse of the S6.1 pattern
/// (``PlacesNearbyScreen``): auto-refresh ON, `surfaceChange`, every tap
/// already routed through the same ``FeedUI/FeedActionRouter``/
/// ``AppDestination`` machinery every S6 screen uses. Legacy's richer
/// now-playing header (like toggle, listen-elsewhere actions) depends on
/// the song screen (S6.3) and audio previews (S6.4), so it isn't ported
/// here — the current song still renders, through the ordinary song row.
struct NowPlayingScreen: View {
	let venueId: String
	let router: TabRouter
	let toastQueue: ToastQueue

	@Environment(\.observability) private var observability
	@Environment(\.openURL) private var openURL

	@State private var model: FeedScreenModel

	init(
		venueId: String,
		loader: any FeedLoading,
		locationService: LocationService,
		router: TabRouter,
		toastQueue: ToastQueue,
		installedApps: any InstalledApps = URLSchemeInstalledApps(),
	) {
		self.venueId = venueId
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
		FeedScreen(
			model: model,
			copy: Self.copy,
			onOutcome: handle(outcome:),
			onJukeboxChanged: handleJukeboxChanged,
		)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(Theme.ColorRole.background.color)
		.navigationTitle(Text("Now Playing", comment: "Navigation title of the venue's now-playing screen."))
		.tracksScreen("NowPlaying")
	}

	/// ``HailRideOutcomeHandling`` intercepts a hail-ride hand-off first
	/// (S6.10); every other outcome routes through ``TabRouter`` exactly as
	/// before.
	private func handle(outcome: FeedActionOutcome) {
		guard !HailRideOutcomeHandling.handle(outcome, openURL: openURL, observability: observability) else { return }
		router.handle(outcome: outcome, venueId: venueId)
	}

	private func handleJukeboxChanged() {
		toastQueue.enqueue(ToastItem(message: String(
			localized: "Jukebox Updated",
			comment: "Toast shown when a paginated feed's content changed underneath the user (LEGACY.md's kJukeboxUpdatedText).",
		)))
	}

	private static var copy: FeedScreenCopy {
		FeedScreenCopy(
			emptySystemImage: Theme.Icon.nowPlaying.systemName,
			emptyTitle: Text(
				"Nothing Playing Yet",
				comment: "Title shown on the now-playing feed when nothing has played yet.",
			),
			emptyMessage: Text(
				"Nothing's played at this venue yet — check back soon.",
				comment: "Body shown on the now-playing feed when nothing has played yet.",
			),
			errorTitle: Text(
				"Something Went Wrong",
				comment: "Title shown on the now-playing feed when it fails to load.",
			),
			errorMessage: Text(
				"Sorry, we couldn't load what's playing.\n\nPlease check that you have a good connection to your cellular data or WiFi network.",
				comment: "Body shown on the now-playing feed when it fails to load.",
			),
			offlineTitle: Text(
				"You're Offline",
				comment: "Title shown on the now-playing feed when the device has no internet connection.",
			),
			offlineMessage: Text(
				"Check your connection and try again.",
				comment: "Body shown on the now-playing feed when the device has no internet connection.",
			),
			retryTitle: Text(
				"Try Again",
				comment: "Button that retries loading the now-playing feed after a failure.",
			),
		)
	}
}

#Preview("Loaded") {
	NavigationStack {
		NowPlayingScreen(
			venueId: "v1",
			loader: PreviewNowPlayingLoading.loaded(),
			locationService: PreviewLocationService.authorized(),
			router: TabRouter(),
			toastQueue: ToastQueue(),
		)
	}
}

#Preview("Empty") {
	NavigationStack {
		NowPlayingScreen(
			venueId: "v1",
			loader: PreviewNowPlayingLoading.empty(),
			locationService: PreviewLocationService.authorized(),
			router: TabRouter(),
			toastQueue: ToastQueue(),
		)
	}
}

#Preview("Accessibility text size") {
	NavigationStack {
		NowPlayingScreen(
			venueId: "v1",
			loader: PreviewNowPlayingLoading.loaded(),
			locationService: PreviewLocationService.authorized(),
			router: TabRouter(),
			toastQueue: ToastQueue(),
		)
	}
	.environment(\.dynamicTypeSize, .accessibility5)
}
