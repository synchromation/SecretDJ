import Observability
import Testing

@testable import SecretDJ

/// The signed-in shell's navigation state (PLAN.md S5.2): which tab is
/// selected, each tab's own ``TabRouter``, and the cross-tab `show(tab:)`
/// affordance legacy's extra-content ticker used to jump to Activity.
@MainActor
enum TabsModelTests {
	struct `Starting up` {
		@Test func `starts on the Places Nearby tab`() {
			let model = TabsModel()

			#expect(model.selectedTab == .placesNearby)
		}

		@Test func `each tab has its own router`() {
			let model = TabsModel()

			#expect(model.router(for: .placesNearby) === model.placesNearbyRouter)
			#expect(model.router(for: .activity) === model.activityRouter)
			#expect(model.router(for: .profile) === model.profileRouter)
		}
	}

	struct `Switching tabs` {
		@Test func `show(tab:) changes the selected tab`() {
			let model = TabsModel()

			model.show(tab: .activity)

			#expect(model.selectedTab == .activity)
		}

		@Test func `show(tab:) with the already-selected tab is a no-op`() {
			let model = TabsModel()

			model.show(tab: .placesNearby)

			#expect(model.selectedTab == .placesNearby)
		}
	}

	struct Instrumentation {
		@Test func `switching tabs leaves an interaction breadcrumb`() {
			let recorder = RecordingDestination()
			let model = TabsModel(observability: ObservabilityPipeline(destinations: [recorder]))

			model.show(tab: .activity)

			#expect(recorder.breadcrumbs.contains(.interaction(description: "selectTab")))
		}

		@Test func `re-selecting the current tab leaves no breadcrumb`() {
			let recorder = RecordingDestination()
			let model = TabsModel(observability: ObservabilityPipeline(destinations: [recorder]))

			model.show(tab: .placesNearby)

			#expect(recorder.breadcrumbs.isEmpty)
		}
	}
}
