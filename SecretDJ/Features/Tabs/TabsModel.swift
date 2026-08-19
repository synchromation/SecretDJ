import Observability
import Observation

/// The signed-in shell's navigation state (PLAN.md S5.2): which tab is
/// selected, and each tab's own ``TabRouter`` (LEGACY.md "Launch and root
/// navigation" — `CustomTabBarViewController`'s three tabs, each its own
/// nav stack). Also exposes the cross-tab affordance legacy had —
/// ``show(tab:)`` — for features like the extra-content ticker (S6.9) that
/// jump to Activity from elsewhere in the app
/// (`secretdjv3/FeedInteractor.swift`'s `userTappedExtraContent`).
@MainActor
@Observable
final class TabsModel {
	private(set) var selectedTab: AppTab = .placesNearby

	let placesNearbyRouter = TabRouter()
	let activityRouter = TabRouter()
	let profileRouter = TabRouter()

	private let observability: ObservabilityPipeline

	init(observability: ObservabilityPipeline = .disabled) {
		self.observability = observability
	}

	/// Switches to `tab` — both the tab bar's own tap and any programmatic
	/// cross-tab jump call this same method.
	func show(tab: AppTab) {
		guard tab != selectedTab else { return }

		selectedTab = tab
		observability.interaction("selectTab")
	}

	/// The router that owns `tab`'s back stack.
	func router(for tab: AppTab) -> TabRouter {
		switch tab {
		case .placesNearby: placesNearbyRouter
		case .activity: activityRouter
		case .profile: profileRouter
		}
	}
}
