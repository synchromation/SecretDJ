import SwiftUI

extension View {
	/// Wraps this view with the kiosk's hidden staff-reset affordance: an
	/// invisible tap zone in the top-left corner that, per
	/// ``StaffResetGestureModel``, needs five taps within three seconds to
	/// surface a confirmation dialog — this rewrite's replacement for
	/// legacy's `?RESTART?` search incantation (LEGACY.md "Venue login and
	/// the skin system"; PLAN.md S7.1).
	///
	/// Deliberately not a visible, labelled control: legacy's own trigger
	/// was equally undiscoverable by design (typed into a search field),
	/// and a visible "reset the kiosk" button would invite exactly the
	/// walk-up misuse the obscurity exists to prevent. `.accessibilityHidden`
	/// on the tap zone follows the same reasoning — this is a staff-only
	/// affordance, not a customer-facing control the accessibility skill's
	/// labelling rules are written for.
	func staffResetOverlay(gestureModel: StaffResetGestureModel, resetModel: StaffResetModel) -> some View {
		modifier(StaffResetOverlayModifier(gestureModel: gestureModel, resetModel: resetModel))
	}
}

private struct StaffResetOverlayModifier: ViewModifier {
	let gestureModel: StaffResetGestureModel
	let resetModel: StaffResetModel

	@State private var isConfirming = false

	func body(content: Content) -> some View {
		content
			.overlay(alignment: .topLeading) {
				Color.clear
					.frame(width: 88, height: 88)
					.contentShape(Rectangle())
					.onTapGesture(perform: handleTap)
					.accessibilityHidden(true)
			}
			.confirmationDialog(
				"Reset This Kiosk?",
				isPresented: $isConfirming,
				titleVisibility: .visible,
			) {
				Button("Reset Kiosk", role: .destructive, action: resetModel.performReset)
				Button("Cancel", role: .cancel) {}
			} message: {
				Text(
					"This signs the venue out and clears everything cached on this device. You'll need to sign in again.",
				)
			}
	}

	private func handleTap() {
		if gestureModel.recordTap() {
			isConfirming = true
		}
	}
}
