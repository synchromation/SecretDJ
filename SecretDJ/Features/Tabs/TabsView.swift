import DesignSystem
import FeedUI
import Observability
import SecretDJAPI
import SecretDJDomain
import SharedFeatures
import SwiftUI

/// The signed-in app's real shell (PLAN.md S5.2): three tabs — Places
/// Nearby, Activity, Profile — each with its own `NavigationStack` driven by
/// a ``TabRouter`` (LEGACY.md "Launch and root navigation"), its stack able
/// to push a real ``VenueScreen``/``NowPlayingScreen``/``ProfileScreen`` or
/// ``SettingsScreen``. Also composes the shell-wide ``DesignSystem/ToastQueue``
/// every S6 feed screen's jukebox-changed toast presents through.
struct TabsView: View {
	let sessionStore: SessionStore
	let apiClient: APIClient
	let locationService: LocationService
	/// The app-wide shared song-preview player (S6.4) — see `SecretDJApp`'s
	/// own doc comment on why exactly one instance exists.
	let previewPlayerModel: PreviewPlayerModel
	/// Starts the ``AccountFlowView`` delete-account flow, forwarded to the
	/// Profile tab — owned by `RootView`, see its doc comment for why.
	let onDeleteAccount: () -> Void
	/// StoreKit 2 purchases, threaded from the composition root so
	/// ``TopUpsScreen`` and ``TopUpTransactionListener`` share the exact
	/// same seam a purchase and a later restore/drain both need to agree
	/// about unfinished transactions.
	let productPurchasing: any ProductPurchasing
	/// Owns "Restore Purchases" and the startup unfinished-transaction
	/// drain — started once at the composition root, never per screen.
	let topUpTransactionListener: TopUpTransactionListener
	let observability: ObservabilityPipeline

