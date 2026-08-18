import SecretDJDomain

/// Fetches a feed screen's content — the seam ``FeedScreenModel`` loads
/// through, so FeedUI takes no dependency on SecretDJAPI. An app implements
/// this over its own `APIClient`, capturing whichever endpoint and venue/user
/// context that screen needs.
public protocol FeedLoading: Sendable {
	/// Fetches one page. `nil` fetches the feed's first page — an initial
	/// load, a pull-to-refresh, or an auto-refresh tick, each of which
	/// discards any previously accumulated pages; a positive page index
	/// (1, 2, 3, ...) extends an already-loaded, pagination-enabled feed by
	/// one page beyond the first, as ``FeedScreenModel/loadNextPage()``
	/// drives infinite scroll.
	func load(page: Int?) async throws -> SectionList
}
