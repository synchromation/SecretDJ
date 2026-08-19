import SwiftUI

extension View {
	/// Wraps this view with S7.3's scene-level interaction observer and
	/// attract-screen overlay: any touch anywhere in `content` reaches
	/// ``IdleTimerModel/recordInteraction()`` without being consumed, and
	/// ``AttractScreen`` covers everything once ``IdleTimerModel/isShowingAttract``
	/// goes true.
	///
	/// **Why a gesture, not a `UIApplication` subclass**: legacy's
	/// `KioskApplication.swift` overrode `sendEvent(_:)` to broadcast every
	/// touch app-wide (LEGACY.md "Boot and composition") — the only way to
	/// observe touches globally in a UIKit app that predates scenes. This
	/// app has no `UIApplication` subclass at all (S7.1's shell is a plain
	/// `@main App`), and reintroducing one just for touch observation would
	/// be strictly more machinery than SwiftUI needs: a
	/// `DragGesture(minimumDistance: 0)` attached via `.simultaneousGesture`
	/// fires on touch-down without ever winning the gesture (so it never
	/// blocks a button, a tap, or a scroll underneath it — the exact
	/// "coexists with everything, consumes nothing" property the touch
	/// broadcast had), attached once here at the root the same way
	/// `staffResetOverlay(gestureModel:resetModel:)` already wraps the
	/// whole kiosk content for its own gesture. The one place this doesn't
	/// reach is inside ``AttractScreen``'s own `WKWebView` — UIKit views
	/// embedded via `UIViewRepresentable` don't participate in SwiftUI's
	/// gesture system — which is exactly why that screen's dismiss is its
	/// own explicit ``Button`` calling ``IdleTimerModel/recordInteraction()``
	/// directly rather than depending on this gesture to notice the tap.
	func attractIdleOverlay(model: IdleTimerModel, attractURL: URL?) -> some View {
		modifier(AttractIdleOverlayModifier(model: model, attractURL: attractURL))
	}
}

private struct AttractIdleOverlayModifier: ViewModifier {
	let model: IdleTimerModel
	let attractURL: URL?

	func body(content: Content) -> some View {
		content
			.simultaneousGesture(
				DragGesture(minimumDistance: 0)
					.onChanged { _ in model.recordInteraction() },
			)
			.overlay {
				if model.isShowingAttract, let attractURL {
					AttractScreen(url: attractURL, onDismiss: model.recordInteraction)
						.transition(.opacity)
				}
			}
			.animation(.default, value: model.isShowingAttract)
	}
}
