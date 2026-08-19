import DesignSystem
import FeedUI
import Observability
import SecretDJAPI
import SecretDJDomain
import SharedFeatures
import SwiftUI

/// The signed-in app's real shell (PLAN.md S5.2): three tabs — Places
/// Nearby, Activity, Profile — each with its own `NavigationStack` driven by
/// a ``TabRouter`` (LEGACY.md "Launch and root navigation"). Places Nearby
/// hosts its real feed as of S6.1, Activity as of S6.5, and any tab's stack
/// can push a real ``VenueScreen``/``NowPlayingScreen`` as of S6.2; Profile
/// still hosts a themed placeholder root pending S6.6. Also composes the
/// shell-wide ``DesignSystem/ToastQueue`` every S6 feed screen's
/// jukebox-changed toast (and later, other server-driven toasts) presents
/// through.
struct TabsView: View {
	let sessionStore: SessionStore
	let apiClient: APIClient
	let locationService: LocationService
	/// Starts the ``AccountFlowView`` delete-account flow, forwarded to the
	/// Profile tab — owned by `RootView`, see its doc comment for why.
	let onDeleteAccount: () -> Void

	@State private var model: TabsModel
	/// Composed here, at the shell's root, so a toast raised by any tab's
	/// screen (S6.1's jukebox-changed toast, and every S6 screen after it)
	/// presents above the tab bar rather than getting clipped to one tab's
	/// own stack.
	@State private var toastQueue = ToastQueue()

	init(
		sessionStore: SessionStore,
		apiClient: APIClient,
		locationService: LocationService,
		onDeleteAccount: @escaping () -> Void,
		observability: ObservabilityPipeline = .disabled,
	) {
		self.sessionStore = sessionStore
		self.apiClient = apiClient
		self.locationService = locationService
		self.onDeleteAccount = onDeleteAccount
		_model = State(initialValue: TabsModel(observability: observability))
	}

	var body: some View {
		TabView(selection: selectedTab) {
			Tab("Places Nearby", systemImage: Theme.Icon.venue.systemName, value: AppTab.placesNearby) {
				tabStack(for: .placesNearby) { router in
					PlacesNearbyScreen(
						loader: APIClientFeedLoading.sessionFeed(
							sessionStore: sessionStore,
							locationService: locationService,
							endpoint: { userId, credential, _ in try await apiClient.placesNearby(
								userId: userId,
								credential: credential,
							) },
						),
						locationService: locationService,
						router: router,
						toastQueue: toastQueue,
					)
				}
			}

			Tab("Activity", systemImage: Theme.Icon.activity.systemName, value: AppTab.activity) {
				tabStack(for: .activity) { router in
					ActivityScreen(
						loader: APIClientFeedLoading.sessionFeed(
							sessionStore: sessionStore,
							locationService: locationService,
							endpoint: { userId, credential, _ in try await apiClient.activity(
								userId: userId,
								credential: credential,
							) },
						),
						locationService: locationService,
						router: router,
						toastQueue: toastQueue,
					)
				}
			}

			Tab("Profile", systemImage: Theme.Icon.profile.systemName, value: AppTab.profile) {
				tabStack(for: .profile) { _ in
					ProfilePlaceholderScreen(sessionStore: sessionStore, onDeleteAccount: onDeleteAccount)
				}
			}
		}
		.toastPresenter(queue: toastQueue)
	}

	private var selectedTab: Binding<AppTab> {
		Binding(get: { model.selectedTab }, set: { model.show(tab: $0) })
	}

	/// Wraps `root` in `tab`'s own `NavigationStack`, bound to its
	/// ``TabRouter``'s path — so a destination the router pushes (a routed
	/// ``FeedActionOutcome``, once S6 wires a real feed screen's taps into
	/// it) navigates within that tab alone, and the back button/swipe-back
	/// pop mirrors straight back into the router. `root` receives that same
	/// router, for a screen (Places Nearby, from S6.1 on) that routes its
	/// own feed taps or a nested screen's taps (the venue map's annotations)
	/// through it directly.
	private func tabStack(for tab: AppTab, @ViewBuilder root: (TabRouter) -> some View) -> some View {
		let router = model.router(for: tab)

		return NavigationStack(path: path(for: router)) {
			root(router)
				.navigationDestination(for: AppDestination.self) { destination in
					self.destination(for: destination, router: router)
				}
		}
	}

