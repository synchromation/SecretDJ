import Foundation
import Observability
import SecretDJDomain

/// Drives a backend-driven feed screen: initial load, pull-to-refresh,
/// opt-in auto-refresh, opt-in unattended error recovery, infinite scroll,
/// hash-change detection, and the load state DesignSystem's surfaces
/// render — composing ``FeedChangeDetector``, ``FeedDisplayModel``, and
/// ``FeedActionRouter`` behind one reusable model both apps' feed screens
/// wrap (PLAN.md S3.4; the kiosk's unattended recovery is S7.7).
@MainActor
@Observable
public final class FeedScreenModel {
	/// Drives which DesignSystem surface ``FeedScreen`` shows.
	public private(set) var phase: FeedLoadPhase = .loading
	/// The feed's current sections, ready for ``FeedView``. Accumulates
	/// across ``loadNextPage()`` calls; replaced wholesale by
	/// ``start()``/``refresh()``/auto-refresh.
	public private(set) var visibleSections: [FeedDisplayModel.VisibleSection] = []
	/// Incrementing this snaps ``FeedView`` back to the top. Bumped by a
	/// user-visible full reload (initial load, pull-to-refresh); a silent
	/// auto-refresh tick never bumps it, so it doesn't yank the user's
	/// scroll position.
	public private(set) var generation = 0
	/// Whether a further page is currently loading — guards
	/// ``loadNextPage()`` against concurrent calls and lets the view show a
	/// footer spinner.
	public private(set) var isLoadingNextPage = false
	/// Whether infinite scroll has more pages to fetch. Resets to `true` on
	/// every full reload and flips to `false` once a page comes back empty
	/// (the legacy end-of-feed signal).
	public private(set) var hasMorePages = true
	/// Set when a paginated load detects the legacy "jukebox changed"
	/// condition; `nil` until the first occurrence. The app observes this to
	/// show its toast and decide what "reload" means for its navigation
	/// stack.
	public private(set) var jukeboxChangedEvent: JukeboxChangedEvent?
	/// The current feed's `hiddenVenueDetails` payload
	/// (``FeedDisplayModel/venueDetails``), when it carried one — the venue
	/// screen's header data (S6.2). `nil` before the first load and for any
	/// feed with no such section; republished after every full load
	/// (initial/pull-to-refresh/auto-refresh), same timing as `jukeboxList`.
	public private(set) var venueDetails: Venue?
	/// The current feed's `hiddenProfile` payload
	/// (``FeedDisplayModel/profile``), when it carried one — the profile
	/// screen's header data (S6.6), sourced identically whether the feed is
	/// showing the signed-in user's own profile or someone else's
	/// (`persondetails` returns the same section shape for both — LEGACY.md
	/// "Tab 3 — Profile"). `nil` before the first load and for any feed with
	/// no such section; republished after every full load, same timing as
	/// ``venueDetails``.
	public private(set) var personDetails: Person?
	/// The current feed's nav-bar action buttons
	/// (``FeedDisplayModel/actionButtons``) — legacy's `ActionBarButtonProvider`
	/// rendering (S6.12), republished after every full load (initial/pull-to-refresh/
	/// auto-refresh), same timing as ``venueDetails``/``personDetails``; a
	/// paginated page never updates this, matching `FeedInteractor.fetchFeed`
	/// being the only caller of legacy's `show(sectionList:)` (`fetchNextFeedPage`
	/// never is).
	public private(set) var actionButtons: [Action] = []

	private let loader: any FeedLoading
	private let router: FeedActionRouter
	private let configuration: FeedConfiguration
	private let gpsFixAge: (any GPSFixAgeProviding)?
	private let clock: any FeedRefreshClock
	private let observability: ObservabilityPipeline

	private var changeDetector: FeedChangeDetector
	private var jukeboxList: [Jukebox] = []
	private var nextPage = 1
	private var refreshToken: FeedRefreshClockToken?
	private var recoveryToken: FeedRefreshClockToken?
	/// How many unattended recovery retries have fired in the current error
	/// streak — `0` outside one (idle, loaded, or a fresh error nobody has
	/// retried yet). Feeds ``recoveryInterval(forAttempt:initial:maximum:)``
	/// and gates the coarse breadcrumb in ``recoveryTick(attempt:)``; reset
	/// to `0` the moment a load succeeds again.
	private var recoveryAttempt = 0

	public init(
		loader: any FeedLoading,
		router: FeedActionRouter,
		configuration: FeedConfiguration,
		gpsFixAge: (any GPSFixAgeProviding)? = nil,
		clock: any FeedRefreshClock = SystemFeedRefreshClock(),
		observability: ObservabilityPipeline = .disabled,
	) {
		self.loader = loader
		self.router = router
		self.configuration = configuration
		self.gpsFixAge = gpsFixAge
		self.clock = clock
		self.observability = observability
		changeDetector = FeedChangeDetector(policy: configuration.changePolicy)
	}

