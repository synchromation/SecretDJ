import Foundation

/// A titled group of items that renders as a list, carousel, or grid.
///
/// `id` must stay stable across data refreshes so the outer feed can diff
/// and animate section-level changes correctly.
struct FeedSection: Identifiable, Hashable {
	let id: UUID
	let kind: SectionKind
	let title: String
	let items: [FeedItem]
}
