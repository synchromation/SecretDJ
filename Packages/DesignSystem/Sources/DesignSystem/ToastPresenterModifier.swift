import SwiftUI

extension View {
	/// Presents `queue`'s current toast as a bottom overlay, VoiceOver-
	/// announcing each new toast and dismissing it early on tap. `appearance`
	/// defaults to ``ToastAppearance/themed``; a caller with venue-skinned
	/// chrome to honor (the kiosk: PLAN.md S7.5) passes its own resolved
	/// colors instead.
	///
	/// `richToastVipActionLabel`/`onRichToastVipTapped` wire a rich toast's
	/// VIP row (S8.6) — both default `nil`, matching every current caller
	/// (the kiosk never enqueues a rich ``ToastItem`` at all — S8.6's
	/// kiosk-exclusion citation lives on ``SharedFeatures/TuneInScreen``, so
	/// its own ``toastPresenter(queue:appearance:)`` call needs neither).
	/// The consumer app supplies both, mapping the tapped
	/// ``RichToastContent/Vip/tapActionID`` (a person id) to a real
	/// navigation action — this modifier only forwards the id, exactly like
	/// ``FeedUI/FeedActionRouter``'s own id-in, action-out shape.
	public func toastPresenter(
		queue: ToastQueue,
		appearance: ToastAppearance = .themed,
		richToastVipActionLabel: Text? = nil,
		onRichToastVipTapped: ((String) -> Void)? = nil,
	) -> some View {
		modifier(ToastPresenterModifier(
			queue: queue,
			appearance: appearance,
			richToastVipActionLabel: richToastVipActionLabel,
			onRichToastVipTapped: onRichToastVipTapped,
		))
	}
}

private struct ToastPresenterModifier: ViewModifier {
	let queue: ToastQueue
	let appearance: ToastAppearance
	let richToastVipActionLabel: Text?
	let onRichToastVipTapped: ((String) -> Void)?

	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	func body(content: Content) -> some View {
		content
			.overlay(alignment: .bottom) {
				if let current = queue.current {
					ToastView(
						item: current,
						appearance: appearance,
						vipActionLabel: richToastVipActionLabel,
						onVipTap: onVipTap,
					)
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

	/// Dismisses the toast — the same outcome tapping anywhere else on the
	/// card produces (`secretdjv3/RichToastView.swift`'s
	/// `viewVipButtonTapped`: `delegate?.richToastDidRequestViewProfile`
	/// dismisses *and* navigates) — before forwarding the tapped VIP's id to
	/// the presenting layer.
	private func onVipTap(_ tapActionID: String) {
		queue.dismissCurrent()
		onRichToastVipTapped?(tapActionID)
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

#Preview("Rich toast presented") {
	let queue = ToastQueue(clock: ManualToastClock())
	let content = RichToastContent(
		title: "Reward!",
		headline: "You earned DJ status",
		bodyText: "Thanks for checking in tonight.",
		vip: RichToastContent.Vip(
			name: "oliverk",
			subtitle: "is DJ of Bench",
			avatarURL: nil,
			tapActionID: "00000087_feae54c9",
		),
	)

	Color.clear
		.toastPresenter(
			queue: queue,
			richToastVipActionLabel: Text(verbatim: "View Profile"),
			onRichToastVipTapped: { _ in },
		)
		.onAppear {
			queue.enqueue(ToastItem(message: content.headline, richContent: content))
		}
}
