import Testing

@testable import DesignSystem

enum RGBAComponentsTests {
	struct `Relative luminance` {
		@Test func `pure white has the maximum relative luminance of one`() {
			let white = Theme.RGBAComponents(red: 1, green: 1, blue: 1)

			#expect(white.relativeLuminance == 1)
		}

		@Test func `pure black has the minimum relative luminance of zero`() {
			let black = Theme.RGBAComponents(red: 0, green: 0, blue: 0)

			#expect(black.relativeLuminance == 0)
		}
	}

	struct `Contrast ratio` {
		@Test func `black against white is the maximum WCAG ratio of 21 to 1`() {
			let black = Theme.RGBAComponents(red: 0, green: 0, blue: 0)
			let white = Theme.RGBAComponents(red: 1, green: 1, blue: 1)

			#expect(abs(black.contrastRatio(against: white) - 21) < 0.01)
		}

		@Test func `a color against itself is the minimum WCAG ratio of 1 to 1`() {
			let gray = Theme.RGBAComponents(red: 0.5, green: 0.5, blue: 0.5)

			#expect(abs(gray.contrastRatio(against: gray) - 1) < 0.0001)
		}

		@Test func `contrast ratio is symmetric regardless of argument order`() {
			let a = Theme.RGBAComponents(red: 0.2, green: 0.4, blue: 0.6)
			let b = Theme.RGBAComponents(red: 0.9, green: 0.9, blue: 0.9)

			#expect(a.contrastRatio(against: b) == b.contrastRatio(against: a))
		}
	}
}
