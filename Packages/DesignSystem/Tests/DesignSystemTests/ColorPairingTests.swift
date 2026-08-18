import Testing

@testable import DesignSystem

struct ColorPairingTests {
	@Test func `sanctioned pairings table is not empty`() {
		#expect(!Theme.sanctionedPairings.isEmpty)
	}

	@Test func `sanctioned pairings contain no duplicates`() {
		#expect(Set(Theme.sanctionedPairings).count == Theme.sanctionedPairings.count)
	}

	@Test func `every text-capable role is certified in at least one sanctioned pairing`() {
		let certifiedTextRoles = Set(Theme.sanctionedPairings.map(\.text))
		let textRoles: Set<Theme.ColorRole> = [
			.primaryText,
			.secondaryText,
			.toastText,
			.accent,
			.accentText,
			.success,
			.warning,
			.danger,
		]

		#expect(certifiedTextRoles == textRoles)
	}
}