	@State private var model: TabsModel
	/// Composed here, at the shell's root, so a toast raised by any tab's
	/// screen presents above the tab bar rather than getting clipped to one
	/// tab's own stack.
	@State private var toastQueue = ToastQueue()
	/// The in-app browser sheet ``OpenURLOutcomeHandling`` presents for this
	/// shell's own `handle(outcome:router:venueId:)` path (S8.5 cross-check).
	@State private var inAppBrowserURL: InAppBrowserURL?
	@Environment(\.openURL) private var openURL
	/// The ``PromotionEngaging`` seam every `.engagePromotion` outcome fires
	/// through, built once here — unlike ``topUpTransactionListener`` it
	/// carries no identity to protect.
	var promotionEngaging: any PromotionEngaging {
		APIClientPromotionEngaging(client: apiClient, sessionStore: sessionStore)
	}

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
						extraContentLoading: APIClientExtraContentLoading(
							client: apiClient,
							sessionStore: sessionStore,
						),
						onShowActivity: { model.show(tab: .activity) },
						promotionEngaging: promotionEngaging,
						observability: observability,
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
						promotionEngaging: promotionEngaging,
					)
				}
			}

			Tab("Profile", systemImage: Theme.Icon.profile.systemName, value: AppTab.profile) {
				tabStack(for: .profile) { router in
					profileScreen(personId: sessionStore.user?.personId ?? "", router: router, toastQueue: toastQueue)
				}
			}
		}
		.themedTabBar() // S9.5: selected-tab tint already follows the root `.tint` (`SecretDJApp`).
		.toastPresenter(
			queue: toastQueue,
			richToastVipActionLabel: Self.richToastVipActionLabel,
			onRichToastVipTapped: { personId in
				observability.interaction("richToastTapped")
				model.router(for: model.selectedTab).push(.person(personId: personId))
			},
		)
		.sheet(item: $inAppBrowserURL) { LegalWebScreen(url: $0.url).ignoresSafeArea() }
	}

	private var selectedTab: Binding<AppTab> {
		Binding(get: { model.selectedTab }, set: { model.show(tab: $0) })
	}

	/// Wraps `root` in `tab`'s own `NavigationStack`, bound to its
	/// ``TabRouter``'s path — so a destination the router pushes navigates
	/// within that tab alone, and the back button/swipe-back pop mirrors
	/// straight back into the router. `root` receives that same router, for
	/// a screen that routes its own feed taps or a nested screen's taps
	/// (the venue map's annotations) through it directly.
	private func tabStack(for tab: AppTab, @ViewBuilder root: (TabRouter) -> some View) -> some View {
		let router = model.router(for: tab)

		return NavigationStack(path: path(for: router)) {
			root(router)
				.navigationDestination(for: AppDestination.self) { destination in
					self.destination(for: destination, router: router)
				}
		}
	}

	/// Every ``AppDestination`` case has a real screen (S6 is complete);
	/// the switch is exhaustive, so there is no ``ComingSoonScreen``
	/// fallback left (PLAN.md S5.2).
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
			venueScreen(
				venueId: venueId,
				router: router,
				toastQueue: toastQueue,
				onShowActivity: { model.show(tab: .activity) },
			)

		case .person(let personId):
			profileScreen(personId: personId, router: router, toastQueue: toastQueue)

		case .settings:
			settingsScreen(toastQueue: toastQueue)

		case .nowPlaying(let venueId):
			nowPlayingScreen(venueId: venueId, router: router, toastQueue: toastQueue)

		case .jukebox(let venueId, let jukeboxId):
			musicSelectionScreen(venueId: venueId, jukeboxId: jukeboxId, router: router, toastQueue: toastQueue)

		case .search(let venueId):
			MusicSearchScreen(
				searching: APIClientMusicSearching(client: apiClient, sessionStore: sessionStore, venueId: venueId),
				copy: Self.musicSearchCopy,
				onOutcome: { handle(outcome: $0, router: router, venueId: venueId) },
			)

		case .songsForArtist(let venueId, let artist):
			SongsForArtistScreen(
				artistName: artist,
				searching: APIClientMusicSearching(client: apiClient, sessionStore: sessionStore, venueId: venueId),
				copy: Self.songsForArtistCopy,
				onOutcome: { handle(outcome: $0, router: router, venueId: venueId) },
			)

		case .topUps(let context):
			topUpsScreen(context: context, toastQueue: toastQueue)
		}
	}

	private func path(for router: TabRouter) -> Binding<[AppDestination]> {
		Binding(get: { router.path }, set: { router.setPath($0) })
	}

	/// Every screen this shell composes with a venue-context `onOutcome`
	/// (music search, songs-for-artist, music selection) forwards its
	/// outcomes here rather than straight to `router.handle(outcome:venueId:)`
	/// — the same hail-ride/openURL/social-app/engage-promotion chain every
	/// S6 feed screen's own `handle(outcome:)` tries (S6.10/S8.5 cross-check).
	func handle(outcome: FeedActionOutcome, router: TabRouter, venueId: String) {
		guard !HailRideOutcomeHandling.handle(outcome, openURL: openURL, observability: observability) else { return }
		guard !OpenURLOutcomeHandling.handle(
			outcome,
			openURL: openURL,
			presentInApp: { inAppBrowserURL = InAppBrowserURL(url: $0) },
			observability: observability,
		) else { return }
		guard !SocialAppOutcomeHandling.handle(outcome, openURL: openURL, observability: observability) else { return }
		guard !EngagePromotionOutcomeHandling.handle(
			outcome,
			venueId: venueId,
			promotionEngaging: promotionEngaging,
			observability: observability,
		) else { return }
		router.handle(outcome: outcome, venueId: venueId)
	}
}

extension TabsView {
	/// Previews only — never production (previews always inject fakes, per
	/// swiftui-views).
	fileprivate static func preview() -> TabsView {
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
}

#Preview("Signed in") {
	TabsView.preview()
}

#Preview("Accessibility text size") {
	TabsView.preview()
		.environment(\.dynamicTypeSize, .accessibility5)
}
