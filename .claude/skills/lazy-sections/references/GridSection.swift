import SwiftUI

struct GridSection: View {
	let items: [FeedItem]

	/// .adaptive handles iPhone/iPad widths; a fixed column count (e.g. three
	/// .flexible columns) is marginally cheaper to solve. The minimum itself
	/// is scaled so tiles keep room for accessibility-sized text.
	@ScaledMetric(relativeTo: .caption)
	private var minimumTileWidth: CGFloat = 104

	private var columns: [GridItem] {
		[GridItem(.adaptive(minimum: minimumTileWidth), spacing: 12)]
	}

	var body: some View {
		LazyVGrid(columns: columns, spacing: 12) {
			ForEach(items) { TileCell(item: $0) }
		}
		.padding(.horizontal, 16)
	}
}
