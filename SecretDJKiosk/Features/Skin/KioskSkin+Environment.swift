import DesignSystem
import SwiftUI

extension KioskSkin {
	/// Every value falls back to `DesignSystem` theming, with no downloaded
	/// images — the environment default before ``KioskSkinGateView`` injects
	/// a resolved skin, and what previews get when they don't inject one
	/// explicitly.
	static let themeDefault = KioskSkin(
		toast: ResolvedToastAppearance(
			background: .themeFallback(.toastSurface),
			text: .themeFallback(.toastText),
			border: nil,
			borderWidth: nil,
		),
		headerTint: .themeFallback(.accent),
		headerBackgroundImageURL: nil,
		headerHeight: nil,
	)
}

extension EnvironmentValues {
	/// The venue skin's resolved chrome — S7.3+ screens read this the same
	/// way they already read `\.observability`, never reaching for
	/// ``SecretDJAPI/SkinManifest`` directly. Defaults to
	/// ``KioskSkin/themeDefault`` so anything rendered before
	/// ``KioskSkinGateView`` injects the real value (or a preview that
	/// doesn't bother) still gets a fully themed, legible result.
	@Entry var kioskSkin = KioskSkin.themeDefault
}
