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
			// No `lineLimit`: a single-line cap is exactly the "won't respond
			// to Dynamic Type" shape `performAccessibilityAudit()` flagged
			// here (PLAN.md S8.2) — server-driven titles are short in
			// practice, but forcing one line still fights the accessibility
			// skill's "text wraps rather than truncates" rule at large sizes.
			// S8.2-FOLLOWUP: removing the cap didn't clear the audit's
			// "Dynamic Type font sizes are partially unsupported" finding
			// for this element; the font itself is already the
			// Dynamic-Type-aware `Theme.TextStyle.sectionHeader` (semantic
			// `.title3`, never a fixed point size) — needs Accessibility
			// Inspector to see what the audit still considers unresponsive.
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
