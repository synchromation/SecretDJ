import FeedUI
import Foundation
import Observability
import Observation
import SecretDJDomain

/// Drives the kiosk's now-playing header (PLAN.md S7.4): polls `playhistory`
/// at the legacy 20-second cadence (LEGACY.md "Home screen: Now Playing +
/// jukebox wall"), turning each response into a ``KioskNowPlayingDisplay``.
/// Mirrors ``FeedUI/FeedScreenModel``'s own auto-refresh shape — the same
/// ``FeedUI/FeedRefreshClock`` seam, the same schedule-cancel-reschedule
/// pattern — rather than reinventing polling, even though this isn't a
/// ``FeedUI/FeedScreenModel`` itself: the header renders one fixed-position
/// song, never a scrolling list, so it has no use for pagination/hash
/// tracking/action routing.
///
/// Also resolves the venue's real display name, opportunistically: legacy's
/// kiosk sign-in response carries only the venue id
/// (`SessionStore+KioskAuthenticatedSession`'s doc comment), and this is the
/// first feed ``KioskHomeView`` fetches after signing in, so whenever a
/// response happens to carry a `hiddenVenueDetails` section, its name is
/// handed to ``onVenueNameResolved`` for the caller to fold into
/// ``SecretDJAPI/SessionStore``.
@MainActor
@Observable
final class KioskNowPlayingModel {
	/// The legacy cadence: `playhistory` polls "every 20 seconds"
	/// (LEGACY.md), with no GPS-tightening rule — that's a consumer-only
	/// workaround (bug #181) with no kiosk equivalent (a fixed venue iPad
	/// never needs a location fix).
	static let cadence: Duration = .seconds(20)

	private(set) var display: KioskNowPlayingDisplay = .idle

	private let loader: any FeedLoading
	private let clock: any FeedRefreshClock
	private let onVenueNameResolved: (String) -> Void
	private let observability: ObservabilityPipeline

	private var refreshToken: FeedRefreshClockToken?

	init(
		loader: any FeedLoading,
		clock: any FeedRefreshClock = SystemFeedRefreshClock(),
		onVenueNameResolved: @escaping (String) -> Void = { _ in },
		observability: ObservabilityPipeline = .disabled,
	) {
		self.loader = loader
		self.clock = clock
		self.onVenueNameResolved = onVenueNameResolved
		self.observability = observability
	}

	/// Fetches the feed's current state and starts polling at ``cadence``.
	/// Safe to call more than once (a re-triggered `.task`) — scheduling
	/// replaces any previous tick rather than doubling up, matching
	/// ``FeedUI/FeedScreenModel/start()``'s own contract.
	func start() async {
		await tick()
		scheduleNextTick()
	}

	/// A user-initiated or programmatic refresh, outside the polling cadence
	/// — used by tests; production code only ever calls ``start()``.
	func refresh() async {
		await tick()
	}

	/// Cancels the pending poll — call from the view's `onDisappear`, though
	/// in practice the header never disappears while the kiosk is signed in.
	func stop() {
		refreshToken?.cancel()
		refreshToken = nil
	}

	private func tick() async {
		do {
			let sectionList = try await loader.load(page: nil)
			let displayModel = FeedDisplayModel(sectionList: sectionList)
			display = KioskNowPlayingDisplay(song: displayModel.currentSong)

			if let name = displayModel.venueDetails?.name, !name.isEmpty {
				onVenueNameResolved(name)
			}
		} catch {
			// A failed poll keeps showing whatever was last known — legacy's
			// own header has no error surface of its own (it just misses an
			// update and tries again at the next tick), and the venue's real
			// music keeps playing regardless of this screen's own network luck.
			observability.report(error, category: "KioskNowPlaying")
		}
	}

	private func scheduleNextTick() {
		refreshToken?.cancel()
		refreshToken = clock.schedule(after: Self.cadence) { [weak self] in
			await self?.autoRefreshTick()
		}
	}

	private func autoRefreshTick() async {
		await tick()
		scheduleNextTick()
	}
}
