import Foundation

/// A feed screen's per-instance opt-ins for ``FeedScreenModel`` behavior —
/// which legacy providers enabled auto-refresh and infinite scroll, and how
/// each reports a mid-pagination hash change (LEGACY.md "The feed engine").
public struct FeedConfiguration: Sendable {
	/// Auto-refresh cadence — LEGACY.md's "Refresh rules": a 20-second base
	/// interval, tightened to 3 seconds until the app's first GPS fix this
	/// launch is about 12 seconds old (bug #181's workaround).
	public struct AutoRefresh: Sendable {
		public let baseCadence: Duration
		public let tightenedCadence: Duration
		/// How young the first GPS fix must be for ``tightenedCadence`` to
		/// apply; at or past this age, refreshing falls back to
		/// ``baseCadence``.
		public let tightenedWindow: Duration

		public init(
			baseCadence: Duration = .seconds(20),
			tightenedCadence: Duration = .seconds(3),
			tightenedWindow: Duration = .seconds(12),
		) {
			self.baseCadence = baseCadence
			self.tightenedCadence = tightenedCadence
			self.tightenedWindow = tightenedWindow
		}
	}

	/// `nil` opts this screen out of auto-refresh entirely, matching the
	/// legacy providers that never polled; a value opts in at that cadence.
	public let autoRefresh: AutoRefresh?
	/// Whether scrolling near the bottom fetches another page — the legacy
	/// providers with infinite scroll (music selection, digest, mood).
	public let paginationEnabled: Bool
	/// How a mid-pagination hash mismatch is reported —
	/// ``FeedChangeDetector/Policy/surfaceChange`` for the consumer app,
	/// ``FeedChangeDetector/Policy/reloadInPlace`` for the kiosk digest.
	public let changePolicy: FeedChangeDetector.Policy
	/// `nil` (every consumer-app screen) leaves a failed load's recovery to
	/// the person looking at the phone — pull-to-refresh or the error
	/// surface's own "Try Again" button, both already unconditional. A
	/// value arms ``FeedScreenModel``'s unattended backoff retry (PLAN.md
	/// S7.7: "an unattended iPad heals without staff") once ``FeedScreenModel/phase``
	/// shows an error — the kiosk digest/jukebox/songs-for-artist screens
	/// are the only callers that set this.
	public let errorRecovery: ErrorRecovery?

	public init(
		autoRefresh: AutoRefresh?,
		paginationEnabled: Bool,
		changePolicy: FeedChangeDetector.Policy,
		errorRecovery: ErrorRecovery? = nil,
	) {
		self.autoRefresh = autoRefresh
		self.paginationEnabled = paginationEnabled
		self.changePolicy = changePolicy
		self.errorRecovery = errorRecovery
	}

	/// A backoff schedule for ``FeedScreenModel``'s unattended error
	/// recovery (PLAN.md S7.7). Retries never stop trying — only the wait
	/// between them grows, doubling each failed attempt up to
	/// ``maximumInterval`` and holding there: an unattended kiosk has no
	/// staff around to eventually give up and go find, so "keep trying,
	/// capped" is the only sensible failure mode (unlike a person-facing
	/// retry button, which only ever fires once per tap).
	public struct ErrorRecovery: Sendable {
		public let initialInterval: Duration
		public let maximumInterval: Duration

		public init(initialInterval: Duration = .seconds(5), maximumInterval: Duration = .seconds(300)) {
			self.initialInterval = initialInterval
			self.maximumInterval = maximumInterval
		}
	}
}
