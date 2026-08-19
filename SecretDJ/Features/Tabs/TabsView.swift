import DesignSystem
import Observability
import SecretDJAPI
import SwiftUI

/// The signed-in app's real shell (PLAN.md S5.2): three tabs — Places
/// Nearby, Activity, Profile — each with its own `NavigationStack` driven by
/// a ``TabRouter`` (LEGACY.md "Launch and root navigation"). Places Nearby
/// hosts its real feed as of S6.1; Activity and Profile still host a themed
/// placeholder root pending S6.5/S6.6. Also composes the shell-wide
/// ``DesignSystem/ToastQueue`` every S6 feed screen's jukebox-changed toast
/// (and later, other server-driven toasts) presents through.
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
				tabStack(for: .activity) { _ in
					ActivityPlaceholderScreen()
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
					ComingSoonScreen(destination: destination)
				}
		}
	}

	private func path(for router: TabRouter) -> Binding<[AppDestination]> {
		Binding(get: { router.path }, set: { router.setPath($0) })
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
