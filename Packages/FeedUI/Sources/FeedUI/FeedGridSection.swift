import DesignSystem
import SwiftUI

/// A `FeedSectionKind/grid` section's layout — a multi-column tile grid, the
/// legacy `matrix*` templates. Thin wrapper: previewed through ``FeedView``'s
/// previews (lazy-sections skill).
struct FeedGridSection: View {
	let items: [FeedDisplayItem]
	/// Applied at this ForEach level, never carried on `FeedCellProps` —
	/// cell props stay immutable values (lazy-sections' no-closures-in-cell-
	/// props rule). This is how the kiosk digest's change-mood tiles
	/// (`.controlTile`) dispatch `changeAtmosphere` (S7).
	var onItemTap: ((FeedDisplayItem) -> Void)?

	/// `.adaptive` handles iPhone/iPad widths; the minimum itself is scaled
	/// so tiles keep room for accessibility-sized text.
	@ScaledMetric(relativeTo: .caption)
	private var minimumTileWidth: CGFloat = 104

	private var columns: [GridItem] {
		[GridItem(.adaptive(minimum: minimumTileWidth), spacing: Spacing.medium)]
	}

	var body: some View {
		LazyVGrid(columns: columns, spacing: Spacing.medium) {
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

	/// Today's Template catalog never produces .event/.topUp inside a
	/// grid-kind section (checkIn/award/topUp are all list-only) — handled
	/// explicitly rather than with `default` so a template that starts
	/// feeding one of them into a grid fails to compile instead of silently
	/// guessing a layout.
	@ViewBuilder
	private func cell(for item: FeedDisplayItem) -> some View {
		switch item.props {
		case .media(let props):
			TileCell(
				artwork: .remote(url: props.artworkURL, placeholderIcon: props.placeholderIcon),
				title: props.title,
			)
		case .person(let props):
			TileCell(artwork: .remote(url: props.avatarURL, placeholderIcon: .profile), title: props.name)
		case .venue(let props):
			TileCell(artwork: .remote(url: props.artworkURL, placeholderIcon: .venue), title: props.name)
		case .promotion(let props):
			TileCell(
				artwork: .remote(url: props.artworkURL, placeholderIcon: .promotion),
				title: props.caption ?? "",
			)
		case .controlTile(let props):
			TileCell(artwork: .flatColor(props.color, icon: props.icon), title: props.title)
		case .event,
		     .topUp,
		     .dropped:
			EmptyView()
		}
	}
}
