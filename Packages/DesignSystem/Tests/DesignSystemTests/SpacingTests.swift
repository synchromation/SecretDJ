import Testing

@testable import DesignSystem

struct SpacingTests {
	@Test func `spacing scale increases from smallest to largest`() {
		#expect(Spacing.extraSmall < Spacing.small)
		#expect(Spacing.small < Spacing.medium)
		#expect(Spacing.medium < Spacing.large)
	}
}
