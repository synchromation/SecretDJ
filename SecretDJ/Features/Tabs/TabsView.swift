import DesignSystem
import Observability
import SecretDJAPI
import SwiftUI

/// The signed-in app's real shell (PLAN.md S5.2): three tabs — Places
/// Nearby, Activity, Profile — each with its own `NavigationStack` driven by
/// a ``TabRouter`` (LEGACY.md "Launch and root navigation"). Each tab hosts
/// a themed placeholder root for now; S6 hangs real feeds off this shell,
/// routing their `FeedActionOutcome` taps through the same per-tab router
/// already wired here.
struct TabsView: View {
	let sessionStore: SessionStore
	let locationService: LocationService
	/// Starts the ``AccountFlowView`` delete-account flow, forwarded to the
	/// Profile tab — owned by `RootView`, see its doc comment for why.
	let onDeleteAccount: () -> Void

	@State private var model: TabsModel

	init(
		sessionStore: SessionStore,
		locationService: LocationService,
		onDeleteAccount: @escaping () -> Void,
		observability: ObservabilityPipeline = .disabled,
	) {
		self.sessionStore = sessionStore
		self.locationService = locationService
		self.onDeleteAccount = onDeleteAccount
		_model = State(initialValue: TabsModel(observability: observability))
	}

	var body: some View {
		TabView(selection: selectedTab) {
			Tab("Places Nearby", systemImage: Theme.Icon.venue.systemName, value: AppTab.placesNearby) {
				tabStack(for: .placesNearby) {
					PlacesNearbyPlaceholderScreen(locationService: locationService)
				}
			}

			Tab("Activity", systemImage: Theme.Icon.activity.systemName, value: AppTab.activity) {
				tabStack(for: .activity) {
					ActivityPlaceholderScreen()
				}
			}

			Tab("Profile", systemImage: Theme.Icon.profile.systemName, value: AppTab.profile) {
				tabStack(for: .profile) {
					ProfilePlaceholderScreen(sessionStore: sessionStore, onDeleteAccount: onDeleteAccount)
				}
			}
		}
	}

	private var selectedTab: Binding<AppTab> {
		Binding(get: { model.selectedTab }, set: { model.show(tab: $0) })
	}

	/// Wraps `root` in `tab`'s own `NavigationStack`, bound to its
	/// ``TabRouter``'s path — so a destination the router pushes (a routed
	/// ``FeedActionOutcome``, once S6 wires a real feed screen's taps into
	/// it) navigates within that tab alone, and the back button/swipe-back
	/// pop mirrors straight back into the router.
	private func tabStack(for tab: AppTab, @ViewBuilder root: () -> some View) -> some View {
		let router = model.router(for: tab)

		return NavigationStack(path: path(for: router)) {
			root()
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
		locationService: PreviewLocationService.authorized(),
		onDeleteAccount: {},
	)
}

#Preview("Accessibility text size") {
	TabsView(
		sessionStore: PreviewSessionStore.signedIn(),
		locationService: PreviewLocationService.authorized(),
		onDeleteAccount: {},
	)
	.environment(\.dynamicTypeSize, .accessibility5)
}
