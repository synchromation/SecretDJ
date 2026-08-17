import SwiftUI

// Cells take only immutable value props (no closures, no observable
// objects), so SwiftUI can compare old and new values and skip body
// re-evaluation entirely.
//
// Deliberately no .shadow() and no materials — soft shadows and blur are two
// of the most common scroll-performance killers. Flat fills only.
//
// The demo's original comment noted fixed heights trade against Dynamic
// Type; @ScaledMetric resolves that trade-off — it reads the current size
// category once per change (not once per frame), so `width`/`height` below
// stay ordinary constants during scroll while still growing when the user
// asks for larger text. `lineLimit(2, reservesSpace: true)` reserves height
// for the scaled font at that size, so the reserved space and the frame
// height grow in step instead of clipping or leaving a gap.
//
// item.title/item.subtitle are demo fixture text (see FeedView's preview
// fixtures) — Text(verbatim:) keeps it out of the live String Catalog. Real
// feed content arrives from the backend already localized.
//
// baseWidth/baseHeight are unscaled base dimensions. CarouselSection scales
// its own copy from baseHeight so its fixed frame height and this cell's
// own height never drift out of sync.

struct CardCell: View {
	static let baseWidth: CGFloat = 140
	static let baseHeight: CGFloat = 168

	let item: FeedItem

	@ScaledMetric(relativeTo: .footnote)
	private var width = CardCell.baseWidth
	@ScaledMetric(relativeTo: .footnote)
	private var height = CardCell.baseHeight
	@ScaledMetric(relativeTo: .footnote)
	private var artworkHeight: CGFloat = 96

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			RoundedRectangle(cornerRadius: 12)
				.fill(item.tint.gradient)
				.frame(height: artworkHeight)
				.overlay {
					Image(systemName: item.symbol)
						.font(.title.weight(.semibold))
						.foregroundStyle(.white)
						.accessibilityHidden(true)
				}
			Text(verbatim: item.title)
				.font(.footnote.weight(.semibold))
				.lineLimit(2, reservesSpace: true) // reserved → stable height
			Text(verbatim: item.subtitle)
				.font(.caption2)
				.foregroundStyle(.secondary)
				.lineLimit(1)
		}
		.frame(width: width, height: height, alignment: .top)
		.accessibilityElement(children: .combine)
	}
}

// MARK: - Previews

#Preview("Card cell") {
	CardCell(
		item: FeedItem(
			id: UUID(),
			title: "Espresso Beans",
			subtitle: "£6.50 · 4.9★",
			symbol: "cup.and.saucer.fill",
			tint: .brown,
		),
	)
	.padding()
}

#Preview("Accessibility text") {
	CardCell(
		item: FeedItem(
			id: UUID(),
			title: "Espresso Beans",
			subtitle: "£6.50 · 4.9★",
			symbol: "cup.and.saucer.fill",
			tint: .brown,
		),
	)
	.padding()
	.environment(\.dynamicTypeSize, .accessibility5)
}
