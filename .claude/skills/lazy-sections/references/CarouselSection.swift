import SwiftUI

struct CarouselSection: View {
	let items: [FeedItem]

	/// Same base value and relativeTo text style as CardCell.baseHeight —
	/// both resolve from the same scale factor in the same environment, so
	/// the two heights can never drift even though each view holds its own
	/// copy.
	@ScaledMetric(relativeTo: .footnote)
	private var cardHeight = CardCell.baseHeight

	var body: some View {
		ScrollView(.horizontal) {
			LazyHStack(spacing: 12) {
				// Each CardCell stays its own accessibility element, so the
				// carousel remains individually navigable — VoiceOver users
				// swipe through cards one at a time, same as any other list.
				ForEach(items) { CardCell(item: $0) }
			}
			.scrollTargetLayout()
		}
		.contentMargins(.horizontal, 16, for: .scrollContent)
		.scrollTargetBehavior(.viewAligned)
		.scrollIndicators(.hidden)
		// Fixed (scaled) height: the vertical feed never has to measure
		// carousel content to lay itself out — a big win for smooth
		// scrolling.
		.frame(height: cardHeight)
	}
}
