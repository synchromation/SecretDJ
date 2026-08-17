import Testing

@testable import DesignSystem

/// The contrast contract itself: every pairing `Theme` sanctions must clear
/// WCAG AA's 4.5:1 threshold for text, in both light and dark appearance.
/// This is the test the `Theme.sanctionedPairings` doc comment promises.
struct ThemeContrastTests {
	@Test(arguments: Theme.sanctionedPairings)
	func `every sanctioned pairing meets 4_5 to 1 contrast in light appearance`(pairing: Theme.ColorPairing) {
		let ratio = pairing.text.token.light.contrastRatio(against: pairing.background.token.light)

		#expect(ratio >= 4.5)
	}

	@Test(arguments: Theme.sanctionedPairings)
	func `every sanctioned pairing meets 4_5 to 1 contrast in dark appearance`(pairing: Theme.ColorPairing) {
		let ratio = pairing.text.token.dark.contrastRatio(against: pairing.background.token.dark)

		#expect(ratio >= 4.5)
	}
}
