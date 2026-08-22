import SwiftUI

/// A person row: rounded-rectangle avatar-or-icon, up to four positional
/// tagged lines, and an optional trailing accessory.
///
/// Unlike ``MediaRowCell``, this cell owns its own body rather than wrapping
/// that one: legacy's person row carries up to four independently
/// positioned labels rather than a plain title/subtitle pair, and the last
/// of them pins near the row's bottom regardless of how many lines precede
/// it (S9.6) — a shape `MediaRowCell`'s two-line API can't express. Its
/// artwork is a rounded rectangle, not a circle: legacy has no circular
/// artwork anywhere in the flat row family (S9.6 — a correction to S9.5's
/// `artworkShape: .circle`, which had no legacy basis). Legacy's own profile
/// header (`SupplementaryViewProvider.profileSectionHeaderView`) is *also*
/// not circular — a large rounded-square container,
/// `getCornerRadius(.size1x1)` == `MatrixMassiveCornerRadius` == 16pt
/// (`secretdjv3/SupplementaryViewProvider.swift:287`), with a smaller
/// centered rounded-square fallback avatar at `getCornerRadius(.size2x2)` ==
/// `MatrixLargeCornerRadius` == 12pt (same file, lines 290-292) — this
/// design's own `ProfileHeaderView` (`SecretDJ/Features/Profile
/// /ProfileHeaderView.swift`) is a different feature/screen than this
/// activity-feed row family, but it had the same `shape: .circle` bug this
/// cell did, with no legacy basis either, so it's been corrected alongside
/// this cell (S9.6) rather than left to carry the same defect forward.
///
/// Its four lines don't share one font recipe either (S9.7): legacy's
/// `FeedItemCollectionViewCell.xib` sets line 1 (person, tag 101)
/// HelveticaNeue-Light 14pt, line 2 (title, tag 102) HelveticaNeue-
/// **Medium** 14pt — the bold line is the *second* line, not the first —
/// line 3 (details, tag 103) Light 12pt, and line 4 ("since", tag 104)
/// Light 11pt; see `font(atLineIndex:)` and
/// `Theme.TextStyle.recipe`'s own `caption2` doc comment for exactly how
/// each maps onto this design's fonts.
public struct PersonRowCell: View {
	let avatarURL: URL?
	/// Up to four positional lines, straight from
	/// `FeedUI.FeedCellProps.PersonProps.lines` — never pre-split into
	/// name/subtitle/etc. upstream; this cell alone decides how they lay out.
	let lines: [String]
	let accessory: MediaRowCell.Accessory?

	@Environment(\.dynamicTypeSize) private var dynamicTypeSize

	/// 106pt — same legacy citation as `MediaRowCell`'s own `artworkSize`
	/// (S9.5): this cell shares the flat row family's artwork size.
	@ScaledMetric(relativeTo: .subheadline)
	private var artworkSize: CGFloat = 106
	/// 12pt — same legacy citation as `MediaRowCell`'s own
	/// `artworkCornerRadius` (S9.6): `StyleKit2023.getCornerRadius(.size3x3)`
	/// (`secretdjv3/StyleKit2023.swift:29`), applied via
	/// `BaseCollectionViewCell.awakeFromNib`
	/// (`secretdjv3/BaseCollectionViewCell.swift:80-85`) to every flat row's
	/// artwork, this cell's own included — never a circle.
	@ScaledMetric(relativeTo: .subheadline)
	private var artworkCornerRadius: CGFloat = 12
	/// 114pt — same legacy citation as `MediaRowCell`'s own `rowHeight`
	/// (S9.5).
	@ScaledMetric(relativeTo: .subheadline)
	private var rowHeight: CGFloat = 114
	/// 14pt — legacy's tag-101 (person) and tag-102 (title) label size
	/// (`secretdjv3/Cells/FeedItemCollectionViewCell.xib`), shared by both
	/// lines despite their different weights (S9.7, this type's own doc
	/// comment). No system Dynamic Type style lands on 14pt at the
	/// default size (nearest neighbors are `.footnote` at 13pt and
	/// `.subheadline` at 15pt), so — per the accessibility skill's
	/// `@ScaledMetric`-seeded-fixed-size allowance — both lines get their
	/// own scaled font here rather than being force-fit onto
	/// `Theme.TextStyle.cellTitle`/`cellSubtitle`, which correctly serve a
	/// different cell family at 15pt/13pt.
	@ScaledMetric(relativeTo: .subheadline)
	private var feedLineFontSize: CGFloat = 14

