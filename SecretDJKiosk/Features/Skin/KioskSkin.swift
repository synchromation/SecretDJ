import DesignSystem
import Foundation
import SecretDJAPI
import SwiftUI

/// One resolved chrome color: either the venue skin's own value, or a
/// documented ``Theme`` fallback — used both when the skin simply didn't
/// configure a role, and when it did but (for a text-bearing pairing) its
/// contrast couldn't be trusted. Carrying the *reason* alongside the color
/// (rather than resolving straight to a `Color`) is what makes
/// ``KioskSkinTests`` able to assert on provenance, not just the pixel that
/// happens to come out.
enum ResolvedSkinColor: Equatable {
	case skin(Theme.RGBAComponents)
	case themeFallback(Theme.ColorRole)

	/// The literal color to render, resolving a theme fallback dynamically
	/// (light/dark) and a skin color as the single fixed value the server
	/// sent (``Theme/RGBAComponents/color``'s own doc comment: "never
	/// adapts to appearance").
	var color: Color {
		switch self {
		case .skin(let components): components.color
		case .themeFallback(let role): role.color
		}
	}
}

/// The kiosk toast's resolved chrome (`secretdjv3/SimpleToastView.swift`'s
/// `initializeKioskAttributes`; LEGACY.md's ids 1010-1013). `border` is
/// `nil` when the skin didn't configure one — legacy's shared `ToastView`
/// (``DesignSystem/ToastView``) draws no border at all, so "no border" is a
/// legitimate resolved state, not a failure needing a fallback.
struct ResolvedToastAppearance: Equatable {
	let background: ResolvedSkinColor
	let text: ResolvedSkinColor
	let border: ResolvedSkinColor?
	let borderWidth: Int?
}

/// The venue skin's chrome, reconciled with `DesignSystem` theming per D10:
/// the manifest's typed color roles are honored where this build has a use
/// for them (toast chrome, the now-playing header — PLAN.md S7.2's exact
/// list), and `DesignSystem` owns everything else (typography, spacing,
/// every other color role) — a skin never overrides more than these
/// values. Resolved once per downloaded (or persisted) manifest and
/// injected via environment (``EnvironmentValues/kioskSkin``), so S7.3+
/// screens read it the same way they already read `\.observability`,
/// never reaching for ``SecretDJAPI/SkinManifest`` directly.
///
/// ### Contrast responsibility
/// A server-supplied color can't be proven to contrast with the text drawn
/// over it at build time the way ``Theme/sanctionedPairings`` can — a venue
/// could in principle configure a toast whose text and background fail
/// WCAG AA. ``resolve(manifest:imageFileURLs:)`` runs the exact
/// ``Theme/RGBAComponents/contrastRatio(against:)`` math
/// `ThemeContrastTests` already proves the app's own pairings with against
/// the skin's toast text/background pair at runtime; a pairing that fails
/// 4.5:1 (or a value that's missing or fails to parse) falls back to
/// ``Theme``'s own already-sanctioned toast pairing (`toastText` on
/// `toastSurface`) for *both* colors together — never one from the skin and
/// one from the theme, which could reintroduce the very failure being
/// guarded against. The other resolved color here, the now-playing header's
/// tint, has no known solid background to check against (it sits over
/// artwork/an image, not a flat surface) — it isn't a text-on-background
/// pairing, so no contrast check applies; it simply defaults to
/// `Theme.ColorRole.accent` when the skin doesn't specify one.
struct KioskSkin: Equatable {
	/// WCAG AA's threshold for text — the same constant
	/// `ThemeContrastTests` checks `Theme.sanctionedPairings` against.
	static let minimumContrastRatio = 4.5

	let toast: ResolvedToastAppearance
	/// The now-playing header's tint — not a text pairing (see the type's
	/// contrast-responsibility doc comment), so it has no runtime check.
	let headerTint: ResolvedSkinColor
	/// The now-playing header's background image, when the skin configured
	/// one and it downloaded successfully — `nil` means the header falls
	/// back to whatever `DesignSystem`/S7.4 renders in its absence.
	let headerBackgroundImageURL: URL?
	/// The now-playing header's skinnable height, in points
	/// (``SecretDJAPI/SkinManifest/headerHeight``). `nil` means "use
	/// `DesignSystem`'s own default" — S7.4's decision, not this type's.
	let headerHeight: Int?

	/// Resolves a freshly downloaded manifest, before it's ever been
	/// persisted — `imageFileURLs` are the local files ``SkinModel`` just
	/// finished writing (the manifest itself only carries the *remote*
	/// URLs it downloaded them from).
	static func resolve(manifest: SkinManifest, imageFileURLs: [Int: URL]) -> KioskSkin {
		resolveCore(
			colors: manifest.colors,
			toastBackground: manifest.toast?.backgroundColor,
			toastText: manifest.toast?.textColor,
			toastBorder: manifest.toast?.borderColor,
			toastBorderWidth: manifest.toast?.borderWidth,
			headerHeight: manifest.headerHeight,
			imageFileURLs: imageFileURLs,
		)
	}

	/// Resolves a previously persisted skin, on a relaunch that skipped the
	/// network entirely (``SkinStoring/loadSnapshot(venueId:)``) — identical
	/// result to ``resolve(manifest:imageFileURLs:)`` for the same venue,
	/// since a ``SkinSnapshot`` carries exactly the fields that call reads.
	static func resolve(snapshot: SkinSnapshot) -> KioskSkin {
		resolveCore(
			colors: snapshot.colors,
			toastBackground: snapshot.toastBackgroundColor,
			toastText: snapshot.toastTextColor,
			toastBorder: snapshot.toastBorderColor,
			toastBorderWidth: snapshot.toastBorderWidth,
			headerHeight: snapshot.headerHeight,
			imageFileURLs: snapshot.imageFileURLs,
		)
	}

	private static func resolveCore(
		colors: [SkinColorRole: String],
		toastBackground: String?,
		toastText: String?,
		toastBorder: String?,
		toastBorderWidth: Int?,
		headerHeight: Int?,
		imageFileURLs: [Int: URL],
	) -> KioskSkin {
		KioskSkin(
			toast: resolveToast(
				background: toastBackground,
				text: toastText,
				border: toastBorder,
				borderWidth: toastBorderWidth,
			),
			headerTint: colors[.nowPlayingTint]
				.flatMap(Theme.RGBAComponents.init(argbHex:))
				.map(ResolvedSkinColor.skin) ?? .themeFallback(.accent),
			headerBackgroundImageURL: imageFileURLs[SkinAssetRole.nowPlayingBackground.rawValue],
			headerHeight: headerHeight,
		)
	}

	private static func resolveToast(
		background backgroundHex: String?,
		text textHex: String?,
		border borderHex: String?,
		borderWidth: Int?,
	) -> ResolvedToastAppearance {
		let border = borderHex.flatMap(Theme.RGBAComponents.init(argbHex:)).map(ResolvedSkinColor.skin)

		guard let background = backgroundHex.flatMap(Theme.RGBAComponents.init(argbHex:)),
		      let text = textHex.flatMap(Theme.RGBAComponents.init(argbHex:)),
		      text.contrastRatio(against: background) >= minimumContrastRatio else
		{
			return ResolvedToastAppearance(
				background: .themeFallback(.toastSurface),
				text: .themeFallback(.toastText),
				border: border,
				borderWidth: borderWidth,
			)
		}

		return ResolvedToastAppearance(
			background: .skin(background),
			text: .skin(text),
			border: border,
			borderWidth: borderWidth,
		)
	}
}
