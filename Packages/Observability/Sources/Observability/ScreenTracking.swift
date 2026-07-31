import SwiftUI

extension EnvironmentValues {
	/// The pipeline views use for screen tracking; the composition root
	/// injects the real one, so previews default to silence.
	@Entry public var observability = ObservabilityPipeline.disabled
}

extension View {
	/// Records a screen breadcrumb each time this view appears.
	///
	/// Apply once, to the root view of each screen the user would name.
	public func tracksScreen(_ name: String) -> some View {
		modifier(ScreenTracking(name: name))
	}
}

private struct ScreenTracking: ViewModifier {
	@Environment(\.observability) private var observability

	let name: String

	func body(content: Content) -> some View {
		content.onAppear {
			observability.screen(name)
		}
	}
}
