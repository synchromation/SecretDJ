import SwiftUI

/// The colors a toast renders with — ``Theme``'s own sanctioned pairing by
/// default, or a venue skin's resolved chrome (the kiosk: PLAN.md S7.5,
/// `KioskSkin/toast`'s own doc comment on why its colors are pre-resolved
/// against contrast rather than trusted blindly).
public struct ToastAppearance: Equatable, Sendable {
	public let background: Color
	public let text: Color
	/// `nil` draws no border — ``ToastView``'s own shape has none by
	/// default, matching legacy's shared `ToastView` (LEGACY.md's kiosk
	/// toast ids 1010-1013 doc comment on `KioskSkin`).
	public let border: Color?
	public let borderWidth: CGFloat?

	public init(background: Color, text: Color, border: Color? = nil, borderWidth: CGFloat? = nil) {
		self.background = background
		self.text = text
		self.border = border
		self.borderWidth = borderWidth
	}

	/// `Theme`'s own already-sanctioned toast pairing — every call site
	/// before this type existed got this implicitly; now it's the explicit
	/// default so an app that never skins its toasts (the consumer) doesn't
	/// have to say so.
	public static let themed = ToastAppearance(
		background: Theme.ColorRole.toastSurface.color,
		text: Theme.ColorRole.toastText.color,
	)
}

/// Renders one ``ToastItem`` on `appearance`'s colors (``Theme``'s own
/// `toastSurface`/`toastText` pairing by default). Used by
/// ``ToastPresenterModifier``; construct directly only for previews or a
/// bespoke presentation.
public struct ToastView: View {
	let item: ToastItem
	let appearance: ToastAppearance

	public init(item: ToastItem, appearance: ToastAppearance = .themed) {
		self.item = item
		self.appearance = appearance
	}

	public var body: some View {
		Text(item.message)
			.font(Theme.TextStyle.body.font)
			.foregroundStyle(appearance.text)
			.multilineTextAlignment(.center)
			.padding(.horizontal, Spacing.medium)
			.padding(.vertical, Spacing.small)
			.frame(minHeight: 44)
			.background {
				Capsule().fill(appearance.background)
			}
			.overlay {
				if let border = appearance.border {
					Capsule().strokeBorder(border, lineWidth: appearance.borderWidth ?? 1)
				}
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
