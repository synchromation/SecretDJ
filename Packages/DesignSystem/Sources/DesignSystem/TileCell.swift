import SwiftUI

/// A grid tile: artwork-or-icon (or, for a mood tile, a flat server-driven
/// color) over a single-line title — the `matrix*` template family's cell.
public struct TileCell: View {
	/// A tile's leading visual — either art loaded from the network (with an
	/// icon fallback), or a flat color the server dictates directly (a mood
	/// tile's `fgColour`/`bgColour`, which aren't part of this design
	/// system's token palette).
	public enum Artwork: Hashable, Sendable {
		case remote(url: URL?, placeholderIcon: Theme.Icon)
		case flatColor(Theme.RGBAComponents, icon: Theme.Icon)
	}

	let artwork: Artwork
	let title: String

	@ScaledMetric(relativeTo: .caption)
	private var boxHeight: CGFloat = 64

	public init(artwork: Artwork, title: String) {
		self.artwork = artwork
		self.title = title
	}

	public var body: some View {
		VStack(spacing: Spacing.small) {
			artworkView

			Text(verbatim: title)
				.font(Theme.TextStyle.caption.font.weight(.medium))
				.lineLimit(1)
				.frame(maxWidth: .infinity, alignment: .leading)
		}
		.accessibilityElement(children: .combine)
	}

	@ViewBuilder
	private var artworkView: some View {
		switch artwork {
		case .remote(let url, let icon):
			RemoteArtworkView(url: url, placeholderIcon: icon, width: nil, height: boxHeight)

		case .flatColor(let components, let icon):
			RoundedRectangle(cornerRadius: 12)
				.fill(components.color)
				.frame(maxWidth: .infinity)
				.frame(height: boxHeight)
				.overlay {
					icon.image
						.font(.title3.weight(.semibold))
						.foregroundStyle(.white)
						.accessibilityHidden(true)
				}
		}
	}
}

// MARK: - Previews

#Preview("Tile cell") {
	TileCell(artwork: .remote(url: nil, placeholderIcon: .song), title: "Almonds")
		.padding()
		.frame(width: 120)
}

#Preview("Mood tile") {
	TileCell(
		artwork: .flatColor(
			Theme.RGBAComponents(hex: "#6C2BD9") ?? Theme.RGBAComponents(red: 0.5, green: 0.5, blue: 0.5),
			icon: .mood,
		),
		title: "Chilled",
	)
	.padding()
	.frame(width: 120)
}

#Preview("Dark mode") {
	TileCell(artwork: .remote(url: nil, placeholderIcon: .song), title: "Almonds")
		.padding()
		.frame(width: 120)
		.preferredColorScheme(.dark)
}

#Preview("Accessibility text size") {
	TileCell(artwork: .remote(url: nil, placeholderIcon: .song), title: "Almonds")
		.padding()
		.frame(width: 160)
		.environment(\.dynamicTypeSize, .accessibility5)
}
