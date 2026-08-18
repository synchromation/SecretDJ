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

	public init(autoRefresh: AutoRefresh?, paginationEnabled: Bool, changePolicy: FeedChangeDetector.Policy) {
		self.autoRefresh = autoRefresh
		self.paginationEnabled = paginationEnabled
		self.changePolicy = changePolicy
	}
}
