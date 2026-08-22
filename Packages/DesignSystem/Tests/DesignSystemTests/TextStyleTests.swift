import Testing

@testable import DesignSystem

struct TextStyleTests {
	@Test func `every designed text style is present exactly once`() {
		#expect(Theme.TextStyle.allCases.count == 8)
	}

	@Test(arguments: zip(Theme.TextStyle.allCases, [
		Theme.TextStyle.Recipe(textStyle: .largeTitle, weight: .bold, design: .rounded),
		Theme.TextStyle.Recipe(textStyle: .title3, weight: .bold),
		Theme.TextStyle.Recipe(textStyle: .subheadline, weight: .semibold),
		Theme.TextStyle.Recipe(textStyle: .footnote, weight: .regular),
		Theme.TextStyle.Recipe(textStyle: .body, weight: .regular),
		Theme.TextStyle.Recipe(textStyle: .body, weight: .semibold, design: .rounded),
		Theme.TextStyle.Recipe(textStyle: .caption, weight: .regular),
		Theme.TextStyle.Recipe(textStyle: .caption2, weight: .regular),
	]))
	func `each text style resolves its designed recipe`(style: Theme.TextStyle, expected: Theme.TextStyle.Recipe) {
		#expect(style.recipe == expected)
	}
}
