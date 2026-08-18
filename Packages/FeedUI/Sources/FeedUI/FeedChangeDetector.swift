import SecretDJDomain

/// Tracks a feed's server ``FeedHash`` across its lifecycle and reports
/// whether the jukebox changed underneath it — LEGACY.md "Consumer app:
/// features and flows" → "The feed engine" and the kiosk digest's hash
/// branch.
///
/// A feed's first content (initial load) and any full reload (pull-to-refresh,
/// re-opening a page) call ``establish(_:)``, which adopts the server's hash
/// unconditionally — there is nothing stale to reconcile because the whole
/// feed was just refetched. Fetching a further page of an already-loaded feed
/// calls ``page(_:)``, which compares the new page's hash against the tracked
/// one: a mismatch means the pub changed the jukebox mid-scroll, and what
/// happens next is decided by ``policy``.
public struct FeedChangeDetector: Sendable {
	/// How a mid-pagination hash change is reported. Detection itself (does
	/// the hash still match?) is identical under both policies — only the
	/// reported outcome differs.
	public enum Policy: Sendable {
		/// The consumer app: a mismatch is surfaced as ``Outcome/jukeboxChanged``
		/// so the caller can show the "jukebox changed" toast and reload (S3.4).
		case surfaceChange

		/// The kiosk digest: a mismatch is absorbed silently — the detector
		/// adopts the new hash and reports ``Outcome/unchanged`` — rather than
		/// erroring while jukeboxes come and go on the venue's own screen (S7.4).
		case reloadInPlace
	}

	/// The result of comparing a page's hash against the tracked one.
	public enum Outcome: Sendable, Equatable {
		/// The page's hash matched the tracked hash, or the policy absorbed a
		/// mismatch in place.
		case unchanged

		/// The page's hash didn't match the tracked hash and the policy
		/// surfaces mismatches: the feed changed mid-pagination and the
		/// caller should reload.
		case jukeboxChanged
	}

	/// The hash this detector currently tracks, or `nil` before any load has
	/// been established.
	public private(set) var hash: FeedHash?

	/// How this detector reports a mid-pagination hash mismatch.
	public let policy: Policy

	/// Creates a detector with no tracked hash yet.
	public init(policy: Policy) {
		self.policy = policy
	}

	/// Adopts `hash` unconditionally, as the initial load or a full refresh
	/// of the feed. Always leaves the detector clean, regardless of any
	/// previously tracked hash.
	public mutating func establish(_ hash: FeedHash) {
		self.hash = hash
	}

	/// Compares `hash` against the tracked hash for a further page of an
	/// already-loaded feed.
	///
	/// With no tracked hash yet (a page arriving before any ``establish(_:)``
	/// call), this establishes it instead of reporting a change.
	@discardableResult
	public mutating func page(_ hash: FeedHash) -> Outcome {
		guard let current = self.hash, current != hash else {
			self.hash = hash
			return .unchanged
		}

		switch policy {
		case .surfaceChange:
			return .jukeboxChanged
		case .reloadInPlace:
			self.hash = hash
			return .unchanged
		}
	}
}
