import SwiftUI

extension View {
	/// Presents `queue`'s current toast as a bottom overlay, VoiceOver-
	/// announcing each new toast and dismissing it early on tap.
	public func toastPresenter(queue: ToastQueue) -> some View {
		modifier(ToastPresenterModifier(queue: queue))
	}
}

private struct ToastPresenterModifier: ViewModifier {
	let queue: ToastQueue

	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	func body(content: Content) -> some View {
		content
			.overlay(alignment: .bottom) {
				if let current = queue.current {
					ToastView(item: current)
						.padding(.bottom, Spacing.large)
						.transition(transition)
						.onTapGesture { queue.dismissCurrent() }
				}
			}
			.animation(.easeInOut(duration: 0.25), value: queue.current)
			.onChange(of: queue.current) { _, newValue in
				guard let newValue else { return }

				AccessibilityNotification.Announcement(newValue.message).post()
			}
	}

	/// Reduced motion trades the slide-up for a plain cross-fade.
	private var transition: AnyTransition {
		reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity)
	}
}

#Preview("Toast presented") {
	let queue = ToastQueue(clock: ManualToastClock())

	Color.clear
		.toastPresenter(queue: queue)
		.onAppear {
			queue.enqueue(ToastItem(message: "Saved to your favourites"))
		}
}

#Preview("No toast") {
	Color.clear
		.toastPresenter(queue: ToastQueue(clock: ManualToastClock()))
}

#Preview("Dark mode") {
	let queue = ToastQueue(clock: ManualToastClock())

	Color.clear
		.toastPresenter(queue: queue)
		.onAppear {
			queue.enqueue(ToastItem(message: "Saved to your favourites"))
		}
		.preferredColorScheme(.dark)
}

#Preview("Accessibility text size") {
	let queue = ToastQueue(clock: ManualToastClock())

	Color.clear
		.toastPresenter(queue: queue)
		.onAppear {
			queue.enqueue(ToastItem(message: "Saved to your favourites — thanks for requesting"))
		}
		.environment(\.dynamicTypeSize, .accessibility5)
}
