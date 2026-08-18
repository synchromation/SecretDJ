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

	/// A server-driven mood tile (``SecretDJDomain/Control``'s `fgColour`/
	/// `bgColour`) sends its color as a hex string, not a semantic token —
	/// this is the one place a raw hex string becomes a color in this design
	/// system.
	struct `Hex parsing` {
		@Test func `parses a six digit hex string with a leading hash`() throws {
			let components = try #require(Theme.RGBAComponents(hex: "#FF0000"))

			#expect(components.red == 1)
			#expect(components.green == 0)
			#expect(components.blue == 0)
			#expect(components.alpha == 1)
		}

		@Test func `parses a six digit hex string without a leading hash`() throws {
			let components = try #require(Theme.RGBAComponents(hex: "00FF00"))

			#expect(components.red == 0)
			#expect(components.green == 1)
			#expect(components.blue == 0)
		}

		@Test func `parses black and white at their extremes`() throws {
			let black = try #require(Theme.RGBAComponents(hex: "#000000"))
			let white = try #require(Theme.RGBAComponents(hex: "#FFFFFF"))

			#expect(black.relativeLuminance == 0)
			#expect(white.relativeLuminance == 1)
		}

		@Test func `fails to parse a string that isn't six hex digits`() {
			#expect(Theme.RGBAComponents(hex: "#FFF") == nil)
			#expect(Theme.RGBAComponents(hex: "#FFFFFFFF") == nil)
			#expect(Theme.RGBAComponents(hex: "") == nil)
		}

		@Test func `fails to parse a string with non hex characters`() {
			#expect(Theme.RGBAComponents(hex: "#GGGGGG") == nil)
		}
	}
}
