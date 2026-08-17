import Testing

@testable import SharedFeatures

import DesignSystem
import SecretDJDomain

struct SharedFeaturePlaceholderTests {
	@Test func `reflects whether the underlying feed changed`() {
		let unchanged = SharedFeaturePlaceholder(cached: FeedHash(rawValue: "a"), latest: FeedHash(rawValue: "a"))
		let changed = SharedFeaturePlaceholder(cached: FeedHash(rawValue: "a"), latest: FeedHash(rawValue: "b"))

		#expect(unchanged.needsReload == false)
		#expect(changed.needsReload)
	}

	@Test func `defaults its spacing to the design system's medium token`() {
		let placeholder = SharedFeaturePlaceholder(cached: FeedHash(rawValue: "a"), latest: FeedHash(rawValue: "a"))

		#expect(placeholder.contentSpacing == Spacing.medium)
	}
}
