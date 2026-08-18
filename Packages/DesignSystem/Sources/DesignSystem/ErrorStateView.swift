import SwiftUI

/// A themed error placeholder with an optional retry action. Carries no copy
/// of its own — callers build `title`/`message`/`retryTitle` from their own
/// String Catalog so it stays app-side.
public struct ErrorStateView: View {
	let systemImage: String
	let title: Text
	let message: Text
	let retryTitle: Text?
	let retryAction: (() -> Void)?

	@ScaledMetric(relativeTo: .largeTitle)
	private var iconSize = 40

	public init(
		systemImage: String = "exclamationmark.triangle",
		title: Text,
		message: Text,
		retryTitle: Text? = nil,
		retryAction: (() -> Void)? = nil,
	) {
		self.systemImage = systemImage
		self.title = title
		self.message = message
		self.retryTitle = retryTitle
		self.retryAction = retryAction
	}

	public var body: some View {
		VStack(spacing: Spacing.medium) {
			VStack(spacing: Spacing.medium) {
				Image(systemName: systemImage)
					.font(.system(size: iconSize))
					.foregroundStyle(Theme.ColorRole.danger.color)
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
			.accessibilityElement(children: .combine)

			if let retryTitle, let retryAction {
				Button(action: retryAction) { retryTitle }
					.buttonStyle(.primary)
			}
		}
		.padding(Spacing.large)
	}
}

#Preview("Without retry") {
	ErrorStateView(
		title: Text(verbatim: "Something went wrong"),
		message: Text(verbatim: "We couldn't load this right now"),
	)
}

#Preview("With retry") {
	ErrorStateView(
		title: Text(verbatim: "Something went wrong"),
		message: Text(verbatim: "We couldn't load this right now"),
		retryTitle: Text(verbatim: "Try again"),
		retryAction: {},
	)
}

#Preview("Dark mode") {
	ErrorStateView(
		title: Text(verbatim: "Something went wrong"),
		message: Text(verbatim: "We couldn't load this right now"),
		retryTitle: Text(verbatim: "Try again"),
		retryAction: {},
	)
	.preferredColorScheme(.dark)
}

#Preview("Accessibility text size") {
	ErrorStateView(
		title: Text(verbatim: "Something went wrong"),
		message: Text(verbatim: "We couldn't load this right now — check your connection and try again"),
		retryTitle: Text(verbatim: "Try again"),
		retryAction: {},
	)
	.environment(\.dynamicTypeSize, .accessibility5)
}
