import SwiftUI

/// A promotion/advert imagery card — the `promotion`/`advert`/
/// `matrixPromotionMedium` templates' cell. `height` is server-controlled
/// (LEGACY.md: the server sizes each promotion's banner) — a caller passes
/// it straight through rather than this cell guessing one.
public struct PromotionCell: View {
	let artworkURL: URL?
	let caption: String?

	@ScaledMetric private var height: CGFloat

	public init(artworkURL: URL?, caption: String? = nil, height: CGFloat = 120) {
		self.artworkURL = artworkURL
		self.caption = caption
		_height = ScaledMetric(wrappedValue: height, relativeTo: .footnote)
	}

	public var body: some View {
		VStack(alignment: .leading, spacing: Spacing.small) {
			RemoteArtworkView(url: artworkURL, placeholderIcon: .promotion, width: nil, height: height)

			if let caption {
				Text(verbatim: caption)
					.font(Theme.TextStyle.cellSubtitle.font)
					.foregroundStyle(Theme.ColorRole.secondaryText.color)
					.lineLimit(2)
			}
		}
		.accessibilityElement(children: .combine)
	}
}

// MARK: - Previews

#Preview("Promotion with caption") {
	PromotionCell(artworkURL: nil, caption: "Half-price requests until 9pm")
		.padding()
}

#Preview("Image-only promotion") {
	PromotionCell(artworkURL: nil, height: 160)
		.padding()
}

#Preview("Dark mode") {
	PromotionCell(artworkURL: nil, caption: "Half-price requests until 9pm")
		.padding()
		.preferredColorScheme(.dark)
}

#Preview("Accessibility text size") {
	PromotionCell(artworkURL: nil, caption: "Half-price requests until 9pm — this weekend only, don't miss out")
		.padding()
		.environment(\.dynamicTypeSize, .accessibility5)
}
