import DesignSystem
import Observability
import SwiftUI

/// The calm terminal screen shown once `requestdeleteaccount` has succeeded
/// and the local session has been wiped — replaces legacy's blocking alert
/// + `exit(0)` gate (LEGACY.md "Consumer app: features and flows" →
/// Settings). It offers nothing but closing: no client-side blocked-state
/// flag is persisted anywhere (``AccountModel``'s doc comment), so there is
/// nothing further for this screen, or the app, to gate on. The server's
/// own confirmation copy isn't surfaced verbatim — it's unconfirmed and
/// unlocalized (``AccountDeletionOutcome``'s doc comment) — this copy is
/// authored and translated instead.
struct AccountDeletionRequestedView: View {
	let onClose: () -> Void

	var body: some View {
		VStack(spacing: Spacing.large) {
			Text("Deletion Requested")
				.font(Theme.TextStyle.screenTitle.font)
				.foregroundStyle(Theme.ColorRole.primaryText.color)

			Text(
				"We've received your request and we're processing it. You've been signed out of this device, and there's nothing more for you to do here.",
			)
			.font(Theme.TextStyle.body.font)
			.foregroundStyle(Theme.ColorRole.secondaryText.color)
			.multilineTextAlignment(.center)

			Button("Close", action: onClose)
				.buttonStyle(.primary)
		}
		.padding(Spacing.large)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.themedScreen()
		.tracksScreen("AccountDeletionRequested")
	}
}

#Preview("Deletion requested") {
	AccountDeletionRequestedView(onClose: {})
}

#Preview("Accessibility text size") {
	AccountDeletionRequestedView(onClose: {})
		.environment(\.dynamicTypeSize, .accessibility5)
}
