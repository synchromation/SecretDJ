import SwiftUI

/// Dispatches one visible section to its concrete layout by
/// ``FeedSectionKind`` — never `AnyView`, so type erasure never destroys
/// `ForEach`'s structural identity (lazy-sections skill). Thin wrapper:
/// previewed through ``FeedView``'s previews.
struct FeedSectionView: View {
	let section: FeedDisplayModel.VisibleSection

	var body: some View {
		switch section.kind {
		case .list: FeedListSection(items: section.items)
		case .carousel: FeedCarouselSection(items: section.items)
		case .grid: FeedGridSection(items: section.items)
		case .hidden:
			// Unreachable: FeedDisplayModel routes hidden-kind sections to
			// `hiddenSections`, never `visibleSections`. Handled explicitly
			// (not `default`) so a future FeedSectionKind case fails to
			// compile here instead of silently rendering nothing.
			EmptyView()
		}
	}
}
