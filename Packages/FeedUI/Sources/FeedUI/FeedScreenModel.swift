import Foundation
import SecretDJDomain

/// Drives a backend-driven feed screen: initial load, pull-to-refresh,
/// opt-in auto-refresh, infinite scroll, hash-change detection, and the
/// load state DesignSystem's surfaces render — composing
/// ``FeedChangeDetector``, ``FeedDisplayModel``, and ``FeedActionRouter``
/// behind one reusable model both apps' feed screens wrap (PLAN.md S3.4).
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

	private let loader: any FeedLoading
	private let router: FeedActionRouter
	private let configuration: FeedConfiguration
	private let gpsFixAge: (any GPSFixAgeProviding)?
	private let clock: any FeedRefreshClock

	private var changeDetector: FeedChangeDetector
	private var jukeboxList: [Jukebox] = []
	private var nextPage = 1
	private var refreshToken: FeedRefreshClockToken?

	public init(
		loader: any FeedLoading,
		router: FeedActionRouter,
		configuration: FeedConfiguration,
		gpsFixAge: (any GPSFixAgeProviding)? = nil,
		clock: any FeedRefreshClock = SystemFeedRefreshClock(),
	) {
		self.loader = loader
		self.router = router
		self.configuration = configuration
		self.gpsFixAge = gpsFixAge
		self.clock = clock
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

	/// Cancels any pending auto-refresh tick — call from the view's
	/// `onDisappear` so a backgrounded screen stops polling.
	public func stop() {
		refreshToken?.cancel()
		refreshToken = nil
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

	// MARK: - Loading

	private func performFullLoad(resetsScrollPosition: Bool) async {
		let showsLoadingState = visibleSections.isEmpty
		if showsLoadingState {
			phase = .loading
		}

		do {
			let sectionList = try await loader.load(page: nil)
			apply(sectionList, resetsScrollPosition: resetsScrollPosition)
		} catch {
			// A background refresh failing while content is already showing
			// keeps that content rather than replacing it with an error surface.
			guard showsLoadingState else { return }
			phase = .error(offline: isOffline(error))
		}
	}

	private func apply(_ sectionList: SectionList, resetsScrollPosition: Bool) {
		changeDetector.establish(sectionList.hash)

		let displayModel = FeedDisplayModel(sectionList: sectionList)
		visibleSections = displayModel.visibleSections
		jukeboxList = displayModel.jukeboxList
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
				merged[index] = FeedDisplayModel.VisibleSection(
					id: existing.id,
					kind: existing.kind,
					title: existing.title,
					items: existing.items + pageSection.items,
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
}
