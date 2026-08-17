import SwiftUI

// Cells take only immutable value props (no closures, no observable
// objects), so SwiftUI can compare old and new values and skip body
// re-evaluation entirely. No GeometryReader, no flexible text boxes, no
// measurement feedback loops.
//
// Deliberately no .shadow() and no materials — soft shadows and blur are two
// of the most common scroll-performance killers. Flat fills only.
//
// item.title/item.subtitle are demo fixture text (see FeedView's preview
// fixtures) — Text(verbatim:) keeps it out of the live String Catalog. Real
// feed content arrives from the backend already localized.

struct RowCell: View {
	let item: FeedItem

	@Environment(\.dynamicTypeSize) private var dynamicTypeSize

	/// @ScaledMetric resolves once per Dynamic Type size-category change, not
	/// per frame, so these stay cheap frame constants during scroll while
	/// still growing with the user's text size — the reconciliation between
	/// the demo's fixed dimensions and real accessibility support.
	@ScaledMetric(relativeTo: .subheadline)
	private var iconBoxSize: CGFloat = 44
	@ScaledMetric(relativeTo: .subheadline)
	private var rowHeight: CGFloat = 64

	var body: some View {
		Group {
			if dynamicTypeSize.isAccessibilitySize {
				// No fixed height to protect in this branch, so text wraps
				// freely instead of clipping: lineLimit(nil) here, versus
				// lineLimit(1) in the compact branch below.
				VStack(alignment: .leading, spacing: 8) {
					HStack {
						icon
						Spacer(minLength: 0)
						chevron
					}
					textStack(lineLimit: nil)
				}
				.padding(12)
			} else {
				HStack(spacing: 12) {
					icon
					textStack(lineLimit: 1)
					Spacer(minLength: 0)
					chevron
				}
				.padding(.horizontal, 12)
				.frame(height: rowHeight) // fixed row height → trivial layout pass
			}
		}
		.background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
		.accessibilityElement(children: .combine)
	}

	private var icon: some View {
		Image(systemName: item.symbol)
			.font(.body.weight(.semibold))
			.foregroundStyle(.white)
			.frame(width: iconBoxSize, height: iconBoxSize)
			.background(item.tint.gradient, in: RoundedRectangle(cornerRadius: 10))
			.accessibilityHidden(true)
	}

	private func textStack(lineLimit: Int?) -> some View {
		VStack(alignment: .leading, spacing: 2) {
			Text(verbatim: item.title)
				.font(.subheadline.weight(.semibold))
				.lineLimit(lineLimit)
			Text(verbatim: item.subtitle)
				.font(.caption)
				.foregroundStyle(.secondary)
				.lineLimit(lineLimit)
		}
	}

	private var chevron: some View {
		Image(systemName: "chevron.right")
			.font(.caption.weight(.semibold))
			.foregroundStyle(.tertiary)
			.accessibilityHidden(true)
	}
}

// MARK: - Previews

#Preview("Row cell") {
	RowCell(
		item: FeedItem(
			id: UUID(),
			title: "Sourdough Loaf",
			subtitle: "£2.80 · 4.8★",
			symbol: "fork.knife",
			tint: .orange,
		),
	)
	.padding()
}

#Preview("Accessibility text") {
	RowCell(
		item: FeedItem(
			id: UUID(),
			title: "Artisan Sourdough Loaf, Freshly Baked This Morning",
			subtitle: "£2.80 · 4.8★",
			symbol: "fork.knife",
			tint: .orange,
		),
	)
	.padding()
	.environment(\.dynamicTypeSize, .accessibility5)
}