	public init(
		avatarURL: URL? = nil,
		lines: [String],
		accessory: MediaRowCell.Accessory? = nil,
	) {
		self.avatarURL = avatarURL
		self.lines = lines
		self.accessory = accessory
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
					linesStack(effectiveLines, lineLimit: nil)
				}
				.padding(Spacing.medium)
			} else {
				HStack(spacing: Spacing.medium) {
					// Top-aligned against the artwork, not centered (S9.6) —
					// see `MediaRowCell`'s own citation for the same fix.
					HStack(alignment: .top, spacing: Spacing.medium) {
						artwork
						textColumn
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
			url: avatarURL,
			placeholderIcon: .profile,
			size: artworkSize,
			cornerRadius: artworkCornerRadius,
		)
	}

	private var accessoryView: some View {
		RowAccessoryView(accessory: accessory)
	}

	/// Legacy's fixed positional label mapping (`FeedCellConfigurator
	/// .populateFields`, `secretdjv3/FeedCellConfigurator.swift:270-275`):
	/// every label is bound by a fixed index — tag 101→line 0, 102→1,
	/// 103→2, 104→3 — regardless of how many total labels a given
	/// template's cell carries, or how many lines the server actually sent
	/// for this row. `.person`/`.horizontalPerson`'s own cell
	/// (`PersonCollectionViewCell.xib`) has only three labels (101/102/104
	/// — no 103 "details" slot); `.feedItem`/`.vip`'s
	/// (`FeedItemCollectionViewCell.xib`) has all four. Either way, tag 104
	/// ("since"/timestamp) sits at a fixed y near the row's bottom
	/// (`PersonCollectionViewCell.xib` y=93,
	/// `FeedItemCollectionViewCell.xib` y=87, of a 114pt row) — never
	/// immediately following whatever the middle line happens to be. So
	/// only a *fourth* line ever pins to the bottom; a row with three lines
	/// or fewer stacks every one of them from the top, with no reserved
	/// gap (S9.6, "degrade gracefully").
	private var effectiveLines: [String] {
		Array(lines.prefix(4))
	}

	private var topLines: [String] {
		effectiveLines.count == 4 ? Array(effectiveLines.prefix(3)) : effectiveLines
	}

	private var bottomLine: String? {
		effectiveLines.count == 4 ? effectiveLines[3] : nil
	}

	/// Sized to `artworkSize` and top-aligned so a `Spacer` between the top
	/// stack and a present `bottomLine` has real room to expand into,
	/// pinning that last line flush with the artwork's own bottom edge —
	/// the standard SwiftUI "fixed-height container + Spacer" pattern for a
	/// bottom-pinned element, matching legacy's fixed-y "since" label
	/// without any fixed-height text (`lineLimit(1)` only, never a clipped
	/// frame).
	private var textColumn: some View {
		VStack(alignment: .leading, spacing: 0) {
			linesStack(topLines, lineLimit: 1)
			if let bottomLine {
				Spacer(minLength: Spacing.extraSmall)
				Text(verbatim: bottomLine)
					.font(Theme.TextStyle.caption2.font)
					.foregroundStyle(Theme.ColorRole.secondaryText.color)
					.lineLimit(1)
			}
		}
		.frame(height: artworkSize, alignment: .top)
	}

	/// Positional by convention, not identity — same rationale as
	/// `EventRowCell`'s own `lines` rendering: the server sends these as
	/// ordered tagged lines, never addressable records, and `lines` is an
	/// immutable value replaced atomically alongside the rest of this
	/// cell's props, so keying by offset never desyncs to stale content.
	private func linesStack(_ lines: [String], lineLimit: Int?) -> some View {
		VStack(alignment: .leading, spacing: Spacing.extraSmall) {
			ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
				Text(verbatim: line)
					.font(font(atLineIndex: index))
					.foregroundStyle(index == 0 ? Theme.ColorRole.primaryText.color : Theme.ColorRole.secondaryText
						.color)
					.lineLimit(lineLimit)
			}
		}
	}

	/// This cell's own per-line font recipe (this type's own doc comment,
	/// `Theme.TextStyle.recipe`'s `caption2` doc comment): index 0 → tag
	/// 101 (person) Light 14pt, index 1 → tag 102 (title) Medium 14pt,
	/// index 2 → tag 103 (details) Light 12pt (`Theme.TextStyle.caption`,
	/// an exact system-style match), index 3+ → tag 104 ("since") Light
	/// 11pt (`Theme.TextStyle.caption2`, also exact). Index-based, not
	/// tag-based, same simplification `effectiveLines`'s own doc comment
	/// already accepts for a row with fewer than four lines.
	private func font(atLineIndex index: Int) -> Font {
		switch index {
		case 0: .system(size: feedLineFontSize, weight: .regular)
		case 1: .system(size: feedLineFontSize, weight: .semibold)
		case 2: Theme.TextStyle.caption.font
		default: Theme.TextStyle.caption2.font
		}
	}
}

// MARK: - Previews

#Preview("Person row") {
	PersonRowCell(lines: ["Nick Banks", "12 places visited"], accessory: .chevron)
		.padding()
}

#Preview("Four tagged lines") {
	PersonRowCell(
		lines: ["Nick Banks", "Requested Levitating", "at The Fox, Chiswick", "2 hours ago"],
		accessory: .chevron,
	)
	.padding()
}

#Preview("Liked") {
	PersonRowCell(lines: ["Nick Banks"], accessory: .like(isLiked: true, summary: "You buzzed this person"))
		.padding()
}

#Preview("Dark mode") {
	PersonRowCell(lines: ["Nick Banks", "12 places visited"], accessory: .chevron)
		.padding()
		.preferredColorScheme(.dark)
}

#Preview("Accessibility text size") {
	PersonRowCell(
		lines: [
			"Nicholas Bartholomew Banks III",
			"Requested a very long song title indeed",
			"at The Fox",
			"2 hours ago",
		],
		accessory: .chevron,
	)
	.padding()
	.environment(\.dynamicTypeSize, .accessibility5)
}
