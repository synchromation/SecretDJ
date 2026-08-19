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
/// seam); a fixed footer with the sign-out/delete-account entry points S5's
/// pre-tabs placeholder used to host (`// S6.11:` relocates delete-account
/// into Settings), own-profile only.
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
	/// Starts the ``AccountFlowView`` delete-account flow, forwarded from
	/// `RootView` via ``TabsView`` — `nil` on someone else's profile, where
	/// the footer never renders at all.
	let onDeleteAccount: (() -> Void)?
	let observability: ObservabilityPipeline

	@State private var feedModel: FeedScreenModel
	@State private var model: ProfileScreenModel
	@State private var showsAvatarPicker = false
	@State private var isConfirmingSignOut = false
	@Environment(\.openURL) private var openURL

	init(
		personId: String,
		loader: any FeedLoading,
		router: TabRouter,
		toastQueue: ToastQueue,
		sessionStore: SessionStore,
		likeToggling: any LikeToggling,
		onboardingService: any OnboardingServicing,
		onDeleteAccount: (() -> Void)? = nil,
		observability: ObservabilityPipeline = .disabled,
		installedApps: any InstalledApps = URLSchemeInstalledApps(),
	) {
		self.personId = personId
		self.router = router
		self.toastQueue = toastQueue
		self.sessionStore = sessionStore
		self.onDeleteAccount = onDeleteAccount
		self.observability = observability
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

			if model.isOwnProfile {
				footer
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(Theme.ColorRole.background.color)
		.navigationTitle(Text(
			"Profile",
			comment: "Navigation title of the Profile tab; also the coming-soon placeholder's title in place of a person's profile.",
		))
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
		.tracksScreen("Profile")
	}

	private var footer: some View {
		VStack(spacing: Spacing.small) {
			Divider()

			Button("Sign Out") {
				isConfirmingSignOut = true
			}
			.buttonStyle(.secondary)

			// S6.11: relocate this entry point into Settings.
			Button("Delete Account", action: { onDeleteAccount?() })
				.font(Theme.TextStyle.body.font)
				.foregroundStyle(Theme.ColorRole.danger.color)
				.frame(minHeight: 44)
		}
		.padding(Spacing.medium)
		.background(Theme.ColorRole.background.color)
		.confirmationDialog(
			"Sign Out?",
			isPresented: $isConfirmingSignOut,
			titleVisibility: .visible,
		) {
			Button("Sign Out", role: .destructive, action: signOut)
			Button("Cancel", role: .cancel) {}
		}
	}

	private func signOut() {
		observability.interaction("signOut")
		sessionStore.signOut()
	}

	/// ``HailRideOutcomeHandling`` intercepts a hail-ride hand-off first
	/// (S6.10); every other outcome routes through ``TabRouter`` exactly as
	/// before.
	private func handle(outcome: FeedActionOutcome) {
		guard !HailRideOutcomeHandling.handle(outcome, openURL: openURL, observability: observability) else { return }
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
			onDeleteAccount: {},
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
			onDeleteAccount: {},
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
			onDeleteAccount: {},
		)
	}
	.environment(\.dynamicTypeSize, .accessibility5)
}
