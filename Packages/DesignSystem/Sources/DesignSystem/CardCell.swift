import SwiftUI

/// A carousel card: artwork-or-icon over a title/subtitle — the
/// `horizontal*`/nested-`container` template family's cell, generalized
/// across song/venue/person payloads by taking only primitive display
/// values (lazy-sections' immutable-value-props rule).
public struct CardCell: View {
	public static let baseWidth: CGFloat = 140
	public static let baseHeight: CGFloat = 168

	let artworkURL: URL?
	let placeholderIcon: Theme.Icon
	let title: String
	let subtitle: String?

	@ScaledMetric(relativeTo: .footnote)
	private var width = CardCell.baseWidth
	@ScaledMetric(relativeTo: .footnote)
	private var height = CardCell.baseHeight
	@ScaledMetric(relativeTo: .footnote)
	private var artworkHeight: CGFloat = 96

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