	/// Fetches the feed's first page and, if ``FeedConfiguration/autoRefresh``
	/// opts in, starts ticking at the legacy cadence. Safe to call more than
	/// once (e.g. a re-triggered `.task`) — auto-refresh scheduling replaces
	/// any previous tick rather than doubling up.
	public func start() async {
		await performFullLoad(resetsScrollPosition: true)
		scheduleNextAutoRefresh()
	}

	/// A user-initiated pull-to-refresh. Re-fetches the first page; existing
	/// content stays on screen (``phase`` doesn't drop back to
	/// ``FeedLoadPhase/loading``) unless nothing had loaded yet.
	public func refresh() async {
		await performFullLoad(resetsScrollPosition: true)
	}

	/// Cancels any pending auto-refresh tick and any pending unattended
	/// recovery retry — call from the view's `onDisappear` so a
	/// backgrounded screen stops polling and stops retrying.
	public func stop() {
		refreshToken?.cancel()
		refreshToken = nil
		recoveryToken?.cancel()
		recoveryToken = nil
	}

	/// Fetches the next page for infinite scroll. A no-op when pagination is
	/// disabled, a page is already in flight, or ``hasMorePages`` is `false`.
	public func loadNextPage() async {
		guard configuration.paginationEnabled, hasMorePages, !isLoadingNextPage else { return }

		isLoadingNextPage = true
		defer { isLoadingNextPage = false }

		do {
			let sectionList = try await loader.load(page: nextPage)
			apply(page: sectionList)
		} catch {
			// No legacy pagination-failure UI: a later scroll can retry, since
			// hasMorePages/nextPage are left untouched.
		}
	}

	/// Routes a feed cell tap to its ``FeedActionOutcome``, correlating a
	/// song's `jukeboxGotoItem` action through the current hidden jukebox
	/// list (the deferred S3.3 item — `FeedActionRouter` needs that context,
	/// which only this model, not the stateless router, holds).
	public func outcome(forTap item: FeedDisplayItem) -> FeedActionOutcome? {
		router.outcome(forTap: item, jukeboxList: jukeboxList)
	}

	/// Routes a tap on one of ``actionButtons`` to its ``FeedActionOutcome``
	/// — the bar-button counterpart of ``outcome(forTap:)``
	/// (`ActionBarButtonItem.buttonTapped()`).
	public func outcome(forBarButton action: Action) -> FeedActionOutcome? {
		router.outcome(forBarButton: action)
	}

	// MARK: - Loading

	private func performFullLoad(resetsScrollPosition: Bool) async {
		let showsLoadingState = visibleSections.isEmpty
		if showsLoadingState {
			phase = .loading
		}

		do {
			let sectionList = try await loader.load(page: nil)
			apply(sectionList, resetsScrollPosition: resetsScrollPosition)
			cancelRecovery()
		} catch {
			// A background refresh failing while content is already showing
			// keeps that content rather than replacing it with an error surface.
			guard showsLoadingState else { return }
			phase = .error(offline: isOffline(error))
			scheduleRecovery()
		}
	}

	private func apply(_ sectionList: SectionList, resetsScrollPosition: Bool) {
		changeDetector.establish(sectionList.hash)

		let displayModel = FeedDisplayModel(sectionList: sectionList)
		visibleSections = displayModel.visibleSections
		jukeboxList = displayModel.jukeboxList
		venueDetails = displayModel.venueDetails
		personDetails = displayModel.profile
		actionButtons = displayModel.actionButtons
		nextPage = 1
		hasMorePages = true
		phase = displayModel.visibleSections.isEmpty ? .empty : .loaded

		if resetsScrollPosition {
			generation += 1
		}
	}

	private func apply(page sectionList: SectionList) {
		switch changeDetector.page(sectionList.hash) {
		case .jukeboxChanged:
			jukeboxChangedEvent = JukeboxChangedEvent(id: (jukeboxChangedEvent?.id ?? 0) + 1)

		case .unchanged:
			appendPage(sectionList)
			nextPage += 1
		}
	}

	private func appendPage(_ sectionList: SectionList) {
		let itemCount = sectionList.sections.reduce(0) { $0 + $1.items.count }
		guard itemCount > 0 else {
			hasMorePages = false
			return
		}

		let pageModel = FeedDisplayModel(sectionList: sectionList)
		var merged = visibleSections

		for pageSection in pageModel.visibleSections {
			if let index = merged.firstIndex(where: { $0.id == pageSection.id }) {
				let existing = merged[index]
				// Overlapping page windows (the server re-sends an item near a
				// page boundary) would otherwise duplicate that item's id
				// within the section — skip anything already present instead.
				let existingItemIDs = Set(existing.items.map(\.id))
				let newItems = pageSection.items.filter { !existingItemIDs.contains($0.id) }
				merged[index] = FeedDisplayModel.VisibleSection(
					id: existing.id,
					kind: existing.kind,
					title: existing.title,
					items: existing.items + newItems,
				)
			} else {
				merged.append(pageSection)
			}
		}

		visibleSections = merged
	}

