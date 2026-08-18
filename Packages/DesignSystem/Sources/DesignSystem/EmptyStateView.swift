import SwiftUI

/// A themed placeholder for a screen or section with nothing to show. Carries
/// no copy of its own — callers build `title`/`message` from their own
/// String Catalog so it stays app-side.
public struct EmptyStateView: View {
	let systemImage: String
	let title: Text
	let message: Text

	@ScaledMetric(relativeTo: .largeTitle)
	private var iconSize = 40

	public init(systemImage: String, title: Text, message: Text) {
		self.systemImage = systemImage
		self.title = title
		self.message = message
	}

	public var body: some View {
		VStack(spacing: Spacing.medium) {
			Image(systemName: systemImage)
				.font(.system(size: iconSize))
				.foregroundStyle(Theme.ColorRole.secondaryText.color)
				.accessibilityHidden(true)

			title
				.font(Theme.TextStyle.sectionHeader.font)
				.foregroundStyle(Theme.ColorRole.primaryText.color)
				.multilineTextAlignment(.center)

			message
				.font(Theme.TextStyle.body.font)
				.foregroundStyle(Theme.ColorRole.secondaryText.color)
				.multilineTextAlignment(.center)
		}
		.padding(Spacing.large)
		.accessibilityElement(children: .combine)
	}
}

#Preview("Empty search") {
	EmptyStateView(
		systemImage: "magnifyingglass",
		title: Text(verbatim: "No results"),
		message: Text(verbatim: "Try a different search"),
	)
}

#Preview("Dark mode") {
	EmptyStateView(
		systemImage: "magnifyingglass",
		title: Text(verbatim: "No results"),
		message: Text(verbatim: "Try a different search"),
	)
	.preferredColorScheme(.dark)
}

#Preview("Accessibility text size") {
	EmptyStateView(
		systemImage: "magnifyingglass",
		title: Text(verbatim: "No results"),
		message: Text(verbatim: "Try changing your filters or searching for something else"),
	)
	.environment(\.dynamicTypeSize, .accessibility5)
}
