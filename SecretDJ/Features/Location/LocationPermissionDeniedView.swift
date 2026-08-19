import DesignSystem
import Observability
import SwiftUI
import UIKit

/// The full-screen surface shown wherever location access is required and
/// denied — Places Nearby today, the venue map once S6.1 lands (LEGACY.md
/// "Tab 1 — Places Nearby": `LocationPermissionDeniedView` overlays with a
/// deep link to Settings). Built on ``DesignSystem/ErrorStateView`` rather
/// than a new DesignSystem primitive, since the open-Settings action and
/// copy are Secret DJ specific — DesignSystem's state surfaces carry no
/// copy of their own.
struct LocationPermissionDeniedView: View {
	var body: some View {
		ErrorStateView(
			systemImage: "location.slash",
			title: Text(
				"Location Access Needed",
				comment: "Title shown full-screen wherever the app needs location and access is denied or restricted.",
			),
			message: Text(
				"To find venues near you, allow Secret DJ to use your location in Settings.",
				comment: "Body shown full-screen wherever the app needs location and access is denied or restricted.",
			),
			retryTitle: Text(
				"Open Settings",
				comment: "Button that deep-links to the app's Settings page when a required permission is denied.",
			),
			retryAction: openSettings,
		)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(Theme.ColorRole.background.color)
		.tracksScreen("LocationPermissionDenied")
	}

	private func openSettings() {
		guard let url = URL(string: UIApplication.openSettingsURLString) else { return }

		UIApplication.shared.open(url)
	}
}

#Preview("Denied") {
	LocationPermissionDeniedView()
}

#Preview("Dark mode") {
	LocationPermissionDeniedView()
		.preferredColorScheme(.dark)
}

#Preview("Accessibility text size") {
	LocationPermissionDeniedView()
		.environment(\.dynamicTypeSize, .accessibility5)
}
