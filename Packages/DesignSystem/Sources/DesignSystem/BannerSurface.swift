import SwiftUI

/// The themed chrome for an edge-anchored banner (e.g. the extra-content
/// ticker) — just the surface, show/hide transition, and combined
/// accessibility element; callers supply the content.
public struct BannerSurface<Content: View>: View {
	let isVisible: Bool
	let edge: Edge
	let content: Content

	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	public init(isVisible: Bool, edge: Edge = .top, @ViewBuilder content: () -> Content) {
		self.isVisible = isVisible
		self.edge = edge
		self.content = content()
	}

	public var body: some View {
		Group {
			if isVisible {
				content
					.padding(Spacing.medium)
					.frame(maxWidth: .infinity)
					.background(Theme.ColorRole.cellSurface.color)
					.accessibilityElement(children: .combine)
					.transition(transition)
			}
		}
		.animation(.easeInOut(duration: 0.25), value: isVisible)
	}

	private var transition: AnyTransition {
		reduceMotion ? .opacity : .move(edge: edge).combined(with: .opacity)
	}
}

#Preview("Visible") {
	BannerSurface(isVisible: true) {
		Text(verbatim: "🎉 Happy hour: requests are half price until 9pm")
	}
}

#Preview("Hidden") {
	BannerSurface(isVisible: false) {
		Text(verbatim: "🎉 Happy hour: requests are half price until 9pm")
	}
}

#Preview("Dark mode") {
	BannerSurface(isVisible: true) {
		Text(verbatim: "🎉 Happy hour: requests are half price until 9pm")
	}
	.preferredColorScheme(.dark)
}

#Preview("Accessibility text size") {
	BannerSurface(isVisible: true) {
		Text(verbatim: "🎉 Happy hour: requests are half price until 9pm")
	}
	.environment(\.dynamicTypeSize, .accessibility5)
}