	/// Every ``AppDestination`` case S6 has a real screen for; everything
	/// else still falls through to ``ComingSoonScreen`` (PLAN.md S5.2's
	/// exercisable-before-built navigation model).
	@ViewBuilder
	private func destination(for destination: AppDestination, router: TabRouter) -> some View {
		switch destination {
		case .venue(let venueId):
			venueScreen(venueId: venueId, router: router)

		case .nowPlaying(let venueId):
			nowPlayingScreen(venueId: venueId, router: router)

		case .jukebox(let venueId, let jukeboxId):
			musicSelectionScreen(venueId: venueId, jukeboxId: jukeboxId, router: router)

		case .search(let venueId):
			MusicSearchScreen(
				searching: APIClientMusicSearching(client: apiClient, sessionStore: sessionStore, venueId: venueId),
				copy: Self.musicSearchCopy,
				onOutcome: { router.handle(outcome: $0, venueId: venueId) },
			)

		case .songsForArtist(let venueId, let artist):
			SongsForArtistScreen(
				artistName: artist,
				searching: APIClientMusicSearching(client: apiClient, sessionStore: sessionStore, venueId: venueId),
				copy: Self.songsForArtistCopy,
				onOutcome: { router.handle(outcome: $0, venueId: venueId) },
			)

		default:
			ComingSoonScreen(destination: destination)
		}
	}

	private func venueScreen(venueId: String, router: TabRouter) -> some View {
		VenueScreen(
			venueId: venueId,
			loader: APIClientFeedLoading.sessionFeed(
				sessionStore: sessionStore,
				locationService: locationService,
				endpoint: { userId, credential, _ in try await apiClient.venue(
					userId: userId,
					venueId: venueId,
					credential: credential,
				) },
			),
			locationService: locationService,
			router: router,
			toastQueue: toastQueue,
			likeToggling: APIClientLikeToggling(client: apiClient, sessionStore: sessionStore),
			promotionEngaging: APIClientPromotionEngaging(client: apiClient, sessionStore: sessionStore),
		)
	}

	private func nowPlayingScreen(venueId: String, router: TabRouter) -> some View {
		NowPlayingScreen(
			venueId: venueId,
			loader: APIClientFeedLoading.sessionFeed(
				sessionStore: sessionStore,
				locationService: locationService,
				endpoint: { userId, credential, _ in try await apiClient.nowPlaying(
					userId: userId,
					venueId: venueId,
					credential: credential,
				) },
			),
			locationService: locationService,
			router: router,
			toastQueue: toastQueue,
		)
	}

	private func musicSelectionScreen(venueId: String, jukeboxId: Int, router: TabRouter) -> some View {
		MusicSelectionScreen(
			venueId: venueId,
			loader: APIClientFeedLoading.sessionFeed(
				sessionStore: sessionStore,
				locationService: locationService,
				endpoint: { userId, credential, page in try await apiClient.musicSelection(
					userId: userId,
					venueId: venueId,
					offset: (page ?? 0) * Self.musicSelectionBatchSize,
					batchSize: Self.musicSelectionBatchSize,
					item: jukeboxId,
					type: Int64(ItemType.song.rawValue),
					hash: nil,
					credential: credential,
				) },
			),
			atmosphereChanging: APIClientAtmosphereChanging(client: apiClient, sessionStore: sessionStore),
			toastQueue: toastQueue,
			copy: Self.musicSelectionCopy,
			onOutcome: { router.handle(outcome: $0, venueId: venueId) },
			onJukeboxChanged: { toastQueue.enqueue(ToastItem(message: Self.jukeboxChangedMessage)) },
		)
	}

	/// The legacy 50-song page size for `musicselection`/`musicdigest`
	/// (LEGACY.md "Choosing music": "hash-checked pagination in 50-song
	/// batches with server-adjustable batch size" — kept as a fixed client
	/// default since the server-adjustable half of that isn't modeled yet).
	private static let musicSelectionBatchSize = 50

	private func path(for router: TabRouter) -> Binding<[AppDestination]> {
		Binding(get: { router.path }, set: { router.setPath($0) })
	}

	/// Reused verbatim from ``VenueScreen``/``NowPlayingScreen``'s own
	/// jukebox-changed toast — the same String Catalog key, not a second one
	/// (LEGACY.md's `kJukeboxUpdatedText`).
	private static var jukeboxChangedMessage: String {
		String(
			localized: "Jukebox Updated",
			comment: "Toast shown when a paginated feed's content changed underneath the user (LEGACY.md's kJukeboxUpdatedText).",
		)
	}

