import SwiftUI

struct SectionBody: View {
	let section: FeedSection

	var body: some View {
		// A switch keeps concrete view types — no AnyView. Type erasure
		// destroys structural identity and makes diffing far more expensive.
		switch section.kind {
		case .list: ListSection(items: section.items)
		case .carousel: CarouselSection(items: section.items)
		case .grid: GridSection(items: section.items)
		}
	}
}
