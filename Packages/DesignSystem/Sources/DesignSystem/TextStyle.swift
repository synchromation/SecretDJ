import SwiftUI

extension Theme {
	/// A semantic text style, always backed by a Dynamic-Type-aware system
	/// font recipe — never a fixed point size.
	public enum TextStyle: CaseIterable, Sendable {
		/// A screen's primary heading, e.g. a tab's navigation title.
		case screenTitle
		/// Introduces a section of related content within a screen.
		case sectionHeader
		/// A cell's primary line — the song, venue, or person name.
		case cellTitle
		/// A cell's supporting line — an artist, distance, or timestamp.
		case cellSubtitle
		/// Standard reading text for paragraphs and descriptions.
		case body
		/// A button's label.
		case button
		/// The smallest supporting text — counts, timestamps, fine print.
		case caption
	}
}

extension Theme.TextStyle {
	/// The Dynamic-Type text style, weight, and design that build a token's
	/// `font`; only weight and design vary between tokens, so Dynamic Type
	/// scaling can never be overridden with a fixed size.
	public struct Recipe: Equatable, Sendable {
		public let textStyle: Font.TextStyle
		public let weight: Font.Weight
		public let design: Font.Design

		public init(textStyle: Font.TextStyle, weight: Font.Weight, design: Font.Design = .default) {
			self.textStyle = textStyle
			self.weight = weight
			self.design = design
		}
	}

	/// This style's underlying recipe.
	///
	/// ### Legacy metrics (S9.5)
	/// `sectionHeader`'s `.title3` (20pt at the default, `.large`, Dynamic
	/// Type size) already lands exactly on `StyleKit2023.SectionHeaderFont`
	/// (`secretdjv3/StyleKit2023.swift:50`, `HelveticaNeue-Bold` 20pt) — no
	/// change needed there. `cellTitle`/`cellSubtitle` did not: the legacy
	/// flat cell family (`secretdjv3/Cells/SongCollectionViewCell.xib`,
	/// `VenueCollectionViewCell.xib`, `AwardCollectionViewCell.xib`,
	/// `CheckInCollectionViewCell.xib`, `NewsItemCollectionViewCell.xib`,
	/// `PPPCollectionViewCell.xib` — every cell `FeedSectionKind.list` maps
	/// to) sets its title line at 15pt (`HelveticaNeue-Medium`) and its
	/// subtitle line at 13pt (`HelveticaNeue-Light`). Per the accessibility
	/// skill's "semantic style first" rule: `.subheadline` and `.footnote`
	/// resolve to exactly 15pt/13pt at the default size already (Apple's own
	/// published Dynamic Type scale), so both cases move onto those system
	/// styles rather than reaching for a `@ScaledMetric`-seeded fixed size —
	/// still perfectly Dynamic-Type-responsive, just point-for-point legacy
	/// at `.large`. Weight keeps this design's own semibold/regular pair
	/// (legacy's Medium/Light HelveticaNeue weights have no exact SF
	/// equivalent; matching *size* is this pass's scope, not hunting for a
	/// weight that isn't expressible in the system font).
	public var recipe: Recipe {
		switch self {
		case .screenTitle: Recipe(textStyle: .largeTitle, weight: .bold, design: .rounded)
		case .sectionHeader: Recipe(textStyle: .title3, weight: .semibold)
		case .cellTitle: Recipe(textStyle: .subheadline, weight: .semibold)
		case .cellSubtitle: Recipe(textStyle: .footnote, weight: .regular)
		case .body: Recipe(textStyle: .body, weight: .regular)
		case .button: Recipe(textStyle: .body, weight: .semibold, design: .rounded)
		case .caption: Recipe(textStyle: .caption, weight: .regular)
		}
	}

	/// The Dynamic-Type-aware system font for this token.
	public var font: Font {
		Font.system(recipe.textStyle, design: recipe.design).weight(recipe.weight)
	}
}
