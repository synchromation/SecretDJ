import DesignSystem
import FeedUI
import Observability
import SecretDJDomain
import SharedFeatures
import SwiftUI

/// The venue's own feed (`venuedetails`, LEGACY.md "Venue screen"),
/// auto-refreshing, over ``FeedUI/FeedScreen`` — S6.2's fuller reuse of the
/// S6.1 pattern (``PlacesNearbyScreen``), plus what the venue screen adds on
/// top: the header (``VenueHeaderView``, sourced from
/// ``FeedUI/FeedScreenModel/venueDetails``) hosting the venue's like/unlike
/// toggle (``OptimisticLikeModel``) and the entry point into
/// ``NowPlayingScreen``; the client-side social-links reorder
/// (``VenueSocialLinksOrdering``, applied by ``SocialOrderingFeedLoading``
/// before this screen's model ever sees a fetched feed); and the
/// non-navigational outcomes a promotion tap can produce
/// (``FeedUI/FeedActionOutcome/openSocialApp(platform:identifier:webFallbackURL:)``/
/// ``FeedUI/FeedActionOutcome/openURL(_:)``/``FeedUI/FeedActionOutcome/engagePromotion(promotionId:)``),
/// which — unlike every navigational outcome — this screen handles directly
/// rather than handing to ``TabRouter``.
struct VenueScreen: View {
	let venueId: String
	let router: TabRouter
	let toastQueue: ToastQueue
	let likeToggling: any LikeToggling
	let observability: ObservabilityPipeline
	let promotionEngaging: any PromotionEngaging

	@State private var model: FeedScreenModel
	@State private var likeModel: OptimisticLikeModel?
	@Environment(\.openURL) private var openURL

