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

	/// Same base value and relativeTo text style as `CardCell.baseHeight` —
	/// both resolve from the same scale factor in the same environment, so
	/// the two heights can never drift even though each view holds its own
	/// copy (lazy-sections' can-never-drift comment pattern). Width isn't
	/// scaled here at all: `CardCell` already sizes itself from
	/// `CardCell.baseWidth`, so a second, independently scaled copy of the
	/// same width is exactly the bug this fixes — cards painting past a
	/// wider carousel band, with snap targets that don't match the card
	/// edges.
	@ScaledMetric(relativeTo: .footnote)
	private var cardHeight = CardCell.baseHeight

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
							.onTapGesture { onItemTap(item) }
							.accessibilityAddTraits(.isButton)
					} else {
						cell(for: item)
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
		switch item.props {
		case .media(let props):
			CardCell(
				artworkURL: props.artworkURL,
				placeholderIcon: props.placeholderIcon,
				title: props.title,
				subtitle: props.subtitle,
			)
		case .person(let props):
			// A card shows a title/subtitle pair, not all four lines — the
			// first two only (unchanged from before `PersonProps` carried
			// every tagged line: `props.lines[0]` is always the name,
			// `personProps(for:text:)`'s own screenName fallback guarantees
			// it).
			CardCell(
				artworkURL: props.avatarURL,
				placeholderIcon: .profile,
				title: props.lines[0],
				subtitle: props.lines.count > 1 ? props.lines[1] : nil,
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
