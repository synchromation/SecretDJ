import DesignSystem
import FeedUI
import Observability
import SecretDJAPI
import SecretDJDomain
import SharedFeatures
import SwiftUI

/// A profile's own feed (`persondetails`, LEGACY.md "Tab 3 — Profile"),
/// serving both the Profile tab root (the signed-in user's own profile) and
/// someone else's profile reached via ``AppDestination/person(personId:)``
/// — S6.6's fuller reuse of the S6.2 venue-screen pattern (``VenueScreen``):
/// a header (``ProfileHeaderView``, sourced from
/// ``FeedUI/FeedScreenModel/personDetails``) hosting the person's like/
/// unlike toggle on someone else's profile (``ProfileScreenModel/likeModel``,
/// reconciled across refreshes like S6.2 did) and, on your own, the
/// avatar-change flow (``AvatarChangeSheet``, reusing Onboarding's upload
/// seam); own profile only, a gear toolbar button pushes ``SettingsScreen``
/// (S6.11), which now hosts the sign-out/delete-account entry points a
/// fixed footer used to host here.
///
/// Unlike legacy, this rewrite doesn't auto-refresh the profile feed
/// (`secretdjv3/FeedDataProvider.swift`'s `ProfileFeedDataProvider` never
/// overrides `shouldAutoRefresh()`, so it inherits the base class's
/// `false`) — matching legacy fidelity rather than every other S6 feed
/// screen's default-on auto-refresh.
struct ProfileScreen: View {
	let personId: String
	let router: TabRouter
	let toastQueue: ToastQueue
	let sessionStore: SessionStore
	let observability: ObservabilityPipeline
	/// A profile's feed carries no single venue in view —
	/// ``EngagePromotionOutcomeHandling`` gets `nil` for it, and
	/// ``PromotionEngaging`` no-ops the network call accordingly (its own
	/// doc comment).
	let promotionEngaging: any PromotionEngaging

	@State private var feedModel: FeedScreenModel
	@State private var model: ProfileScreenModel
	@State private var showsAvatarPicker = false
	@State private var inAppBrowserURL: InAppBrowserURL?
	@Environment(\.openURL) private var openURL

	init(
		personId: String,
		loader: any FeedLoading,
		router: TabRouter,
		toastQueue: ToastQueue,
		sessionStore: SessionStore,
		likeToggling: any LikeToggling,
		onboardingService: any OnboardingServicing,
		promotionEngaging: any PromotionEngaging,
		observability: ObservabilityPipeline = .disabled,
		installedApps: any InstalledApps = URLSchemeInstalledApps(),
	) {
		self.personId = personId
		self.router = router
		self.toastQueue = toastQueue
		self.sessionStore = sessionStore
		self.observability = observability
		self.promotionEngaging = promotionEngaging
		_feedModel = State(initialValue: FeedScreenModel(
			loader: loader,
			router: FeedActionRouter(installedApps: installedApps),
			// No `autoRefresh` — see this type's own doc comment.
			configuration: FeedConfiguration(autoRefresh: nil, paginationEnabled: false, changePolicy: .surfaceChange),
		))
		_model = State(initialValue: ProfileScreenModel(
			personId: personId,
			sessionStore: sessionStore,
			likeToggling: likeToggling,
			onboardingService: onboardingService,
			observability: observability,
		))
	}

	var body: some View {
		VStack(spacing: 0) {
			ProfileHeaderView(
				screenName: feedModel.personDetails?.screenName ?? "",
				avatarURL: feedModel.personDetails?.image?.url(for: .size1x1),
				isOwnProfile: model.isOwnProfile,
				likeModel: model.likeModel,
				isUploadingAvatar: model.isUploadingAvatar,
				onChangeAvatar: { showsAvatarPicker = true },
			)

			FeedScreen(model: feedModel, copy: Self.copy, onOutcome: handle(outcome:))
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.themedScreen()
		.navigationTitle(Text(
			"Profile",
			comment: "Navigation title of the Profile tab; also the coming-soon placeholder's title in place of a person's profile.",
		))
		.toolbar {
			if model.isOwnProfile {
				ToolbarItem(placement: .topBarTrailing) {
					Button("Settings", systemImage: Theme.Icon.settings.systemName) {
						router.push(.settings)
					}
					.labelStyle(.iconOnly)
				}
			}
		}
		.onChange(of: feedModel.personDetails) { _, person in
			model.personDetailsChanged(person)
		}
		.onChange(of: model.likeModel?.failureEvent) { _, event in
			guard let event else { return }
			toastQueue.enqueue(ToastItem(message: event.message ?? Self.likeFailureFallbackMessage))
		}
		.onChange(of: model.avatarUploadEvent) { _, event in
			guard let event else { return }
			showsAvatarPicker = false
			Task { await feedModel.refresh() }
			if let rewardMessage = event.rewardMessage, !rewardMessage.isEmpty {
				toastQueue.enqueue(ToastItem(message: rewardMessage))
			}
		}
		.sheet(isPresented: $showsAvatarPicker) {
			AvatarChangeSheet(
				isSubmitting: model.isUploadingAvatar,
				errorMessage: model.avatarUploadFailureMessage,
				onImageData: { data in Task { await model.uploadAvatar(data) } },
			)
		}
		.sheet(item: $inAppBrowserURL) { LegalWebScreen(url: $0.url).ignoresSafeArea() }
		.tracksScreen("Profile")
	}

	/// ``HailRideOutcomeHandling``/``OpenURLOutcomeHandling``/
	/// ``SocialAppOutcomeHandling``/``EngagePromotionOutcomeHandling`` each
	/// intercept their own hand-off first (S6.10/S8.5 cross-check); every
	/// other outcome routes through ``TabRouter`` exactly as before.
	private func handle(outcome: FeedActionOutcome) {
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
			venueId: nil,
			promotionEngaging: promotionEngaging,
			observability: observability,
		) else { return }
		router.handle(outcome: outcome)
	}