	private static var musicSelectionCopy: FeedScreenCopy {
		FeedScreenCopy(
			emptySystemImage: Theme.Icon.jukebox.systemName,
			emptyTitle: Text(
				"Nothing Here Yet",
				comment: "Title shown on a jukebox's song list when it has no content yet.",
			),
			emptyMessage: Text(
				"This jukebox hasn't got anything to show yet — check back soon.",
				comment: "Body shown on a jukebox's song list when it has no content yet.",
			),
			errorTitle: Text(
				"Something Went Wrong",
				comment: "Title shown on a jukebox's song list when it fails to load.",
			),
			errorMessage: Text(
				"Sorry, we couldn't load this jukebox.\n\nPlease check that you have a good connection to your cellular data or WiFi network.",
				comment: "Body shown on a jukebox's song list when it fails to load.",
			),
			offlineTitle: Text(
				"You're Offline",
				comment: "Title shown on a jukebox's song list when the device has no internet connection.",
			),
			offlineMessage: Text(
				"Check your connection and try again.",
				comment: "Body shown on a jukebox's song list when the device has no internet connection.",
			),
			retryTitle: Text(
				"Try Again",
				comment: "Button that retries loading a jukebox's song list after a failure.",
			),
		)
	}

	private static var musicSearchCopy: MusicSearchScreenCopy {
		MusicSearchScreenCopy(
			navigationTitle: Text("Search", comment: "Navigation title of the artist/song search screen."),
			artistModeLabel: Text("Artists", comment: "Search screen tab that searches by artist name."),
			trackModeLabel: Text("Songs", comment: "Search screen tab that searches by song title."),
			searchFieldPlaceholder: Text(
				"Search",
				comment: "Placeholder text in the search screen's text field, before the user types anything.",
			),
			emptyTitle: Text("No Results", comment: "Title shown on the search screen when a search finds nothing."),
			emptyMessage: Text(
				"Try a different search.",
				comment: "Body shown on the search screen when a search finds nothing.",
			),
			errorTitle: Text("Something Went Wrong", comment: "Title shown on the search screen when a search fails."),
			errorMessage: Text(
				"Sorry, we couldn't search right now.\n\nPlease check that you have a good connection to your cellular data or WiFi network.",
				comment: "Body shown on the search screen when a search fails.",
			),
			retryTitle: Text("Try Again", comment: "Button that retries a failed search."),
		)
	}

	private static var songsForArtistCopy: FeedScreenCopy {
		FeedScreenCopy(
			emptySystemImage: Theme.Icon.song.systemName,
			emptyTitle: Text(
				"No Songs",
				comment: "Title shown on an artist's song list when they have no songs here yet.",
			),
			emptyMessage: Text(
				"This artist hasn't got anything to show yet — check back soon.",
				comment: "Body shown on an artist's song list when they have no songs here yet.",
			),
			errorTitle: Text(
				"Something Went Wrong",
				comment: "Title shown on an artist's song list when it fails to load.",
			),
			errorMessage: Text(
				"Sorry, we couldn't load these songs.\n\nPlease check that you have a good connection to your cellular data or WiFi network.",
				comment: "Body shown on an artist's song list when it fails to load.",
			),
			offlineTitle: Text(
				"You're Offline",
				comment: "Title shown on an artist's song list when the device has no internet connection.",
			),
			offlineMessage: Text(
				"Check your connection and try again.",
				comment: "Body shown on an artist's song list when the device has no internet connection.",
			),
			retryTitle: Text(
				"Try Again",
				comment: "Button that retries loading an artist's song list after a failure.",
			),
		)
	}
}

#Preview("Signed in") {
	TabsView(
		sessionStore: PreviewSessionStore.signedIn(),
		apiClient: PreviewAPIClient.broken(),
		locationService: PreviewLocationService.authorized(),
		onDeleteAccount: {},
	)
}

#Preview("Accessibility text size") {
	TabsView(
		sessionStore: PreviewSessionStore.signedIn(),
		apiClient: PreviewAPIClient.broken(),
		locationService: PreviewLocationService.authorized(),
		onDeleteAccount: {},
	)
	.environment(\.dynamicTypeSize, .accessibility5)
}
