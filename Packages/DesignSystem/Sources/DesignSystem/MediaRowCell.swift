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

	/// 106pt — `StyleKit2023.defaultCellImageSize`
	/// (`secretdjv3/StyleKit2023.swift:15`), confirmed as this row family's
	/// actual artwork side in the cell xibs themselves (e.g.
	/// `secretdjv3/Cells/SongCollectionViewCell.xib`'s 106×106 "Placeholder
	/// Image" constraints) — every `FeedSectionKind.list` template shares one
	/// image size (S9.5).
	@ScaledMetric(relativeTo: .subheadline)
	private var artworkSize: CGFloat = 106
	/// 114pt — `StyleKit2023.defaultCellHeight()`
	/// (`secretdjv3/StyleKit2023.swift:93-95`: `defaultCellImageSize`(106) +
	/// `defaultCellBottomMargin`(8)), the row height
	/// `FeedCellSizeCalculator.cellSizeiPhone(for:maxSize:lastSection:)`'s
	/// `default` case falls through to for every plain (non-matrix,
	/// non-horizontal) template — song/venue/person/feedItem/checkIn/award/
	/// newsItem/topUp all included (S9.5).
	@ScaledMetric(relativeTo: .subheadline)
	private var rowHeight: CGFloat = 114
	/// 12pt — `StyleKit2023.getCornerRadius(.size3x3)` ==
	/// `MatrixMediumCornerRadius` (`secretdjv3/StyleKit2023.swift:29`),
	/// applied to every flat row's artwork via `BaseCollectionViewCell
	/// .awakeFromNib` (`secretdjv3/BaseCollectionViewCell.swift:80-85`) — a
	/// fixed point value, not proportional to `artworkSize` (S9.6, replacing
	/// `RemoteArtworkView`'s general-purpose `height * 0.2` default for this
	/// row family specifically).
	@ScaledMetric(relativeTo: .subheadline)
	private var artworkCornerRadius: CGFloat = 12

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
					// Top-aligned against the artwork, not centered (S9.6):
					// legacy's own title/subtitle labels sit at a fixed y
					// from the cell's top (`secretdjv3/Cells
					// /SongCollectionViewCell.xib`'s tag-101/102 constraints,
					// y=8/y=26), never vertically centered against the
					// 106pt artwork beside them. The trailing accessory
					// stays centered in its own nesting level, unchanged.
					HStack(alignment: .top, spacing: Spacing.medium) {
						artwork
						textStack(lineLimit: 1)
					}
					Spacer(minLength: 0)
					accessoryView
				}
				.padding(.horizontal, Spacing.medium)
				// `minHeight`, not a fixed `height` — see `TopUpRowCell`'s own
				// comment (PLAN.md S8.2): a hard-fixed frame around
				// `lineLimit(1)` text is a Dynamic Type clipping risk.
				.frame(minHeight: rowHeight)
			}
		}
		.background(Theme.ColorRole.cellSurface.color, in: RoundedRectangle(cornerRadius: 14))
		.accessibilityElement(children: .combine)
	}

	private var artwork: some View {
		RemoteArtworkView(
			url: artworkURL,
			placeholderIcon: placeholderIcon,
			size: artworkSize,
			shape: artworkShape,
			cornerRadius: artworkCornerRadius,
		)
	}

	/// `cellTitle`/`cellSubtitle` re-confirmed against this family's own
	/// legacy xibs (S9.7): `SongCollectionViewCell.xib` sets tag 101
	/// (artist/title line) `HelveticaNeue-Medium` 15pt and tag 102/103
	/// (song name / "liked by") `HelveticaNeue-Light` 13pt/11pt;
	/// `VenueCollectionViewCell.xib` sets tag 101 (venue name)
	/// `HelveticaNeue-Medium` 15pt and tag 102 (address)
	/// `HelveticaNeue-Light` 13pt — both land exactly on `cellTitle`/
	/// `cellSubtitle`'s existing 15pt-semibold/13pt-regular recipe
	/// already, so this cell's two-line family needed no change.
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

	private var accessoryView: some View {
		RowAccessoryView(accessory: accessory)
	}
}

/// A row's trailing affordance (chevron / like / credit badge), shared by
/// every row cell that exposes ``MediaRowCell/Accessory`` (``MediaRowCell``,
/// ``PersonRowCell``) so its rendering and accessibility behavior live in one
/// place rather than each cell duplicating the same switch.
struct RowAccessoryView: View {
	let accessory: MediaRowCell.Accessory?

	var body: some View {
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
