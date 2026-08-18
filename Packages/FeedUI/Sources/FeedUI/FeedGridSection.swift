import DesignSystem
import SwiftUI

/// A `FeedSectionKind/grid` section's layout — a multi-column tile grid, the
/// legacy `matrix*` templates. Thin wrapper: previewed through ``FeedView``'s
/// previews (lazy-sections skill).
struct FeedGridSection: View {
	let items: [FeedDisplayItem]

	/// `.adaptive` handles iPhone/iPad widths; the minimum itself is scaled
	/// so tiles keep room for accessibility-sized text.
	@ScaledMetric(relativeTo: .caption)
	private var minimumTileWidth: CGFloat = 104

	private var columns: [GridItem] {
		[GridItem(.adaptive(minimum: minimumTileWidth), spacing: Spacing.medium)]
	}

	var body: some View {
		LazyVGrid(columns: columns, spacing: Spacing.medium) {
			ForEach(items) { FeedPlaceholderCell(item: $0) }
		}
		.padding(.horizontal, Spacing.medium)
	}
}
