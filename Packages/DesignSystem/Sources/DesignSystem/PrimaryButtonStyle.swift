import SwiftUI

/// The filled, high-emphasis button style for a screen's primary action.
/// Darkens on press and dims to secondary tokens when disabled — both are
/// solid token colors, never opacity, so contrast never degrades.
public struct PrimaryButtonStyle: ButtonStyle {
	@Environment(\.isEnabled) private var isEnabled

	public func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.font(Theme.TextStyle.button.font)
			.foregroundStyle(foregroundColor)
			.padding(.horizontal, Spacing.medium)
			.frame(minWidth: 44, minHeight: 44)
			.background(backgroundColor(isPressed: configuration.isPressed))
			.clipShape(.capsule)
	}

	private var foregroundColor: Color {
		isEnabled ? Theme.ColorRole.accentText.color : Theme.ColorRole.secondaryText.color
	}

	private func backgroundColor(isPressed: Bool) -> Color {
		guard isEnabled else { return Theme.ColorRole.secondaryBackground.color }

		return isPressed ? Theme.ColorRole.accentPressed.color : Theme.ColorRole.accent.color
	}
}

extension ButtonStyle where Self == PrimaryButtonStyle {
	public static var primary: PrimaryButtonStyle {
		PrimaryButtonStyle()
	}
}

#Preview("Enabled") {
	Button("Request song") {}
		.buttonStyle(.primary)
		.padding()
}

#Preview("Disabled") {
	Button("Request song") {}
		.buttonStyle(.primary)
		.disabled(true)
		.padding()
}

#Preview("Dark mode") {
	Button("Request song") {}
		.buttonStyle(.primary)
		.padding()
		.preferredColorScheme(.dark)
}

#Preview("Accessibility text size") {
	Button("Request song") {}
		.buttonStyle(.primary)
		.padding()
		.environment(\.dynamicTypeSize, .accessibility5)
}
