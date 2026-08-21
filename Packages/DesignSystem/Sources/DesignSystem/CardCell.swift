import SwiftUI

/// A carousel card: artwork-or-icon over a title/subtitle — the
/// `horizontal*`/nested-`container` template family's cell, generalized
/// across song/venue/person payloads by taking only primitive display
/// values (lazy-sections' immutable-value-props rule).
public struct CardCell: View {
	/// 106pt — `StyleKit2023.defaultCellImageSize`
	/// (`secretdjv3/StyleKit2023.swift:15`), matching
	/// `ContainerCellSizeCalculator.calculateCellSize`'s own square sizing
	/// for `horizontalAward`/`horizontalPerson`/`horizontalSong` (width ==
	/// height == `defaultCellImageSize`) — the templates this cell's own
	/// `FeedCarouselSection` caller renders (S9.5).
	public static let baseWidth: CGFloat = 106
	/// Derived, not directly cited: legacy's own horizontal song/person/
	/// award cells carry no title/subtitle text at all (`HorizontalSong
	/// CollectionViewCell.xib` has no `<label>`; `Horizontal{Award,Person}
	/// CollectionViewCell.xib` carry only a single 12pt name caption), so
	/// there's no legacy total-height to port for a card that (unlike
	/// legacy) always shows a title and optional subtitle underneath its
	/// artwork. This is `baseWidth`'s square artwork (106) plus this cell's
	/// own two-line title + one-line subtitle text stack and spacing.
	public static let baseHeight: CGFloat = 178

	let artworkURL: URL?
	let placeholderIcon: Theme.Icon
	let title: String
	let subtitle: String?

	@ScaledMetric(relativeTo: .footnote)
	private var width = CardCell.baseWidth
	@ScaledMetric(relativeTo: .footnote)
	private var height = CardCell.baseHeight
	/// Same 106pt legacy citation as `baseWidth` (S9.5) — kept square, same
	/// as the legacy cells it ports from.
	@ScaledMetric(relativeTo: .footnote)
	private var artworkHeight: CGFloat = 106

	public init(artworkURL: URL? = nil, placeholderIcon: Theme.Icon, title: String, subtitle: String? = nil) {
		self.artworkURL = artworkURL
		self.placeholderIcon = placeholderIcon
		self.title = title
		self.subtitle = subtitle
	}

	public var body: some View {
		VStack(alignment: .leading, spacing: Spacing.small) {
			RemoteArtworkView(url: artworkURL, placeholderIcon: placeholderIcon, width: width, height: artworkHeight)

			Text(verbatim: title)
				.font(Theme.TextStyle.cellTitle.font)
				.foregroundStyle(Theme.ColorRole.primaryText.color)
				.lineLimit(2, reservesSpace: true) // reserved → stable height regardless of actual line count

			if let subtitle {
				Text(verbatim: subtitle)
					.font(Theme.TextStyle.caption.font)
					.foregroundStyle(Theme.ColorRole.secondaryText.color)
					.lineLimit(1)
			}
		}
		.frame(width: width, height: height, alignment: .top)
		.accessibilityElement(children: .combine)
	}
}

// MARK: - Previews

#Preview("Card cell") {
	CardCell(placeholderIcon: .song, title: "Levitating", subtitle: "Dua Lipa")
		.padding()
}

#Preview("No subtitle") {
	CardCell(placeholderIcon: .venue, title: "The Fox")
		.padding()
}

#Preview("Dark mode") {
	CardCell(placeholderIcon: .song, title: "Levitating", subtitle: "Dua Lipa")
		.padding()
		.preferredColorScheme(.dark)
}

#Preview("Accessibility text size") {
	CardCell(placeholderIcon: .song, title: "Levitating (Featuring DaBaby) [Extended Remix]", subtitle: "Dua Lipa")
		.padding()
		.environment(\.dynamicTypeSize, .accessibility5)
}
