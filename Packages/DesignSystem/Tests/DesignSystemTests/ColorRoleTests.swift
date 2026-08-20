import Testing

@testable import DesignSystem

struct ColorRoleTests {
	@Test(arguments: Theme.ColorRole.allCases)
	func `every role resolves valid zero to one RGBA components in both appearances`(role: Theme.ColorRole) {
		let token = role.token

		for components in [token.light, token.dark] {
			#expect((0 ... 1).contains(components.red))
			#expect((0 ... 1).contains(components.green))
			#expect((0 ... 1).contains(components.blue))
			#expect((0 ... 1).contains(components.alpha))
		}
	}

	@Test func `background is a near-white surface in light and a deep charcoal in dark`() {
		let token = Theme.ColorRole.background.token

		#expect(token.light.relativeLuminance > 0.9)
		#expect(token.dark.relativeLuminance < 0.05)
	}

	@Test func `cell surface sits above background on the elevation scale in both appearances`() {
		let background = Theme.ColorRole.background.token
		let cellSurface = Theme.ColorRole.cellSurface.token

		#expect(cellSurface.light.relativeLuminance > background.light.relativeLuminance)
		#expect(cellSurface.dark.relativeLuminance > background.dark.relativeLuminance)
	}

	@Test func `accent stays a distinguishable teal in both appearances`() {
		let token = Theme.ColorRole.accent.token

		for components in [token.light, token.dark] {
			#expect(components.green > components.blue)
			#expect(components.blue > components.red)
		}
	}

	@Test func `toast text is intentionally identical near-white text regardless of appearance`() {
		let token = Theme.ColorRole.toastText.token

		#expect(token.light == token.dark)
		#expect(token.light.relativeLuminance > 0.6)
	}
}
