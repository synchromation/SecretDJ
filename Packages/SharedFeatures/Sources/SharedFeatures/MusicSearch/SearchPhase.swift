/// Which DesignSystem-style state ``MusicSearchScreen`` shows for the
/// current query/mode. Deliberately smaller than `FeedUI/FeedLoadPhase`
/// (no `.error(offline:)` distinction — a search failure has no pull-to-
/// refresh surface to retry from, so the caller's own copy covers both
/// causes with one message).
public enum SearchPhase: Sendable, Equatable {
	/// No query has produced results yet — the pre-search state, and where
	/// an emptied track-mode query returns to.
	case idle
	/// A track-mode search is in flight (LEGACY.md: "server round-trip per
	/// keystroke"). Artist-mode filtering is synchronous and never shows
	/// this, except while its one-time index fetch is still in flight.
	case searching
	case loaded
	/// A search or the artist index fetch completed with nothing to show.
	case empty
	case error
}