	private func isOffline(_ error: any Error) -> Bool {
		guard let urlError = error as? URLError else { return false }
		return urlError.code == .notConnectedToInternet || urlError.code == .networkConnectionLost
	}

	// MARK: - Auto-refresh

	private func scheduleNextAutoRefresh() {
		refreshToken?.cancel()
		refreshToken = nil

		guard let autoRefresh = configuration.autoRefresh else { return }

		refreshToken = clock.schedule(after: cadence(for: autoRefresh)) { [weak self] in
			await self?.autoRefreshTick()
		}
	}

	private func autoRefreshTick() async {
		await performFullLoad(resetsScrollPosition: false)
		scheduleNextAutoRefresh()
	}

	/// The legacy cadence rule: tightened until the first GPS fix is old
	/// enough, base otherwise. A screen with no ``gpsFixAge`` provider never
	/// tightens — it isn't opting into GPS-aware behavior, so it just
	/// refreshes steadily at ``FeedConfiguration/AutoRefresh/baseCadence``.
	private func cadence(for autoRefresh: FeedConfiguration.AutoRefresh) -> Duration {
		guard let gpsFixAge else {
			return autoRefresh.baseCadence
		}

		guard let age = gpsFixAge.firstFixAge(), age >= autoRefresh.tightenedWindow else {
			return autoRefresh.tightenedCadence
		}

		return autoRefresh.baseCadence
	}

	// MARK: - Unattended error recovery (PLAN.md S7.7)

	/// Arms (or re-arms) the backoff retry once ``phase`` has just become
	/// an error — a no-op when ``FeedConfiguration/errorRecovery`` opts
	/// this screen out. Any already-pending retry is replaced rather than
	/// left to double-fire alongside a new one, the same guard
	/// ``scheduleNextAutoRefresh()`` applies to its own token; a retry
	/// triggered by a person's own pull-to-refresh failing counts toward
	/// the same backoff series as an unattended tick — there's no reason
	/// to forgive the streak just because a human happened to tap in the
	/// middle of it.
	private func scheduleRecovery() {
		guard let policy = configuration.errorRecovery else { return }

		recoveryToken?.cancel()
		recoveryAttempt += 1
		let attempt = recoveryAttempt
		let interval = Self.recoveryInterval(
			forAttempt: attempt,
			initial: policy.initialInterval,
			maximum: policy.maximumInterval,
		)

		recoveryToken = clock.schedule(after: interval) { [weak self] in
			await self?.recoveryTick(attempt: attempt)
		}
	}

	/// Cancels any pending retry and resets the backoff streak — called
	/// once a load actually succeeds. Only breadcrumbs "recovered" when
	/// there was a streak to recover from, so an ordinary happy-path load
	/// (which has never failed) stays silent.
	private func cancelRecovery() {
		recoveryToken?.cancel()
		recoveryToken = nil

		if recoveryAttempt > 0 {
			observability.interaction("feedErrorRecoveryRecovered")
		}
		recoveryAttempt = 0
	}

	/// One backoff-scheduled retry: re-runs the exact same full load a
	/// person's own "Try Again" button would (``refresh()``'s own path),
	/// so a retry that succeeds clears the error surface exactly as if
	/// someone had tapped it, and a retry that fails re-arms the next,
	/// longer wait via ``scheduleRecovery()``.
	private func recoveryTick(attempt: Int) async {
		recoveryToken = nil

		// Coarse breadcrumbs only (PLAN.md S7.7: "not per-attempt spam") —
		// the first retry of a streak, then every `recoveryBreadcrumbStride`th
		// after that, is enough to see a screen stuck retrying in telemetry
		// without flooding it once backoff settles at its capped cadence.
		if attempt == 1 || attempt.isMultiple(of: Self.recoveryBreadcrumbStride) {
			observability.interaction("feedErrorRecoveryRetry")
		}

		await performFullLoad(resetsScrollPosition: true)
	}

	private static let recoveryBreadcrumbStride = 5

	/// Exponential backoff, doubling each attempt from `initial` and
	/// holding at `maximum` rather than growing without bound — pure and
	/// `static` so it's directly testable without a hosted model
	/// (mirrors `DesignSystem/SectionIndexStrip`'s own testable geometry
	/// math). `attempt` is 1-based: the first retry after an error waits
	/// `initial`, the second waits `initial * 2`, and so on.
	nonisolated static func recoveryInterval(
		forAttempt attempt: Int,
		initial: Duration,
		maximum: Duration,
	) -> Duration {
		guard attempt > 1 else { return initial }

		// The exponent is capped well below where `1 << exponent` could
		// overflow — irrelevant to any real backoff (it saturates at
		// `maximum` within a handful of doublings), but keeps this total
		// for a pathologically long attempt count during an all-day soak.
		let exponent = min(attempt - 1, 20)
		let scaled = initial.secondsAsDouble * Double(1 << exponent)
		return .seconds(min(scaled, maximum.secondsAsDouble))
	}
}

extension Duration {
	fileprivate var secondsAsDouble: Double {
		Double(components.seconds) + Double(components.attoseconds) / 1e18
	}
}
