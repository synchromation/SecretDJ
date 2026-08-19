import DesignSystem
import FeedUI
import MapKit
import Observability
import SecretDJDomain
import SharedFeatures
import SwiftUI

/// The venue's own feed (`venuedetails`, LEGACY.md "Venue screen"),
/// auto-refreshing, over ``FeedUI/FeedScreen`` — S6.2's fuller reuse of the
/// S6.1 pattern (``PlacesNearbyScreen``), plus what the venue screen adds on
/// top: the header (``VenueHeaderView``, sourced from
/// ``FeedUI/FeedScreenModel/venueDetails``) hosting the venue's like/unlike
/// toggle (``OptimisticLikeModel``), check-in (``CheckInModel``, S6.8),
/// directions (S6.10 — an Apple Maps walking-directions hand-off, this
/// screen's own doc comment on ``openDirections()``), and the entry point
/// into ``NowPlayingScreen``; the client-side social-links reorder
/// (``VenueSocialLinksOrdering``, applied by ``SocialOrderingFeedLoading``
/// before this screen's model ever sees a fetched feed); and the
/// non-navigational outcomes a promotion tap (or a server-driven hail-ride
/// action button) can produce
/// (``FeedUI/FeedActionOutcome/openSocialApp(platform:identifier:webFallbackURL:)``/
/// ``FeedUI/FeedActionOutcome/openURL(_:)``/``FeedUI/FeedActionOutcome/engagePromotion(promotionId:)``/
/// ``FeedUI/FeedActionOutcome/hailRide(url:)``), which — unlike every
/// navigational outcome — this screen handles directly rather than handing
/// to ``TabRouter``.
struct VenueScreen: View {
	let venueId: String
	let router: TabRouter
	let toastQueue: ToastQueue
	let likeToggling: any LikeToggling
	let checkingIn: any CheckingIn
	let observability: ObservabilityPipeline
	let promotionEngaging: any PromotionEngaging

	@State private var model: FeedScreenModel
	@State private var likeModel: OptimisticLikeModel?
	@State private var checkInModel: CheckInModel?
	@Environment(\.openURL) private var openURL

	init(
		venueId: String,
		loader: any FeedLoading,
		locationService: LocationService,
		router: TabRouter,
		toastQueue: ToastQueue,
		likeToggling: any LikeToggling,
		checkingIn: any CheckingIn,
		observability: ObservabilityPipeline = .disabled,
		promotionEngaging: any PromotionEngaging,
		installedApps: any InstalledApps = URLSchemeInstalledApps(),
	) {
		self.venueId = venueId
		self.router = router
		self.toastQueue = toastQueue
		self.likeToggling = likeToggling
		self.checkingIn = checkingIn
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
			if let venue = model.venueDetails, let likeModel, let checkInModel {
				VenueHeaderView(
					venueName: venue.name,
					venueAddress: venue.address,
					likeModel: likeModel,
					checkInModel: checkInModel,
					onNowPlaying: { openNowPlaying() },
					onDirections: { openDirections(venue: venue) },
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

			if let checkInModel {
				checkInModel.reconcile(with: venue.checkedIn)
			} else {
				checkInModel = CheckInModel(
					venueId: venue.venueId,
					checkedIn: venue.checkedIn,
					checkingIn: checkingIn,
					observability: observability,
				)
			}
		}
		.onChange(of: likeModel?.failureEvent) { _, event in
			guard let event else { return }
			toastQueue.enqueue(ToastItem(message: event.message ?? Self.likeFailureFallbackMessage))
		}
		.onChange(of: checkInModel?.successEvent) { _, event in
			guard let event else { return }
			// LEGACY.md's `ToastHandler`: a response URL is opened *instead
			// of* the toast, never alongside it.
			if let url = event.url {
				observability.interaction("openCheckInURL")
				openURL(url)
			} else if let message = event.message, !message.isEmpty {
				toastQueue.enqueue(ToastItem(message: message))
			}
		}
		.onChange(of: checkInModel?.failureEvent) { _, event in
			guard let event else { return }
			toastQueue.enqueue(ToastItem(message: event.message ?? Self.checkInFailureFallbackMessage))
		}
		.tracksScreen("Venue")
	}

	private func openNowPlaying() {
		observability.interaction("openNowPlaying")
		router.push(.nowPlaying(venueId: venueId))
	}

	/// LEGACY.md "Venue screen": "Directions → `VenueDirectionsViewController`:
	/// MapKit map with venue pin + walking route from current location
	/// (`DirectionsProvider.swift`), phone-call button, and pre-filled
	/// SMS/email share." That screen's own routing half —
	/// `secretdjv3/DirectionsProvider.swift`'s `MKDirections.Request` with
	/// `transportType = .walking` from the current location to the venue's
	/// coordinate — is what this hands off to Apple's own Maps app rather
	/// than re-building in-app: modern Maps already renders the walking
	/// route, and (unlike 2017) already offers a call button and a share
	/// sheet from the destination pin itself, which is what
	/// `DirectionsMessageProvider.swift`'s pre-filled SMS/email hand-off
	/// existed to approximate by hand. That hand-built share flow isn't
	/// ported here — it's materially separate from what PLAN.md S6.10 asks
	/// for ("directions surface; server-driven Uber/taxi actions preserved
	/// via `appmask`").
	private func openDirections(venue: Venue) {
		observability.interaction("openDirections")

		let location = CLLocation(latitude: venue.lat, longitude: venue.lng)
		let address = MKAddress(fullAddress: venue.address, shortAddress: nil)
		let mapItem = MKMapItem(location: location, address: address)
		mapItem.name = venue.name
		mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
	}

	/// Every navigational outcome (song/jukebox/person/venue/...) still goes
	/// through ``TabRouter`` exactly like every other S6 feed screen —
	/// ``TabRouter/handle(outcome:venueId:)`` supplies this screen's own
	/// venue id for the three outcomes that need one
	/// (``FeedUI/FeedActionOutcome/showJukebox(jukeboxId:)``/
	/// ``FeedUI/FeedActionOutcome/launchSearch``/
	/// ``FeedUI/FeedActionOutcome/showSongsForArtist(artist:)``) — only the
	/// outcomes a promotion tap or a server-driven hail-ride action button
	/// can produce are this screen's own side effect
	/// (``AppDestination/init(outcome:)``'s doc comment: "S6 hangs its own
	/// handling... directly off the outcome").
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

		case .hailRide:
			HailRideOutcomeHandling.handle(outcome, openURL: openURL, observability: observability)

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

	/// ``CheckInModel`` owns no fallback copy of its own (mirrors this
	/// type's own ``likeFailureFallbackMessage``) when a check-in failure
	/// carries no server message.
	static var checkInFailureFallbackMessage: String {
		String(
			localized: "Sorry, we couldn't check you in — please try again.",
			comment: "Toast shown when checking in at a venue fails.",
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
			checkingIn: InMemoryCheckingIn(),
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
			checkingIn: InMemoryCheckingIn(),
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
			checkingIn: InMemoryCheckingIn(),
			promotionEngaging: InMemoryPromotionEngaging(),
		)
	}
	.environment(\.dynamicTypeSize, .accessibility5)
}
