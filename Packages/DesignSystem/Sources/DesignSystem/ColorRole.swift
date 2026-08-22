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
		/// A feed section header's title color — legacy's dark teal, never
		/// `primaryText` (S9.7).
		case sectionHeader
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
	///
	/// ### Brand provenance (S9.2)
	/// Dark appearance ports `secretdjv3/AppConfiguration.swift`'s
	/// `AppColors` verbatim wherever the legacy value itself clears
	/// `Theme.sanctionedPairings`' 4.5:1 threshold — legacy shipped
	/// dark-only, so its own values are the ground truth there. Light
	/// appearance has no legacy counterpart (it never existed): it's a
	/// systematically *derived* rendition of the same brand — the achromatic
	/// grey ladder inverted into light neutrals, and the teal accent
	/// darkened by a fixed factor until it clears AA on light surfaces —
	/// documented per token below. Where a legacy value itself fails a
	/// sanctioned pairing (`textPlaceHolder`), it's adjusted by the minimum
	/// amount needed to pass, the same mechanism S2.1 used for the brand
	/// violet accent it replaces. Every pairing's exact margin is proven by
	/// `ThemeContrastTests`; the lowest across both appearances is 4.58:1
	/// (`sectionHeader` on `background`, light — legacy's own dark teal,
	/// ported verbatim there since it already clears; see `sectionHeader`'s
	/// own case for its dark appearance, which doesn't).
	public var token: Theme.ColorToken {
		switch self {
		case .background:
			// Legacy `AppColors.darkestGrey`/`.background`/`.webviewBackground`
			// (all the same literal) ported verbatim for dark — the app's
			// base surface. Light has no legacy value; derived as a near-
			// white neutral (no legacy color is tinted, so light stays
			// achromatic too), the lightest step of the light-mode ladder
			// short of `cellSurface`.
			Theme.ColorToken(
				light: Theme.RGBAComponents(red: 250 / 255, green: 250 / 255, blue: 250 / 255),
				dark: Theme.RGBAComponents(red: 0.157, green: 0.157, blue: 0.157),
			)
		case .secondaryBackground:
			// Legacy `AppColors.darkGrey` ported verbatim for dark — the
			// lightest, most-elevated step of legacy's three-grey ladder
			// (`darkestGrey` < `darkerGrey` < `darkGrey`), reused here as the
			// most-recessed grouped-surface tier (legacy `searchBackground`,
			// 0.1725, sits between `darkestGrey` and `darkerGrey` and is
			// absorbed into `cellSurface`'s tier rather than kept distinct).
			// Light is derived as the most recessed of the three light
			// neutrals, mirroring dark's ladder direction.
			Theme.ColorToken(
				light: Theme.RGBAComponents(red: 237 / 255, green: 237 / 255, blue: 237 / 255),
				dark: Theme.RGBAComponents(red: 0.2235294118, green: 0.2235294118, blue: 0.2235294118),
			)
		case .cellSurface:
			// Legacy `AppColors.darkerGrey` ported verbatim for dark — the
			// middle step of the grey ladder, between `background` and
			// `secondaryBackground`, also the nearest neighbor to legacy's
			// `searchBackground` (0.1725). Light is derived as pure white,
			// the brightest surface, so elevated cards read as popping above
			// `background` exactly as `cellSurface`/`background`'s ordering
			// requires in both appearances.
			Theme.ColorToken(
				light: Theme.RGBAComponents(red: 1, green: 1, blue: 1),
				dark: Theme.RGBAComponents(red: 0.1882352941, green: 0.1882352941, blue: 0.1882352941),
			)
		case .toastSurface:
			// No legacy analog (legacy had no toast concept). Derived as a
			// chrome darker than every step of the grey ladder, so a toast
			// reads as a distinct floating overlay against any of this
			// role's own backgrounds rather than blending in — kept
			// identical in both appearances per this role's own contract,
			// the same "deliberately dark regardless of appearance" idea
			// legacy's own dark-only design took for granted everywhere.
			Theme.ColorToken(
				light: Theme.RGBAComponents(red: 10 / 255, green: 10 / 255, blue: 10 / 255),
				dark: Theme.RGBAComponents(red: 10 / 255, green: 10 / 255, blue: 10 / 255),
			)
		case .primaryText:
			// Legacy `AppColors.text`/`.navigationTitleText` (same 0.831
			// literal) ported verbatim for dark. Light has no legacy value;
			// derived as a neutral near-black, matching the achromatic
			// character of legacy's own palette rather than introducing a
			// tint.
			Theme.ColorToken(
				light: Theme.RGBAComponents(red: 18 / 255, green: 18 / 255, blue: 18 / 255),
				dark: Theme.RGBAComponents(red: 0.831, green: 0.831, blue: 0.831),
			)
		case .secondaryText:
			// Legacy `AppColors.textPlaceHolder` (0.345) was designed only
			// for placeholder text with no contrast guarantee: it fails
			// `secondaryBackground` at 1.62:1. Lightened to the minimum
			// grey (0.65) that clears 4.5:1 against `secondaryBackground`,
			// the tightest of the three sanctioned dark backgrounds — same
			// minimal-adjustment mechanism S2.1 used for the accent it
			// replaces. Light is derived as a mid grey clearing 4.5:1
			// against all three light backgrounds (tightest: `cellSurface`,
			// pure white).
			Theme.ColorToken(
				light: Theme.RGBAComponents(red: 100 / 255, green: 100 / 255, blue: 100 / 255),
				dark: Theme.RGBAComponents(red: 0.65, green: 0.65, blue: 0.65),
			)
		case .sectionHeader:
			// Legacy `SectionHeaderView.xib`'s `textColor` (21/255,
			// 129/255, 109/255 — a dark teal, distinct from `accent`'s
			// brighter one) ported verbatim for light: it already clears
			// `background` light at 4.58:1. Verbatim on `background`
			// dark (0.157) only reaches 3.08:1 — this role's one
			// sanctioned pairing (`Theme.sanctionedPairings`) — so dark
			// is lightened by a flat ×1.3 factor, the same
			// fixed-factor-until-it-clears-4.5:1 mechanism S2.1 used
			// for `accent`, landing at 4.92:1 with a safety margin
			// similar to that pass's own (hue preserved: green > blue >
			// red in both appearances, same as legacy).
			Theme.ColorToken(
				light: Theme.RGBAComponents(red: 21 / 255, green: 129 / 255, blue: 109 / 255),
				dark: Theme.RGBAComponents(red: 0.1071, green: 0.6576, blue: 0.5557),
			)
		case .toastText:
			// Reuses legacy `AppColors.text` (0.831) verbatim in both
			// appearances — `toastSurface` is itself deliberately dark
			// regardless of appearance, so the text drawn over it stays the
			// same legacy near-white in both too.
			Theme.ColorToken(
				light: Theme.RGBAComponents(red: 0.831, green: 0.831, blue: 0.831),
				dark: Theme.RGBAComponents(red: 0.831, green: 0.831, blue: 0.831),
			)
		case .accent:
			// Legacy `AppColors.greenBlue`/`.navigationItemText` (the brand
			// teal, also legacy's `border` at 33% alpha) ported verbatim for
			// dark — it clears all three sanctioned dark backgrounds already
			// (lowest 4.75:1, `secondaryBackground`). The same bright teal
			// fails badly against light surfaces (as low as 2.08:1): light
			// darkens it by a fixed 0.62 factor, the minimum found to clear
			// 4.5:1 against `secondaryBackground` (light's tightest
			// background) with a small safety margin, while keeping the hue
			// exactly legacy's (green > blue > red in both appearances).
			Theme.ColorToken(
				light: Theme.RGBAComponents(red: 13 / 255, green: 116 / 255, blue: 99 / 255),
				dark: Theme.RGBAComponents(red: 0.082, green: 0.733, blue: 0.624),
			)
		case .accentPressed:
			// No legacy pressed-state analog. Darkened from this
			// appearance's own `accent` by a flat 0.8 factor per channel —
			// the same factor the brand-violet predecessor used between its
			// own `accent`/`accentPressed` pair, kept for consistency.
			Theme.ColorToken(
				light: Theme.RGBAComponents(red: 10 / 255, green: 93 / 255, blue: 79 / 255),
				dark: Theme.RGBAComponents(red: 0.0656, green: 0.5864, blue: 0.4992),
			)
		case .accentText:
			// No legacy analog (legacy never drew text over a filled accent
			// button). Unchanged from the brand-violet predecessor: verified
			// to still clear 4.5:1 against the new teal `accent`/
			// `accentPressed` in both appearances (lowest 5.12:1, dark).
			Theme.ColorToken(
				light: Theme.RGBAComponents(red: 248 / 255, green: 247 / 255, blue: 251 / 255),
				dark: Theme.RGBAComponents(red: 18 / 255, green: 15 / 255, blue: 23 / 255),
			)
		case .success:
			// No legacy analog — `AppColors` defines no status colors at all.
			// Left unchanged; not part of this brand port.
			Theme.ColorToken(
				light: Theme.RGBAComponents(red: 27 / 255, green: 122 / 255, blue: 61 / 255),
				dark: Theme.RGBAComponents(red: 111 / 255, green: 219 / 255, blue: 148 / 255),
			)
		case .warning:
			// No legacy analog — see `.success`.
			Theme.ColorToken(
				light: Theme.RGBAComponents(red: 138 / 255, green: 90 / 255, blue: 0),
				dark: Theme.RGBAComponents(red: 245 / 255, green: 192 / 255, blue: 92 / 255),
			)
		case .danger:
			// No legacy analog — see `.success`.
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
