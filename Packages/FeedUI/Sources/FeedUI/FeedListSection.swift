import DesignSystem
import SwiftUI

/// A `FeedSectionKind/list` section's layout — a vertically stacked row per
/// item. Thin wrapper: previewed through ``FeedView``'s previews, the one
/// sanctioned exception to swiftui-views' every-file preview rule
/// (lazy-sections skill).
struct FeedListSection: View {
	let items: [FeedDisplayItem]

	var body: some View {
		// Kept lazy to mirror the lazy-sections exemplar; inside an
		// already-lazy vertical feed a plain VStack often profiles the same
		// or marginally better for small row counts — measure in S3.5.
		LazyVStack(spacing: Spacing.small) {
			ForEach(items) { FeedPlaceholderCell(item: $0) }
		}
		.padding(.horizontal, Spacing.medium)
	}
}