	/// ``SharedFeatures/OptimisticLikeModel`` owns no fallback copy of its
	/// own (package views own zero copy — mirrors ``VenueScreen``'s own
	/// fallback) when a like/unlike failure carries no server message; this
	/// is that fallback, shared verbatim with every other S6 screen's own
	/// like toggle.
	private static var likeFailureFallbackMessage: String {
		String(
			localized: "Sorry, we couldn't update that — please try again.",
			comment: "Toast shown when liking or unliking something fails.",
		)
	}

	private static var copy: FeedScreenCopy {
		FeedScreenCopy(
			emptySystemImage: Theme.Icon.profile.systemName,
			emptyTitle: Text(
				"Nothing Here Yet",
				comment: "Title shown on the profile feed when it has no content yet.",
			),
			emptyMessage: Text(
				"Nothing to show here yet — check back soon.",
				comment: "Body shown on the profile feed when it has no content yet.",
			),
			errorTitle: Text("Something Went Wrong", comment: "Title shown on the profile feed when it fails to load."),
			errorMessage: Text(
				"Sorry, we couldn't load this profile.\n\nPlease check that you have a good connection to your cellular data or WiFi network.",
				comment: "Body shown on the profile feed when it fails to load.",
			),
			offlineTitle: Text(
				"You're Offline",
				comment: "Title shown on the profile feed when the device has no internet connection.",
			),
			offlineMessage: Text(
				"Check your connection and try again.",
				comment: "Body shown on the profile feed when the device has no internet connection.",
			),
			retryTitle: Text("Try Again", comment: "Button that retries loading the profile feed after a failure."),
		)
	}
}

#Preview("Own profile") {
	NavigationStack {
		ProfileScreen(
			personId: "9",
			loader: PreviewProfileLoading.ownProfile(),
			router: TabRouter(),
			toastQueue: ToastQueue(),
			sessionStore: PreviewSessionStore.signedIn(personId: "9", screenName: "TurboTim"),
			likeToggling: InMemoryLikeToggling(),
			onboardingService: InMemoryOnboardingService(),
			promotionEngaging: InMemoryPromotionEngaging(),
		)
	}
}

#Preview("Someone else's profile") {
	NavigationStack {
		ProfileScreen(
			personId: "41",
			loader: PreviewProfileLoading.otherProfile(),
			router: TabRouter(),
			toastQueue: ToastQueue(),
			sessionStore: PreviewSessionStore.signedIn(personId: "9", screenName: "TurboTim"),
			likeToggling: InMemoryLikeToggling(),
			onboardingService: InMemoryOnboardingService(),
			promotionEngaging: InMemoryPromotionEngaging(),
		)
	}
}

#Preview("Empty") {
	NavigationStack {
		ProfileScreen(
			personId: "9",
			loader: PreviewProfileLoading.empty(),
			router: TabRouter(),
			toastQueue: ToastQueue(),
			sessionStore: PreviewSessionStore.signedIn(personId: "9", screenName: "TurboTim"),
			likeToggling: InMemoryLikeToggling(),
			onboardingService: InMemoryOnboardingService(),
			promotionEngaging: InMemoryPromotionEngaging(),
		)
	}
}

#Preview("Accessibility text size") {
	NavigationStack {
		ProfileScreen(
			personId: "9",
			loader: PreviewProfileLoading.ownProfile(),
			router: TabRouter(),
			toastQueue: ToastQueue(),
			sessionStore: PreviewSessionStore.signedIn(personId: "9", screenName: "TurboTim"),
			likeToggling: InMemoryLikeToggling(),
			onboardingService: InMemoryOnboardingService(),
			promotionEngaging: InMemoryPromotionEngaging(),
		)
	}
	.environment(\.dynamicTypeSize, .accessibility5)
}
