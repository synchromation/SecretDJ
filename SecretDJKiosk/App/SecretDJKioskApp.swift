import DesignSystem
import SwiftUI

@main
struct SecretDJKioskApp: App {
	var body: some Scene {
		WindowGroup {
			PlaceholderRootView()
		}
	}
}

/// The kiosk's placeholder root screen, standing in for the real
/// composition root until S7 wires venue sign-in and the kiosk shell.
private struct PlaceholderRootView: View {
	var body: some View {
		Text("Kiosk coming soon")
			.font(.title)
			.multilineTextAlignment(.center)
			.padding(Spacing.medium)
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.accessibilityAddTraits(.isHeader)
	}
}

#Preview("Placeholder root") {
	PlaceholderRootView()
}
