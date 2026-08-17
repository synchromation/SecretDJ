import SwiftUI

// item.title is demo fixture text (see FeedView's preview fixtures) —
// Text(verbatim:) keeps it out of the live String Catalog. Real feed
// content arrives from the backend already localized.

struct TileCell: View {
	let item: FeedItem

	@ScaledMetric(relativeTo: .caption)
	private var iconBoxHeight: CGFloat = 64

	var body: some View {
		VStack(spacing: 6) {
			Image(systemName: item.symbol)
				.font(.title3.weight(.semibold))
				.foregroundStyle(.white)
				.frame(maxWidth: .infinity)
				.frame(height: iconBoxHeight)
				.background(item.tint.gradient, in: RoundedRectangle(cornerRadius: 12))
				.accessibilityHidden(true)
			Text(verbatim: item.title)
				.font(.caption.weight(.medium))
				.lineLimit(1)
				.frame(maxWidth: .infinity, alignment: .leading)
		}
		.accessibilityElement(children: .combine)
	}
}

// MARK: - Previews

#Preview("Tile cell") {
	TileCell(
		item: FeedItem(
			id: UUID(),
			title: "Almonds",
			subtitle: "£3.50 · 4.5★",
			symbol: "cart.fill",
			tint: .purple,
		),
	)
	.padding()
}

#Preview("Accessibility text") {
	TileCell(
		item: FeedItem(
			id: UUID(),
			title: "Almonds",
			subtitle: "£3.50 · 4.5★",
			symbol: "cart.fill",
			tint: .purple,
		),
	)
	.padding()
	.environment(\.dynamicTypeSize, .accessibility5)
}
