import FeedUI
import SecretDJDomain

/// Wraps another ``FeedUI/FeedLoading``, applying
/// ``VenueSocialLinksOrdering`` to every fetched feed before
/// ``FeedUI/FeedScreenModel`` ever sees it — so the existing generic
/// promotion rendering (S3.2) needs no venue-specific branch; it just
/// renders whatever the reordered/capped section already contains.
struct SocialOrderingFeedLoading: FeedLoading {
	private let base: any FeedLoading

	init(base: any FeedLoading) {
		self.base = base
	}

	func load(page: Int?) async throws -> SectionList {
		try await VenueSocialLinksOrdering.prioritized(base.load(page: page))
	}
}
