import SwiftUI

struct ListSection: View {
	let items: [FeedItem]

	var body: some View {
		// NOTE: inside an already-lazy vertical feed, an inner LazyVStack adds
		// little — its rows materialise when the section nears the viewport
		// anyway, and each lazy container adds bookkeeping. With small row
		// counts a plain VStack often profiles the same or marginally better.
		// Kept lazy here to mirror the source demo; measure both in your real feed.
		LazyVStack(spacing: 10) {
			ForEach(items) { RowCell(item: $0) }
		}
		.padding(.horizontal, 16)
	}
}
