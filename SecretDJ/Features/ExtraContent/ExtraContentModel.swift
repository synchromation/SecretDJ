import FeedUI
import Observability
import Observation
import SecretDJAPI
import SecretDJDomain

/// The extra-content ticker's state (PLAN.md S6.9): fetches `screen`'s
/// rotating songs/people (`secretdjv3/ExtraContentManager.swift`'s
/// `updateWith(extraContent:)`), rotates ``currentEntry`` on an injected
/// ``ExtraContentClock`` every ten seconds, and tracks whether the ticker is
/// currently shown — driven by the hosting screen's scroll direction
/// (``handleScrollDirectionChange(_:)``, D9: kept verbatim — see
/// ``FeedUI/FeedScrollDirection``'s doc comment for the legacy mapping) and,
/// once, by the first successful fetch (legacy's own `bounceInContainer()`:
/// the ticker's first content always bounces into view regardless of
/// whatever scroll state came before it).
@MainActor
@Observable
final class ExtraContentModel {
	private(set) var entries: [ExtraContentEntry] = []
	private(set) var currentIndex = 0
	/// Whether the ticker is currently shown. Starts `false` — there is
	/// nothing to show before the first fetch resolves — and, from then on,
	/// mirrors legacy's `ExtraContentManager.isShowing`.
	private(set) var isVisible = false

	/// The entry ``TickerView`` renders, or `nil` while ``entries`` is
	/// empty (nothing fetched yet, or the response carried no rotatable
	/// items) — the ticker never has anything to show in that case,
	/// regardless of ``isVisible``.
	var currentEntry: ExtraContentEntry? {
		entries.indices.contains(currentIndex) ? entries[currentIndex] : nil
	}

	private let screen: ExtraContentScreen
	/// The hosting screen's own venue, when it has one — `nil` on Places
	/// Nearby, set on the venue screen. Threads straight into
	/// ``ExtraContentEntry/tapRoute(hostVenueId:)`` (see its doc comment for
	/// why a tapped song always routes to *this* venue, never one the
	/// tapped item itself might name).
	private let hostVenueId: String?
	private let loading: any ExtraContentLoading
	private let clock: any ExtraContentClock
	private let observability: ObservabilityPipeline
	private var rotationToken: ExtraContentClockToken?

	/// The legacy rotation cadence
	/// (`secretdjv3/ExtraContentManager.swift`'s `timeInterval: 10.0`).
	private static let rotationInterval = Duration.seconds(10)

	init(
		screen: ExtraContentScreen,
		hostVenueId: String?,
		loading: any ExtraContentLoading,
		clock: any ExtraContentClock = SystemExtraContentClock(),
		observability: ObservabilityPipeline = .disabled,
	) {
		self.screen = screen
		self.hostVenueId = hostVenueId
		self.loading = loading
		self.clock = clock
		self.observability = observability
	}

	/// Fetches ``screen``'s content and replaces ``entries`` wholesale,
	/// resetting the rotation to its first entry — matching legacy's own
	/// `updateWith(extraContent:)`/`startExtraContentRotation()`, which
	/// always restarts at `currentItemIndex = 0` on a fresh fetch rather
	/// than trying to preserve position across one. A failure never
	/// surfaces to the UI — legacy's `FeedInteractor.fetchExtraContent`
	/// has no failure branch at all, it just never calls
	/// `viewController.show(extraContent:)` — so this only reports the
	/// error for diagnostics and leaves whatever ``entries`` already held.
	func fetch() async {
		do {
			let items = try await loading.loadExtraContent(venueId: hostVenueId, screen: screen)
			let wasEmpty = entries.isEmpty
			entries = items.compactMap(ExtraContentEntry.init(item:))
			currentIndex = 0

			guard !entries.isEmpty else {
				cancelRotation()
				return
			}

			if wasEmpty {
				// Legacy's `bounceInContainer()`: the very first content ever
				// shown forces the ticker visible, independent of whatever
				// scroll state preceded it.
				isVisible = true
			}

			scheduleRotationIfNeeded()
		} catch {
			observability.report(error, category: "ExtraContent")
		}
	}

	/// Shows or hides the ticker in response to the hosting screen's scroll
	/// direction (D9) — see ``FeedUI/FeedScrollDirection``'s doc comment for
	/// exactly which legacy gesture each case reproduces. Also pauses/
	/// resumes rotation: legacy's own timer keeps running while the banner
	/// is scrolled off-screen, but PLAN.md S6.9 asks this rewrite to pause
	/// it instead, so a hidden ticker never silently advances underneath
	/// the user.
	func handleScrollDirectionChange(_ direction: FeedScrollDirection) {
		isVisible = direction == .towardStart
		scheduleRotationIfNeeded()
	}

	/// Routes the current entry's tap, breadcrumbing the interaction first
	/// — legacy's `tappedExtraContentView()` always notifies its delegate on
	/// tap, whether or not that produces a real destination (see
	/// ``ExtraContentEntry/tapRoute(hostVenueId:)``'s doc comment for when
	/// it doesn't). Returns `nil` when there's nothing to tap (no current
	/// entry) or the current entry's kind has no destination on this
	/// screen.
	func tapCurrentEntry() -> ExtraContentTapRoute? {
		guard let currentEntry else { return nil }

		observability.interaction("tapExtraContent")
		return currentEntry.tapRoute(hostVenueId: hostVenueId)
	}

	/// Cancels rotation — call when the hosting screen disappears, mirroring
	/// legacy's `stopExtraContent()` (`FeedViewController`'s own
	/// `deinit`/dismissal path).
	func stop() {
		cancelRotation()
	}

	private func scheduleRotationIfNeeded() {
		guard isVisible, !entries.isEmpty else {
			cancelRotation()
			return
		}

		guard rotationToken == nil else { return }

		rotationToken = clock.schedule(after: Self.rotationInterval) { [weak self] in
			self?.rotate()
		}
	}

	private func cancelRotation() {
		rotationToken?.cancel()
		rotationToken = nil
	}

	private func rotate() {
		rotationToken = nil

		guard !entries.isEmpty else { return }

		// Legacy's `updateDisplayedExtraContent()`: advance, wrapping back
		// to the first entry past the last.
		currentIndex = entries.count > currentIndex + 1 ? currentIndex + 1 : 0
		scheduleRotationIfNeeded()
	}
}
