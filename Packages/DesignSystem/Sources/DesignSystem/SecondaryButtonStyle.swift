import SwiftUI

/// The outlined, low-emphasis button style for a secondary action alongside
/// a ``PrimaryButtonStyle`` button. Fills with a token surface on press and
/// dims to secondary tokens when disabled — both are solid token colors,
/// never opacity, so contrast never degrades.
public struct SecondaryButtonStyle: ButtonStyle {
	@Environment(\.isEnabled) private var isEnabled

	public func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.font(Theme.TextStyle.button.font)
			.foregroundStyle(contentColor)
			.padding(.horizontal, Spacing.medium)
			.frame(minWidth: 44, minHeight: 44)
			.background(fillColor(isPressed: configuration.isPressed))
			.clipShape(.capsule)
			.overlay {
				Capsule().strokeBorder(contentColor, lineWidth: 1.5)
			}
	}

	private var contentColor: Color {
		isEnabled ? Theme.ColorRole.accent.color : Theme.ColorRole.secondaryText.color
	}

	private func fillColor(isPressed: Bool) -> Color {
		isPressed && isEnabled ? Theme.ColorRole.secondaryBackground.color : .clear
	}
}

extension ButtonStyle where Self == SecondaryButtonStyle {
	public static var secondary: SecondaryButtonStyle {
		SecondaryButtonStyle()
	}
}

#Preview("Enabled") {
	Button("Not now") {}
		.buttonStyle(.secondary)
		.padding()
}

#Preview("Disabled") {
	Button("Not now") {}
		.buttonStyle(.secondary)
		.disabled(true)
		.padding()
}

#Preview("Dark mode") {
	Button("Not now") {}
		.buttonStyle(.secondary)
		.padding()
		.preferredColorScheme(.dark)
}

#Preview("Accessibility text size") {
	Button("Not now") {}
		.buttonStyle(.secondary)
		.padding()
		.environment(\.dynamicTypeSize, .accessibility5)
}
