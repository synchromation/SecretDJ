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
/// hosts its real feed as of S6.1, Activity as of S6.5, Profile as of S6.6
/// (its tab root is the signed-in user's own profile, ``profileScreen(personId:router:onDeleteAccount:)``
/// resolving the session's own id), and any tab's stack can push a real
/// ``VenueScreen``/``NowPlayingScreen``/``ProfileScreen`` as of S6.2/S6.6.
/// Also composes the shell-wide ``DesignSystem/ToastQueue`` every S6 feed
/// screen's jukebox-changed toast (and later, other server-driven toasts)
/// presents through.
struct TabsView: View {
	let sessionStore: SessionStore
	let apiClient: APIClient
	let locationService: LocationService
	/// The app-wide shared song-preview player (S6.4), threaded from the
	/// composition root down to whichever `TuneInDestinationScreen` a tab's
	/// stack pushes — see `SecretDJApp`'s own doc comment on why exactly one
	/// instance exists.
	let previewPlayerModel: PreviewPlayerModel
	/// Starts the ``AccountFlowView`` delete-account flow, forwarded to the
	/// Profile tab — owned by `RootView`, see its doc comment for why.
	let onDeleteAccount: () -> Void
	/// StoreKit 2 purchases, threaded from the composition root
	/// (`SecretDJApp`) so ``TopUpsScreen`` and its
	/// ``TopUpTransactionListener`` share the exact same seam a real
	/// purchase and a later restore/drain both need to agree about
	/// unfinished transactions.
	let productPurchasing: any ProductPurchasing
	/// Owns "Restore Purchases" and the startup unfinished-transaction
	/// drain — started once at the composition root
	/// (``TopUpTransactionListener``'s doc comment), never per screen
	/// presentation.
	let topUpTransactionListener: TopUpTransactionListener
	let observability: ObservabilityPipeline

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
		previewPlayerModel: PreviewPlayerModel,
		onDeleteAccount: @escaping () -> Void,
		productPurchasing: any ProductPurchasing,
		topUpTransactionListener: TopUpTransactionListener,
		observability: ObservabilityPipeline = .disabled,
	) {
		self.sessionStore = sessionStore
		self.apiClient = apiClient
		self.locationService = locationService
		self.previewPlayerModel = previewPlayerModel
		self.onDeleteAccount = onDeleteAccount
		self.productPurchasing = productPurchasing
		self.topUpTransactionListener = topUpTransactionListener
		self.observability = observability
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
				tabStack(for: .profile) { router in
					profileScreen(
						personId: sessionStore.user?.personId ?? "",
						router: router,
						onDeleteAccount: onDeleteAccount,
					)
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
		case .song(let venueId, let target):
			TuneInDestinationScreen(
				target: target,
				venueId: venueId,
				apiClient: apiClient,
				sessionStore: sessionStore,
				toastQueue: toastQueue,
				previewPlayerModel: previewPlayerModel,
				router: router,
				observability: observability,
			)

		case .venue(let venueId):
			venueScreen(venueId: venueId, router: router)

		case .person(let personId):
			profileScreen(personId: personId, router: router, onDeleteAccount: nil)

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

		case .topUps(let context):
			topUpsScreen(context: context)

		default:
			ComingSoonScreen(destination: destination)
		}
	}

	private func topUpsScreen(context: FeedActionOutcome.TopUpContext) -> some View {
		TopUpsScreen(
			loader: APIClientFeedLoading.sessionFeed(
				sessionStore: sessionStore,
				locationService: locationService,
				endpoint: { userId, credential, _ in try await apiClient.topUpDetails(
					userId: userId,
					venueId: nil,
					context: context.apiContext,
					vendor: .appleAppStore,
					credential: credential,
				) },
			),
			sessionStore: sessionStore,
			toastQueue: toastQueue,
			listener: topUpTransactionListener,
			productPurchasing: productPurchasing,
			topUpsServicing: APIClientTopUpsService(client: apiClient),
			observability: observability,
		)
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

	/// Shared by the Profile tab root (`onDeleteAccount` forwarded, `personId`
	/// the session's own) and ``AppDestination/person(personId:)`` (no
	/// delete-account entry point — someone else's profile never renders
	/// this screen's footer at all, see ``ProfileScreen``'s own doc comment).
	private func profileScreen(personId: String, router: TabRouter, onDeleteAccount: (() -> Void)?) -> some View {
		ProfileScreen(
			personId: personId,
			loader: APIClientFeedLoading.sessionFeed(
				sessionStore: sessionStore,
				locationService: locationService,
				endpoint: { userId, credential, _ in try await apiClient.profile(
					userId: userId,
					profileUserId: personId,
					credential: credential,
				) },
			),
			router: router,
			toastQueue: toastQueue,
			sessionStore: sessionStore,
			likeToggling: APIClientLikeToggling(client: apiClient, sessionStore: sessionStore),
			onboardingService: APIClientOnboardingService(client: apiClient),
			onDeleteAccount: onDeleteAccount,
			observability: observability,
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
}

#Preview("Signed in") {
	TabsView(
		sessionStore: PreviewSessionStore.signedIn(),
		apiClient: PreviewAPIClient.broken(),
		locationService: PreviewLocationService.authorized(),
		previewPlayerModel: PreviewPlayerModel(
			downloading: InMemoryPreviewDownloading(),
			playerFactory: InMemoryAudioPlayerFactory(),
		),
		onDeleteAccount: {},
		productPurchasing: FakeProductPurchasing(),
		topUpTransactionListener: TopUpTransactionListener(
			purchasing: FakeProductPurchasing(),
			servicing: InMemoryTopUpsServicing(),
			sessionStore: PreviewSessionStore.signedIn(),
		),
	)
}

#Preview("Accessibility text size") {
	TabsView(
		sessionStore: PreviewSessionStore.signedIn(),
		apiClient: PreviewAPIClient.broken(),
		locationService: PreviewLocationService.authorized(),
		previewPlayerModel: PreviewPlayerModel(
			downloading: InMemoryPreviewDownloading(),
			playerFactory: InMemoryAudioPlayerFactory(),
		),
		onDeleteAccount: {},
		productPurchasing: FakeProductPurchasing(),
		topUpTransactionListener: TopUpTransactionListener(
			purchasing: FakeProductPurchasing(),
			servicing: InMemoryTopUpsServicing(),
			sessionStore: PreviewSessionStore.signedIn(),
		),
	)
	.environment(\.dynamicTypeSize, .accessibility5)
}