	init(
		venueId: String,
		loader: any FeedLoading,
		locationService: LocationService,
		router: TabRouter,
		toastQueue: ToastQueue,
		likeToggling: any LikeToggling,
		observability: ObservabilityPipeline = .disabled,
		promotionEngaging: any PromotionEngaging,
		installedApps: any InstalledApps = URLSchemeInstalledApps(),
	) {
		self.venueId = venueId
		self.router = router
		self.toastQueue = toastQueue
		self.likeToggling = likeToggling
		self.observability = observability
		self.promotionEngaging = promotionEngaging
		_model = State(initialValue: FeedScreenModel(
			loader: SocialOrderingFeedLoading(base: loader),
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
		VStack(spacing: 0) {
			if let venue = model.venueDetails, let likeModel {
				VenueHeaderView(
					venueName: venue.name,
					venueAddress: venue.address,
					likeModel: likeModel,
					onNowPlaying: { openNowPlaying() },
				)
			}

			FeedScreen(
				model: model,
				copy: Self.copy,
				onOutcome: handle(outcome:),
				onJukeboxChanged: handleJukeboxChanged,
			)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(Theme.ColorRole.background.color)
		.navigationTitle(Text("Venue", comment: "Navigation title of a venue's screen."))
		.onChange(of: model.venueDetails) { _, venue in
			guard let venue else { return }

			if let likeModel {
				// A later auto-refresh's fresh payload — resync rather than
				// leaving the header frozen at whatever it looked like on
				// first load (``OptimisticLikeModel/reconcile(with:)``'s doc
				// comment covers why an in-flight toggle is protected).
				likeModel.reconcile(with: venue.likeInfo)
			} else {
				likeModel = OptimisticLikeModel(
					itemId: venue.venueId,
					venueId: venue.venueId,
					type: .venue,
					likeInfo: venue.likeInfo,
					likeToggling: likeToggling,
					observability: observability,
				)
			}
		}
		.onChange(of: likeModel?.failureEvent) { _, event in
			guard let event else { return }
			toastQueue.enqueue(ToastItem(message: event.message ?? Self.likeFailureFallbackMessage))
		}
		.tracksScreen("Venue")
	}

	private func openNowPlaying() {
		observability.interaction("openNowPlaying")
		router.push(.nowPlaying(venueId: venueId))
	}

	/// Every navigational outcome (song/jukebox/person/venue/...) still goes
	/// through ``TabRouter`` exactly like every other S6 feed screen —
	/// ``TabRouter/handle(outcome:venueId:)`` supplies this screen's own
	/// venue id for the three outcomes that need one
	/// (``FeedUI/FeedActionOutcome/showJukebox(jukeboxId:)``/
	/// ``FeedUI/FeedActionOutcome/launchSearch``/
	/// ``FeedUI/FeedActionOutcome/showSongsForArtist(artist:)``) — only the
	/// three outcomes a promotion tap can produce are this screen's own side
	/// effect (``AppDestination/init(outcome:)``'s doc comment: "S6 hangs
	/// its own handling... directly off the outcome").
	private func handle(outcome: FeedActionOutcome) {
		switch outcome {
		case .openSocialApp(let platform, let identifier, let webFallbackURL):
			openSocialApp(platform: platform, identifier: identifier, webFallbackURL: webFallbackURL)

		case .openURL(.external(let url)),
		     .openURL(.inApp(let url)):
			// No in-app web view exists yet in this rewrite (legacy's
			// `InternalWebViewController` isn't ported by any S6 task so
			// far) — both branches open externally until one lands.
			observability.interaction("openPromotionURL")
			openURL(url)

		case .engagePromotion(let promotionId):
			observability.interaction("engagePromotion")
			Task { await promotionEngaging.engage(venueId: venueId, promotionId: promotionId) }

		default:
			router.handle(outcome: outcome, venueId: venueId)
		}
	}

	/// `secretdjv3/FeedActionProvider.swift:319-324`'s deep-link-else-browser
	/// rule: try the native app first (``SocialAppDeepLink``), falling back
	/// to the web profile URL either when no native scheme exists for this
	/// platform or when opening it didn't succeed.
	private func openSocialApp(platform: SocialPlatform, identifier: String, webFallbackURL: URL) {
		observability.interaction("openSocialApp")

		guard let nativeURL = SocialAppDeepLink.url(platform: platform, identifier: identifier) else {
			openURL(webFallbackURL)
			return
		}

		openURL(nativeURL) { accepted in
			if !accepted {
				openURL(webFallbackURL)
			}
		}
	}

	private func handleJukeboxChanged() {
		toastQueue.enqueue(ToastItem(message: String(
			localized: "Jukebox Updated",
			comment: "Toast shown when a paginated feed's content changed underneath the user (LEGACY.md's kJukeboxUpdatedText).",
		)))
	}

	/// ``SharedFeatures/OptimisticLikeModel`` owns no fallback copy of its
	/// own (package views own zero copy — mirrors `MoodTileModel`'s doc
	/// comment) when a like/unlike failure carries no server message; this
	/// is that fallback, shared verbatim with ``TuneInScreen``'s own buzz
	/// toggle.
	static var likeFailureFallbackMessage: String {
		String(
			localized: "Sorry, we couldn't update that — please try again.",
			comment: "Toast shown when liking or unliking something fails.",
		)
	}

	private static var copy: FeedScreenCopy {
		FeedScreenCopy(
			emptySystemImage: Theme.Icon.venue.systemName,
			emptyTitle: Text(
				"Nothing Here Yet",
				comment: "Title shown on the venue feed when it has no content yet.",
			),
			emptyMessage: Text(
				"This venue hasn't got anything to show yet — check back soon.",
				comment: "Body shown on the venue feed when it has no content yet.",
			),
			errorTitle: Text(
				"Something Went Wrong",
				comment: "Title shown on the venue feed when it fails to load.",
			),
			errorMessage: Text(
				"Sorry, we couldn't load this venue.\n\nPlease check that you have a good connection to your cellular data or WiFi network.",
				comment: "Body shown on the venue feed when it fails to load.",
			),
			offlineTitle: Text(
				"You're Offline",
				comment: "Title shown on the venue feed when the device has no internet connection.",
			),
			offlineMessage: Text(
				"Check your connection and try again.",
				comment: "Body shown on the venue feed when the device has no internet connection.",
			),
			retryTitle: Text(
				"Try Again",
				comment: "Button that retries loading the venue feed after a failure.",
			),
		)
	}
}

#Preview("Loaded") {
	NavigationStack {
		VenueScreen(
			venueId: "v1",
			loader: PreviewVenueLoading.loaded(),
			locationService: PreviewLocationService.authorized(),
			router: TabRouter(),
			toastQueue: ToastQueue(),
			likeToggling: InMemoryLikeToggling(),
			promotionEngaging: InMemoryPromotionEngaging(),
		)
	}
}

#Preview("Empty") {
	NavigationStack {
		VenueScreen(
			venueId: "v1",
			loader: PreviewVenueLoading.empty(),
			locationService: PreviewLocationService.authorized(),
			router: TabRouter(),
			toastQueue: ToastQueue(),
			likeToggling: InMemoryLikeToggling(),
			promotionEngaging: InMemoryPromotionEngaging(),
		)
	}
}

#Preview("Accessibility text size") {
	NavigationStack {
		VenueScreen(
			venueId: "v1",
			loader: PreviewVenueLoading.loaded(),
			locationService: PreviewLocationService.authorized(),
			router: TabRouter(),
			toastQueue: ToastQueue(),
			likeToggling: InMemoryLikeToggling(),
			promotionEngaging: InMemoryPromotionEngaging(),
		)
	}
	.environment(\.dynamicTypeSize, .accessibility5)
}
