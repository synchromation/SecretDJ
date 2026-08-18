import DesignSystem
import SwiftUI

/// A visible section's title — VoiceOver users navigate by heading using
/// this trait (accessibility skill).
struct FeedSectionHeader: View {
	let title: String

	var body: some View {
		// title is server-driven copy that already arrives localized
		// (localization skill's server-text rule) — Text(verbatim:) keeps
		// it out of the String Catalog, same as any dynamic feed content.
		Text(verbatim: title)
			.font(Theme.TextStyle.sectionHeader.font)
			.foregroundStyle(Theme.ColorRole.primaryText.color)
			.lineLimit(1)
			.frame(maxWidth: .infinity, alignment: .leading)
			.padding(.horizontal, Spacing.medium)
			.accessibilityAddTraits(.isHeader)
	}
}

// MARK: - Previews

#Preview("Section header") {
	FeedSectionHeader(title: "Now Playing")
}

#Preview("Accessibility text size") {
	FeedSectionHeader(title: "Now Playing")
		.environment(\.dynamicTypeSize, .accessibility5)
}
