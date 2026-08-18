import DesignSystem
import SwiftUI

/// A `FeedSectionKind/list` section's layout — a vertically stacked row per
/// item. Thin wrapper: previewed through ``FeedView``'s previews, the one
/// sanctioned exception to swiftui-views' every-file preview rule
/// (lazy-sections skill).
struct FeedListSection: View {
	let items: [FeedDisplayItem]
	/// Applied at this ForEach level, never carried on `FeedCellProps` —
	/// cell props stay immutable values (lazy-sections' no-closures-in-cell-
	/// props rule).
	var onItemTap: ((FeedDisplayItem) -> Void)?

	var body: some View {
		// Kept lazy to mirror the lazy-sections exemplar; inside an
		// already-lazy vertical feed a plain VStack often profiles the same
		// or marginally better for small row counts — measure in S3.5.
		LazyVStack(spacing: Spacing.small) {
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
		.padding(.horizontal, Spacing.medium)
	}

	/// Never AnyView (lazy-sections skill) — exhaustive over every
	/// FeedCellProps case so a new payload variant fails to compile here
	/// instead of silently rendering nothing. .controlTile is unreachable in
	/// a list-kind section (mood tiles are matrixControlLarge-only, which
	/// maps to grid).
	@ViewBuilder
	private func cell(for item: FeedDisplayItem) -> some View {
		switch item.cellProps {
		case .media(let props):
			MediaRowCell(
				artworkURL: props.artworkURL,
				placeholderIcon: props.placeholderIcon,
				title: props.title,
				subtitle: props.subtitle,
				accessory: props.accessory,
			)
		case .person(let props):
			PersonRowCell(
				avatarURL: props.avatarURL,
				name: props.name,
				subtitle: props.subtitle,
				accessory: props.accessory,
			)
		case .venue(let props):
			VenueRowCell(
				artworkURL: props.artworkURL,
				name: props.name,
				address: props.address,
				hasJukebox: props.hasJukebox,
				isCheckedIn: props.isCheckedIn,
			)
		case .event(let props):
			EventRowCell(icon: props.icon, lines: props.lines)
		case .topUp(let props):
			TopUpRowCell(title: props.title, subtitle: props.subtitle, priceText: props.priceText)
		case .promotion(let props):
			PromotionCell(artworkURL: props.artworkURL, caption: props.caption)
		case .controlTile(let props):
			TileCell(artwork: .flatColor(props.color, icon: props.icon), title: props.title)
		case .dropped:
			EmptyView()
		}
	}
}
