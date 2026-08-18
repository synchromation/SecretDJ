import DesignSystem
import SecretDJDomain
import SwiftUI

/// A themed placeholder row for one item's display text — S3.2 replaces
/// this with the real per-payload cell library (song, artist, venue, ...);
/// for now every item renders identically regardless of its concrete
/// Domain payload.
struct FeedPlaceholderCell: View {
	let item: FeedDisplayItem

	@Environment(\.dynamicTypeSize) private var dynamicTypeSize

	var body: some View {
		// item.text is server-driven copy that already arrives localized
		// (localization skill's server-text rule) — Text(verbatim:) keeps
		// it out of the String Catalog, same as any dynamic feed content.
		Text(verbatim: item.text)
			.font(Theme.TextStyle.cellTitle.font)
			.foregroundStyle(Theme.ColorRole.primaryText.color)
			.lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
			.multilineTextAlignment(.leading)
			.frame(maxWidth: .infinity, alignment: .leading)
			.padding(Spacing.medium)
			.background(Theme.ColorRole.cellSurface.color, in: RoundedRectangle(cornerRadius: 14))
			.accessibilityElement(children: .combine)
	}
}

// MARK: - Previews

#Preview("Placeholder cell") {
	FeedPlaceholderCell(item: previewItem(text: "Bohemian Rhapsody\nQueen"))
		.padding()
}

#Preview("Accessibility text size") {
	FeedPlaceholderCell(item: previewItem(text: "Bohemian Rhapsody\nQueen"))
		.padding()
		.environment(\.dynamicTypeSize, .accessibility5)
}

/// Inline preview fixture only — production items come from
/// ``FeedDisplayModel``, built once from a fetched ``SecretDJDomain/SectionList``.
private func previewItem(text: String) -> FeedDisplayItem {
	let song = Song(
		songId: "1",
		title: "",
		artist: "",
		previewURL: nil,
		likeInfo: LikeInfo(likedByYou: false, info: ""),
		text: text,
		sortIndex: 0,
		action: nil,
		actions: [],
	)
	return FeedDisplayItem(id: "preview", item: .song(song), text: text)
}
