import FeedUI
import Foundation
import SecretDJDomain
import SharedFeatures
import Testing

@testable import SecretDJKiosk

/// PLAN.md S7.7's composition requirement: "the attract/idle system still
/// returns to attract on schedule ... error states must not block attract".
///
/// ``IdleTimerModel`` and ``FeedUI/FeedScreenModel``'s own unattended
/// recovery share no state at all — confirmed here by driving both from
/// independent manual clocks and observing neither one's schedule is
/// perturbed by the other. That's also the real proof for how they compose
/// in the running app: ``AttractIdleOverlayModifier/body(content:)``
/// presents ``AttractScreen`` from an `.overlay` keyed only on
/// ``IdleTimerModel/isShowingAttract``, wrapping whatever `content` the
/// caller passes — the kiosk's own composition root wraps the *entire*
/// signed-in home screen this way (``KioskSkinGateView``'s `.ready` case),
/// so attract sits visually above the digest/jukebox wall regardless of
/// whether that content is loaded, empty, or mid-``FeedLoadPhase/error(offline:)``.
/// A screen's own error surface has no way to suppress an overlay applied
/// two layers above it in the view tree.
enum KioskResilienceCompositionTests {
	@MainActor
	struct `Attract and recovery run independently` {
		@Test func `attract firing does not disturb a pending recovery retry`() async throws {
			let loader = InMemoryFeedLoading()
			let feedClock = ManualFeedRefreshClock()
			let model = makeScreenModel(loader: loader, clock: feedClock)
			let idleClock = ManualIdleTimerClock()
			let idleModel = try IdleTimerModel(config: makeBehavioralConfig(), clock: idleClock)

			await model.start() // fails, arms the first recovery retry
			idleClock.fire(after: .seconds(20)) // the attract countdown elapses

			#expect(idleModel.isShowingAttract)
			#expect(feedClock.pendingCount == 1)
			#expect(model.phase == .error(offline: false))
		}

		@Test func `a recovering screen keeps retrying while attract is showing`() async throws {
			let loader = InMemoryFeedLoading()
			let feedClock = ManualFeedRefreshClock()
			let model = makeScreenModel(loader: loader, clock: feedClock)
			let idleClock = ManualIdleTimerClock()
			let idleModel = try IdleTimerModel(config: makeBehavioralConfig(), clock: idleClock)
			await model.start()
			idleClock.fire(after: .seconds(20))
			#expect(idleModel.isShowingAttract)

			await loader.setOutcome(.success(makeSectionList(items: [makeSong(songId: "1")])), forPage: nil)
			await feedClock.advance()

			#expect(model.phase == .loaded)
		}

		/// The end-to-end story S7.7 asks to verify by name: a screen that
		/// was broken, recovers unattended while attract covers it, and a
		/// customer dismissing attract lands on the now-healthy screen —
		/// never on the error surface they never actually had to see.
		@Test func `dismissing attract after an unattended recovery lands on a healthy screen`() async throws {
			let loader = InMemoryFeedLoading()
			let feedClock = ManualFeedRefreshClock()
			let model = makeScreenModel(loader: loader, clock: feedClock)
			let idleClock = ManualIdleTimerClock()
			let idleModel = try IdleTimerModel(config: makeBehavioralConfig(), clock: idleClock)
			await model.start() // errors
			idleClock.fire(after: .seconds(20)) // attract covers the error

			await loader.setOutcome(.success(makeSectionList(items: [makeSong(songId: "1")])), forPage: nil)
			await feedClock.advance() // unattended retry heals it, still under attract

			idleModel.recordInteraction() // a customer taps to dismiss attract

			#expect(!idleModel.isShowingAttract)
			#expect(model.phase == .loaded)
			#expect(model.visibleSections[0].items.map(\.id) == ["song-1"])
		}
	}
}

// MARK: - Fixtures

@MainActor
private func makeScreenModel(loader: any FeedLoading, clock: any FeedRefreshClock) -> FeedScreenModel {
	FeedScreenModel(
		loader: loader,
		router: FeedActionRouter(installedApps: NoInstalledApps()),
		configuration: FeedConfiguration(
			autoRefresh: nil,
			paginationEnabled: false,
			changePolicy: .reloadInPlace,
			errorRecovery: FeedConfiguration.ErrorRecovery(),
		),
		clock: clock,
	)
}

private func makeBehavioralConfig() throws -> KioskBehavioralConfig {
	try KioskBehavioralConfig(manifest: SkinManifestFixture.make(properties: [
		1020: "https://example.com/attract.html",
		1021: "20",
		1004: "10",
	]))
}

private func makeSectionList(items: [Song]) -> SectionList {
	SectionList(
		hash: FeedHash(rawValue: "h1"),
		sections: [Section(
			itemType: [],
			template: .song,
			title: "",
			index: 0,
			store: nil,
			hash: nil,
			items: items.map(Item.song),
		)],
		actions: [],
	)
}

private func makeSong(songId: String) -> Song {
	Song(
		songId: songId,
		title: "Yellow",
		artist: "Coldplay",
		previewURL: nil,
		likeInfo: LikeInfo(likedByYou: false, info: ""),
		text: "",
		sortIndex: 0,
		action: nil,
		actions: [],
	)
}
