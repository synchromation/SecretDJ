extension Theme {
	/// A text role certified legible when drawn over a specific background role.
	public struct ColorPairing: Equatable, Hashable, Sendable {
		public let text: ColorRole
		public let background: ColorRole

		public init(text: ColorRole, background: ColorRole) {
			self.text = text
			self.background = background
		}
	}
}

extension Theme {
	/// The contrast contract: every pairing listed here is proven —
	/// by `ThemeContrastTests` — to meet the WCAG AA threshold of 4.5:1
	/// contrast in both light and dark appearance. This table is the only
	/// sanctioned way to combine a text role with a background role in either
	/// app; a new combination is added here first, which pins the contrast
	/// suite to fail until the underlying colors are tuned to pass.
	public static let sanctionedPairings: [ColorPairing] = [
		ColorPairing(text: .primaryText, background: .background),
		ColorPairing(text: .secondaryText, background: .background),
		ColorPairing(text: .primaryText, background: .secondaryBackground),
		ColorPairing(text: .secondaryText, background: .secondaryBackground),
		ColorPairing(text: .primaryText, background: .cellSurface),
		ColorPairing(text: .secondaryText, background: .cellSurface),
		ColorPairing(text: .accent, background: .background),
		ColorPairing(text: .accent, background: .cellSurface),
		ColorPairing(text: .accent, background: .secondaryBackground),
		ColorPairing(text: .accentText, background: .accent),
		ColorPairing(text: .accentText, background: .accentPressed),
		ColorPairing(text: .success, background: .background),
		ColorPairing(text: .success, background: .cellSurface),
		ColorPairing(text: .warning, background: .background),
		ColorPairing(text: .warning, background: .cellSurface),
		ColorPairing(text: .danger, background: .background),
		ColorPairing(text: .danger, background: .cellSurface),
		ColorPairing(text: .toastText, background: .toastSurface),
	]
}
