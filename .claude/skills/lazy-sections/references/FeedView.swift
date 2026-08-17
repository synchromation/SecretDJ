import SwiftUI

// One vertical ScrollView with one outer LazyVStack provides the laziness
// for the whole feed: section bodies are only instantiated as they approach
// the viewport. Scroll-to-top is event-driven via ScrollViewReader —
// deliberately NOT a `.scrollPosition(id:)` binding, which writes state on
// the main thread continuously while the user scrolls.

struct FeedView: View {
	let sections: [FeedSection]
	/// Incrementing this snaps the feed back to the top — e.g. after a
	/// refresh replaces `sections`. Equal values never trigger a scroll.
	let generation: Int

	private static let topAnchorID = "top"

	var body: some View {
		ScrollViewReader { proxy in
			ScrollView(.vertical) {
				VStack(spacing: 0) {
					// Anchor lives outside the lazy container so it always exists.
					Color.clear.frame(height: 0).id(Self.topAnchorID)

					// pinnedViews: [.sectionHeaders] also works here; pinning
					// costs a little per frame, so it's off by default.
					LazyVStack(spacing: 12) {
						ForEach(sections) { section in
							Section {
								SectionBody(section: section)
									.padding(.bottom, 18)
							} header: {
								SectionHeader(title: section.title, kind: section.kind)
							}
						}
					}
					.padding(.vertical, 16)
				}
			}
			.onChange(of: generation) {
				proxy.scrollTo(Self.topAnchorID, anchor: .top) // not animated → instant
			}
		}
	}
}

// MARK: - Previews

#Preview("Mixed feed") {
	FeedView(sections: previewMixedSections, generation: 0)
}

#Preview("Empty feed") {
	FeedView(sections: [], generation: 0)
}

#Preview("Accessibility text size") {
	FeedView(sections: previewMixedSections, generation: 0)
		.environment(\.dynamicTypeSize, .accessibility5)
}

/// Inline preview fixtures only. A real feed's sections and items come from
/// the backend, already localized (localization skill's server-text rule) —
/// every cell and header renders this fixture text with Text(verbatim:) so
/// none of it pollutes the live String Catalog.
private let previewMixedSections: [FeedSection] = [
	FeedSection(
		id: UUID(),
		kind: .list,
		title: "Fresh Picks",
		items: [
			FeedItem(id: UUID(), title: "Organic Bananas", subtitle: "£1.20 · 4.6★", symbol: "leaf.fill", tint: .green),
			FeedItem(
				id: UUID(),
				title: "Sourdough Loaf",
				subtitle: "£2.80 · 4.8★",
				symbol: "fork.knife",
				tint: .orange,
			),
			FeedItem(
				id: UUID(),
				title: "Oat Milk",
				subtitle: "£1.60 · 4.4★",
				symbol: "cup.and.saucer.fill",
				tint: .brown,
			),
			FeedItem(
				id: UUID(),
				title: "Free Range Eggs",
				subtitle: "£2.10 · 4.9★",
				symbol: "circle.fill",
				tint: .yellow,
			),
		],
	),
	FeedSection(
		id: UUID(),
		kind: .carousel,
		title: "Trending Now",
		items: [
			FeedItem(
				id: UUID(),
				title: "Espresso Beans",
				subtitle: "£6.50 · 4.9★",
				symbol: "cup.and.saucer.fill",
				tint: .brown,
			),
			FeedItem(id: UUID(), title: "Dark Chocolate", subtitle: "£3.10 · 4.7★", symbol: "gift.fill", tint: .pink),
			FeedItem(
				id: UUID(),
				title: "Wild Salmon Fillet",
				subtitle: "£8.90 · 4.5★",
				symbol: "fish.fill",
				tint: .blue,
			),
			FeedItem(id: UUID(), title: "Greek Yoghurt", subtitle: "£2.40 · 4.6★", symbol: "star.fill", tint: .indigo),
			FeedItem(id: UUID(), title: "Honey", subtitle: "£4.20 · 4.8★", symbol: "hexagon.fill", tint: .yellow),
		],
	),
	FeedSection(
		id: UUID(),
		kind: .grid,
		title: "Store Cupboard",
		items: [
			FeedItem(id: UUID(), title: "Almonds", subtitle: "£3.50 · 4.5★", symbol: "cart.fill", tint: .purple),
			FeedItem(id: UUID(), title: "Green Tea", subtitle: "£2.90 · 4.3★", symbol: "leaf.fill", tint: .green),
			FeedItem(id: UUID(), title: "Basil", subtitle: "£1.10 · 4.2★", symbol: "leaf.fill", tint: .mint),
			FeedItem(id: UUID(), title: "Olive Oil", subtitle: "£5.60 · 4.7★", symbol: "drop.fill", tint: .yellow),
			FeedItem(id: UUID(), title: "Tomatoes", subtitle: "£1.80 · 4.4★", symbol: "circle.fill", tint: .red),
			FeedItem(id: UUID(), title: "Granola", subtitle: "£3.20 · 4.6★", symbol: "bag.fill", tint: .orange),
			FeedItem(id: UUID(), title: "Cheddar", subtitle: "£4.00 · 4.5★", symbol: "square.fill", tint: .yellow),
			FeedItem(id: UUID(), title: "Smoked Salmon", subtitle: "£7.50 · 4.8★", symbol: "fish.fill", tint: .pink),
			FeedItem(
				id: UUID(),
				title: "Crunchy Granola Bars",
				subtitle: "£2.60 · 4.3★",
				symbol: "star.fill",
				tint: .brown,
			),
		],
	),
]
