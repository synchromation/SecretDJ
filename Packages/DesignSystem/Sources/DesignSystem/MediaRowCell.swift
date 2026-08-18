import SwiftUI

/// A song, artist, or jukebox row: artwork-or-icon leading, title/subtitle,
/// and an optional trailing accessory. Immutable value props only (no
/// closures, no observable objects) — see the lazy-sections skill.
public struct MediaRowCell: View {
	/// A row's trailing affordance. At most one per row — the legacy cell
	/// family never combines them.
	public enum Accessory: Hashable, Sendable {
		/// The row navigates somewhere on tap.
		case chevron
		/// The row's like ("buzz") state. `summary` is the server's own
		/// pre-rendered, already-localized like copy (e.g. "12 people
		/// buzzed this") — spoken as part of this row's combined
		/// accessibility element; `nil` when the server sent none, in which
		/// case the icon stays purely decorative.
		case like(isLiked: Bool, summary: String?)
		/// A plain text badge, e.g. a credit cost.
		case creditBadge(String)
	}

	let artworkURL: URL?
	let placeholderIcon: Theme.Icon
	let title: String
	let subtitle: String?
	let accessory: Accessory?
	let artworkShape: RemoteArtworkView.Shape

	@Environment(\.dynamicTypeSize) private var dynamicTypeSize

	@ScaledMetric(relativeTo: .subheadline)
	private var artworkSize: CGFloat = 44
	@ScaledMetric(relativeTo: .subheadline)
	private var rowHeight: CGFloat = 64

	public init(
		artworkURL: URL? = nil,
		placeholderIcon: Theme.Icon,
		title: String,
		subtitle: String? = nil,
		accessory: Accessory? = nil,
		artworkShape: RemoteArtworkView.Shape = .rounded,
	) {
		self.artworkURL = artworkURL
		self.placeholderIcon = placeholderIcon
		self.title = title
		self.subtitle = subtitle
		self.accessory = accessory
		self.artworkShape = artworkShape
	}

	public var body: some View {
		Group {
			if dynamicTypeSize.isAccessibilitySize {
				VStack(alignment: .leading, spacing: Spacing.small) {
					HStack {
						artwork
						Spacer(minLength: 0)
						accessoryView
					}
					textStack(lineLimit: nil)
				}
				.padding(Spacing.medium)
			} else {
				HStack(spacing: Spacing.medium) {
					artwork
					textStack(lineLimit: 1)
					Spacer(minLength: 0)
					accessoryView
				}
				.padding(.horizontal, Spacing.medium)
				.frame(height: rowHeight)
			}
		}
		.background(Theme.ColorRole.cellSurface.color, in: RoundedRectangle(cornerRadius: 14))
		.accessibilityElement(children: .combine)
	}

	private var artwork: some View {
		RemoteArtworkView(url: artworkURL, placeholderIcon: placeholderIcon, size: artworkSize, shape: artworkShape)
	}

	private func textStack(lineLimit: Int?) -> some View {
		VStack(alignment: .leading, spacing: Spacing.extraSmall) {
			Text(verbatim: title)
				.font(Theme.TextStyle.cellTitle.font)
				.foregroundStyle(Theme.ColorRole.primaryText.color)
				.lineLimit(lineLimit)

			if let subtitle {
				Text(verbatim: subtitle)
					.font(Theme.TextStyle.cellSubtitle.font)
					.foregroundStyle(Theme.ColorRole.secondaryText.color)
					.lineLimit(lineLimit)
			}
		}
	}

	@ViewBuilder
	private var accessoryView: some View {
		switch accessory {
		case nil:
			EmptyView()

		case .chevron:
			Theme.Icon.disclosure.image
				.font(.caption.weight(.semibold))
				.foregroundStyle(Theme.ColorRole.secondaryText.color)
				.accessibilityHidden(true)

		case .like(let isLiked, let summary):
			(isLiked ? Theme.Icon.likeFilled : Theme.Icon.like).image
				.font(.body)
				.foregroundStyle(isLiked ? Theme.ColorRole.accent.color : Theme.ColorRole.secondaryText.color)
				.modifier(LikeAccessibilityModifier(isLiked: isLiked, summary: summary))

		case .creditBadge(let text):
			Text(verbatim: text)
				.font(Theme.TextStyle.caption.font)
				.foregroundStyle(Theme.ColorRole.accentText.color)
				.padding(.horizontal, Spacing.small)
				.padding(.vertical, Spacing.extraSmall)
				.background(Theme.ColorRole.accent.color, in: Capsule())
		}
	}
}

/// Exposes a like accessory's state to VoiceOver without this package
/// authoring any copy of its own: the server's own like-summary text (when
/// present) becomes the icon's label, and `.isSelected` carries the boolean
/// state independent of any text. With no summary, the icon stays decorative
/// — there's nothing true to say beyond the icon's appearance.
private struct LikeAccessibilityModifier: ViewModifier {
	let isLiked: Bool
	let summary: String?

	func body(content: Content) -> some View {
		if let summary, !summary.isEmpty {
			content
				.accessibilityLabel(Text(verbatim: summary))
				.accessibilityAddTraits(isLiked ? .isSelected : [])
		} else {
			content.accessibilityHidden(true)
		}
	}
}

// MARK: - Previews

#Preview("Song row") {
	MediaRowCell(
		placeholderIcon: .song,
		title: "Bohemian Rhapsody",
		subtitle: "Queen",
		accessory: .like(isLiked: true, summary: "12 people buzzed this"),
	)
	.padding()
}

#Preview("Jukebox row") {
	MediaRowCell(placeholderIcon: .jukebox, title: "Rock Classics", subtitle: "42 songs", accessory: .chevron)
		.padding()
}

#Preview("Credit badge") {
	MediaRowCell(
		placeholderIcon: .song,
		title: "Levitating",
		subtitle: "Dua Lipa",
		accessory: .creditBadge("2 credits"),
	)
	.padding()
}

#Preview("Dark mode") {
	MediaRowCell(
		placeholderIcon: .song,
		title: "Bohemian Rhapsody",
		subtitle: "Queen",
		accessory: .like(isLiked: false, summary: nil),
	)
	.padding()
	.preferredColorScheme(.dark)
}

#Preview("Accessibility text size") {
	MediaRowCell(
		placeholderIcon: .song,
		title: "Bohemian Rhapsody (Live Aid Wembley Stadium Recording)",
		subtitle: "Queen",
		accessory: .chevron,
	)
	.padding()
	.environment(\.dynamicTypeSize, .accessibility5)
}
