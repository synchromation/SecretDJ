import SwiftUI

/// Renders one ``ToastItem`` on the theme's `toastSurface`/`toastText`
/// pairing. Used by ``ToastPresenterModifier``; construct directly only
/// for previews or a bespoke presentation.
public struct ToastView: View {
	let item: ToastItem

	public init(item: ToastItem) {
		self.item = item
	}

	public var body: some View {
		Text(item.message)
			.font(Theme.TextStyle.body.font)
			.foregroundStyle(Theme.ColorRole.toastText.color)
			.multilineTextAlignment(.center)
			.padding(.horizontal, Spacing.medium)
			.padding(.vertical, Spacing.small)
			.frame(minHeight: 44)
			.background {
				Capsule().fill(Theme.ColorRole.toastSurface.color)
			}
			.contentShape(.capsule)
			.accessibilityElement(children: .combine)
	}
}

#Preview("Short message") {
	ToastView(item: ToastItem(message: "Saved"))
}

#Preview("Long message") {
	ToastView(item: ToastItem(message: "X people buzzed this song — nice pick!"))
		.padding()
}

#Preview("Dark mode") {
	ToastView(item: ToastItem(message: "Saved"))
		.preferredColorScheme(.dark)
}

#Preview("Accessibility text size") {
	ToastView(item: ToastItem(message: "Saved to your favourites"))
		.padding()
		.environment(\.dynamicTypeSize, .accessibility5)
}
