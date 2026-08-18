import DesignSystem
import SwiftUI

/// A `FeedSectionKind/carousel` section's layout — a horizontally scrolling
/// row of cards, the legacy `horizontal*`/nested-"container" templates.
/// Thin wrapper: previewed through ``FeedView``'s previews (lazy-sections
/// skill).
struct FeedCarouselSection: View {
	let items: [FeedDisplayItem]
	/// Applied at this ForEach level, never carried on `FeedCellProps` —
	/// cell props stay immutable values (lazy-sections' no-closures-in-cell-
	/// props rule).
	var onItemTap: ((FeedDisplayItem) -> Void)?

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
				ForEach(items) { item in
					if let onItemTap {
						cell(for: item)
							.frame(width: cardWidth)
							.onTapGesture { onItemTap(item) }
							.accessibilityAddTraits(.isButton)
					} else {
						cell(for: item)
							.frame(width: cardWidth)
					}
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

	/// Today's Template catalog only ever produces .media (horizontalSong),
	/// .person (horizontalVIP/horizontalPerson), and .venue (horizontalAward)
	/// inside a carousel-kind section — .event/.topUp/.promotion/.controlTile/
	/// .dropped are unreachable here, handled explicitly rather than with
	/// `default` so a template that starts feeding one of them into a
	/// carousel fails to compile instead of silently guessing a layout.
	@ViewBuilder
	private func cell(for item: FeedDisplayItem) -> some View {
		switch item.cellProps {
		case .media(let props):
			CardCell(
				artworkURL: props.artworkURL,
				placeholderIcon: props.placeholderIcon,
				title: props.title,
				subtitle: props.subtitle,
			)
		case .person(let props):
			CardCell(
				artworkURL: props.avatarURL,
				placeholderIcon: .profile,
				title: props.name,
				subtitle: props.subtitle,
			)
		case .venue(let props):
			CardCell(
				artworkURL: props.artworkURL,
				placeholderIcon: .venue,
				title: props.name,
				subtitle: props.address,
			)
		case .event,
		     .topUp,
		     .promotion,
		     .controlTile,
		     .dropped:
			EmptyView()
		}
	}
}
