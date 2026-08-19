import DesignSystem
import SwiftUI

/// The Facebook sign-in button — unlike ``AppleSignInButton``, Facebook
/// supplies no system-drawn control to wrap, so this is a plain button in
/// the app's own secondary style, carrying its own localized title.
struct FacebookSignInButton: View {
	let action: () -> Void

	var body: some View {
		Button("Sign in with Facebook", action: action)
			.buttonStyle(.secondary)
			.frame(maxWidth: .infinity)
	}
}

#Preview("Enabled") {
	FacebookSignInButton {}
		.padding()
}

#Preview("Disabled") {
	FacebookSignInButton {}
		.disabled(true)
		.padding()
}

#Preview("Accessibility text size") {
	FacebookSignInButton {}
		.padding()
		.environment(\.dynamicTypeSize, .accessibility5)
}
