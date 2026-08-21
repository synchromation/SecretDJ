import DesignSystem
import FeedUI
import SecretDJAPI
import SecretDJDomain
import SharedFeatures
import SwiftUI

/// ``TabsView``'s per-destination screen builders — split from
/// `TabsView.swift` itself (an extension, not a second type) for the same
/// file-length reason as ``TabsView/jukeboxChangedMessage`` and friends
/// (`TabsView+Copy.swift`'s own doc comment). `toastQueue` is threaded in as
/// an explicit parameter rather than read off `self`: SwiftFormat's
/// `privateStateVariables` rule keeps `TabsView`'s own `@State` storage
/// `private`, and `private`/`fileprivate` are both file-scoped in Swift, so
/// a same-file-only property can't cross into this extension — matching how
/// every screen these methods build already takes `toastQueue` as its own
/// explicit init parameter rather than reaching for shared state.
extension TabsView {
	func topUpsScreen(context: FeedActionOutcome.TopUpContext, toastQueue: ToastQueue) -> some View {
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

	func venueScreen(
		venueId: String,
		router: TabRouter,
		toastQueue: ToastQueue,
		onShowActivity: @escaping () -> Void,
	) -> some View {
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
			checkingIn: APIClientCheckingIn(client: apiClient, sessionStore: sessionStore),
			observability: observability,
			promotionEngaging: promotionEngaging,
			extraContentLoading: APIClientExtraContentLoading(client: apiClient, sessionStore: sessionStore),
			onShowActivity: onShowActivity,
		)
	}

	/// Shared by the Profile tab root and ``AppDestination/person(personId:)``
	/// — the gear toolbar button leading to ``settingsScreen(toastQueue:)``
	/// only ever renders on the former (``ProfileScreen``'s own doc comment).
	func profileScreen(personId: String, router: TabRouter, toastQueue: ToastQueue) -> some View {
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
			promotionEngaging: promotionEngaging,
			observability: observability,
		)
	}

	/// The Settings hub (S6.11), pushed from the Profile tab's gear toolbar
	/// button — relocates the sign-out/delete-account entry points.
	@ViewBuilder
	func settingsScreen(toastQueue: ToastQueue) -> some View {
		if let user = sessionStore.user, let credential = sessionStore.credential {
			SettingsScreen(
				personId: user.personId,
				credential: credential,
				sessionStore: sessionStore,
				settingsService: APIClientSettingsService(client: apiClient),
				onboardingService: APIClientOnboardingService(client: apiClient),
				toastQueue: toastQueue,
				onDeleteAccount: onDeleteAccount,
				observability: observability,
			)
		}
	}

	func nowPlayingScreen(venueId: String, router: TabRouter, toastQueue: ToastQueue) -> some View {
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
			promotionEngaging: promotionEngaging,
		)
	}

	func musicSelectionScreen(
		venueId: String,
		jukeboxId: Int,
		router: TabRouter,
		toastQueue: ToastQueue,
	) -> some View {
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
			onOutcome: { handle(outcome: $0, router: router, venueId: venueId) },
			onJukeboxChanged: { toastQueue.enqueue(ToastItem(message: Self.jukeboxChangedMessage)) },
		)
	}

	/// The legacy 50-song page size for `musicselection`/`musicdigest`
	/// (LEGACY.md "Choosing music" — server-adjustable batch size isn't
	/// modeled yet, so this is a fixed client default).
	static var musicSelectionBatchSize: Int {
		50
	}
}
