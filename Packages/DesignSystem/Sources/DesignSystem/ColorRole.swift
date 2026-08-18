import SwiftUI

extension Theme {
	/// A semantic color role backed by explicit sRGB components — views
	/// reach for a role, never a raw color.
	public enum ColorRole: CaseIterable, Hashable, Sendable {
		/// The full-screen backdrop content sits on.
		case background
		/// A grouped or inset surface distinguished from `background`, e.g.
		/// behind a settings list.
		case secondaryBackground
		/// The elevated surface behind feed and list cells.
		case cellSurface
		/// The surface behind a transient toast banner — deliberately the
		/// same dark chrome in both appearances.
		case toastSurface
		/// The default reading color for titles and body copy.
		case primaryText
		/// A de-emphasized reading color for supporting copy, e.g. subtitles
		/// and metadata.
		case secondaryText
		/// The text color drawn on `toastSurface`.
		case toastText
		/// The brand color for interactive elements and highlighted content.
		case accent
		/// A darkened `accent`, e.g. a filled button's background while pressed.
		case accentPressed
		/// The text/icon color drawn on `accent` or `accentPressed`, e.g. a
		/// primary button's label.
		case accentText
		/// Signals a positive or confirming outcome, e.g. a completed request.
		case success
		/// Signals a cautionary state that needs attention but isn't an error.
		case warning
		/// Signals a destructive action or error state.
		case danger
	}
}

extension Theme.ColorRole {
	/// This role's light and dark sRGB components.
	public var token: Theme.ColorToken {
		switch self {
		case .background:
			Theme.ColorToken(
				light: Theme.RGBAComponents(red: 250 / 255, green: 250 / 255, blue: 252 / 255),
				dark: Theme.RGBAComponents(red: 11 / 255, green: 10 / 255, blue: 14 / 255),
			)
		case .secondaryBackground:
			Theme.ColorToken(
				light: Theme.RGBAComponents(red: 240 / 255, green: 239 / 255, blue: 243 / 255),
				dark: Theme.RGBAComponents(red: 22 / 255, green: 20 / 255, blue: 27 / 255),
			)
		case .cellSurface:
			Theme.ColorToken(
				light: Theme.RGBAComponents(red: 1, green: 1, blue: 1),
				dark: Theme.RGBAComponents(red: 29 / 255, green: 27 / 255, blue: 35 / 255),
			)
		case .toastSurface:
			Theme.ColorToken(
				light: Theme.RGBAComponents(red: 27 / 255, green: 25 / 255, blue: 32 / 255),
				dark: Theme.RGBAComponents(red: 40 / 255, green: 37 / 255, blue: 47 / 255),
			)
		case .primaryText:
			Theme.ColorToken(
				light: Theme.RGBAComponents(red: 18 / 255, green: 15 / 255, blue: 23 / 255),
				dark: Theme.RGBAComponents(red: 248 / 255, green: 247 / 255, blue: 251 / 255),
			)
		case .secondaryText:
			Theme.ColorToken(
				light: Theme.RGBAComponents(red: 92 / 255, green: 88 / 255, blue: 102 / 255),
				dark: Theme.RGBAComponents(red: 182 / 255, green: 178 / 255, blue: 192 / 255),
			)
		case .toastText:
			Theme.ColorToken(
				light: Theme.RGBAComponents(red: 250 / 255, green: 250 / 255, blue: 252 / 255),
				dark: Theme.RGBAComponents(red: 250 / 255, green: 250 / 255, blue: 252 / 255),
			)
		case .accent:
			Theme.ColorToken(
				light: Theme.RGBAComponents(red: 108 / 255, green: 43 / 255, blue: 217 / 255),
				dark: Theme.RGBAComponents(red: 180 / 255, green: 156 / 255, blue: 250 / 255),
			)
		case .accentPressed:
			Theme.ColorToken(
				light: Theme.RGBAComponents(red: 86 / 255, green: 34 / 255, blue: 174 / 255),
				dark: Theme.RGBAComponents(red: 144 / 255, green: 125 / 255, blue: 200 / 255),
			)
		case .accentText:
			Theme.ColorToken(
				light: Theme.RGBAComponents(red: 248 / 255, green: 247 / 255, blue: 251 / 255),
				dark: Theme.RGBAComponents(red: 18 / 255, green: 15 / 255, blue: 23 / 255),
			)
		case .success:
			Theme.ColorToken(
				light: Theme.RGBAComponents(red: 27 / 255, green: 122 / 255, blue: 61 / 255),
				dark: Theme.RGBAComponents(red: 111 / 255, green: 219 / 255, blue: 148 / 255),
			)
		case .warning:
			Theme.ColorToken(
				light: Theme.RGBAComponents(red: 138 / 255, green: 90 / 255, blue: 0),
				dark: Theme.RGBAComponents(red: 245 / 255, green: 192 / 255, blue: 92 / 255),
			)
		case .danger:
			Theme.ColorToken(
				light: Theme.RGBAComponents(red: 179 / 255, green: 38 / 255, blue: 30 / 255),
				dark: Theme.RGBAComponents(red: 255 / 255, green: 155 / 255, blue: 147 / 255),
			)
		}
	}

	/// The dynamic SwiftUI color for this role.
	public var color: Color {
		token.color
	}
}
