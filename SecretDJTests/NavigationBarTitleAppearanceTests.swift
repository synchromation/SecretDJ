import DesignSystem
import Testing
import UIKit

/// Coverage for ``Theme/NavigationBarTitleAppearance/scaledTitleFont(forContentSizeCategory:)``
/// — the one piece of the nav-title-appearance port pure enough to unit
/// test: given a content-size category, it deterministically returns a
/// scaled `UIFont`, with no navigation bar, window, or appearance proxy
/// involved. The appearance-application/observer wiring itself
/// (``Theme/NavigationBarTitleAppearance/apply()``,
/// ``Theme/NavigationBarTitleAppearance/observeContentSizeCategoryChanges()``)
/// is view/app-level glue exercised visually — mirroring how
/// `View+ThemedScreen`'s own bar-theming half has no unit test either.
enum NavigationBarTitleAppearanceTests {
	struct `scaledTitleFont anchors 24pt Bold at the default size category` {
		@Test func `Large (the Dynamic Type default) returns exactly the 24pt base`() {
			let font = Theme.NavigationBarTitleAppearance.scaledTitleFont(forContentSizeCategory: .large)

			#expect(font.pointSize == 24)
		}
	}

	struct `scaledTitleFont scales with the content size category` {
		@Test func `a larger accessibility category returns a font bigger than 24pt`() {
			let font = Theme.NavigationBarTitleAppearance.scaledTitleFont(
				forContentSizeCategory: .accessibilityExtraExtraExtraLarge,
			)

			#expect(font.pointSize > 24)
		}

		@Test func `a smaller category returns a font smaller than 24pt`() {
			let font = Theme.NavigationBarTitleAppearance.scaledTitleFont(forContentSizeCategory: .extraSmall)

			#expect(font.pointSize < 24)
		}

		@Test func `point size is monotonically non-decreasing across the full category scale`() {
			// Asserts the shape of the curve (never smaller at a larger
			// category) without hardcoding Apple's own internal per-category
			// point-size table as an expected value — that table is
			// `UIFontMetrics`' implementation detail, not this function's
			// contract.
			let categories: [UIContentSizeCategory] = [
				.extraSmall, .small, .medium, .large, .extraLarge,
				.extraExtraLarge, .extraExtraExtraLarge,
				.accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge,
				.accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge,
			]

			let sizes = categories
				.map { Theme.NavigationBarTitleAppearance.scaledTitleFont(forContentSizeCategory: $0).pointSize }

			#expect(sizes == sizes.sorted())
		}
	}
}
