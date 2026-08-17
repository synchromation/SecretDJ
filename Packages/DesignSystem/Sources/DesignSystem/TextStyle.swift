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
	public var recipe: Recipe {
		switch self {
		case .screenTitle: Recipe(textStyle: .largeTitle, weight: .bold, design: .rounded)
		case .sectionHeader: Recipe(textStyle: .title3, weight: .semibold)
		case .cellTitle: Recipe(textStyle: .headline, weight: .semibold)
		case .cellSubtitle: Recipe(textStyle: .subheadline, weight: .regular)
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
