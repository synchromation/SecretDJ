import DesignSystem
import SwiftUI

/// A `FeedSectionKind/carousel` section's layout — a horizontally scrolling
/// row of cards, the legacy `horizontal*`/nested-"container" templates.
/// Thin wrapper: previewed through ``FeedView``'s previews (lazy-sections
/// skill).
struct FeedCarouselSection: View {
	let items: [FeedDisplayItem]

	@ScaledMetric(relativeTo: .subheadline)
	private var cardWidth: CGFloat = 180
	@ScaledMetric(relativeTo: .subheadline)
	private var cardHeight: CGFloat = 120

	var body: some View {
		ScrollView(.horizontal) {
			LazyHStack(spacing: Spacing.medium) {
				// Each cell stays its own accessibility element, so the
				// carousel remains individually navigable — VoiceOver
				// users swipe through cards one at a time, same as any
				// other list.
				ForEach(items) {
					FeedPlaceholderCell(item: $0)
						.frame(width: cardWidth)
				}
			}
			.scrollTargetLayout()
		}
		.contentMargins(.horizontal, Spacing.medium, for: .scrollContent)
		.scrollTargetBehavior(.viewAligned)
		.scrollIndicators(.hidden)
		// Fixed (scaled) height: the vertical feed never has to measure
		// carousel content to lay itself out (lazy-sections' scroll rule).
		.frame(height: cardHeight)
	}
}
