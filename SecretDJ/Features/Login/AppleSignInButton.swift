import AuthenticationServices
import SwiftUI

/// The system Sign in with Apple button (`ASAuthorizationAppleIDButton` — the
/// control SwiftUI's `SignInWithAppleButton` itself wraps), shaped to sit
/// beside the app's own capsule primary buttons.
///
/// It reports taps rather than running the authorization itself: this flow's
/// authorization goes through ``AppleAuthorizing`` inside
/// ``AppleSignInModel``, which is what the Login feature's seams and tests
/// are built around. Apple draws, localizes, and labels the button's title
/// itself, so it carries no copy or accessibility label of ours.
struct AppleSignInButton: View {
	let action: () -> Void

	@Environment(\.colorScheme) private var colorScheme
	@ScaledMetric(relativeTo: .body)
	private var height: CGFloat = 50

	var body: some View {
		SystemAppleIDButton(
			style: colorScheme == .dark ? .white : .black,
			cornerRadius: height / 2,
			action: action,
		)
		.frame(maxWidth: .infinity)
		.frame(height: height)
		// `ASAuthorizationAppleIDButton` takes its style at construction and
		// can't be restyled afterwards, so a light/dark switch has to rebuild
		// it.
		.id(colorScheme)
	}
}

private struct SystemAppleIDButton: UIViewRepresentable {
	let style: ASAuthorizationAppleIDButton.Style
	let cornerRadius: CGFloat
	let action: () -> Void

	@Environment(\.isEnabled) private var isEnabled

	func makeCoordinator() -> Coordinator {
		Coordinator(action: action)
	}

	func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
		let button = ASAuthorizationAppleIDButton(authorizationButtonType: .signIn, authorizationButtonStyle: style)
		button.addTarget(context.coordinator, action: #selector(Coordinator.buttonTapped), for: .touchUpInside)
		return button
	}

	func updateUIView(_ button: ASAuthorizationAppleIDButton, context: Context) {
		context.coordinator.action = action
		button.cornerRadius = cornerRadius
		button.isEnabled = isEnabled
		button.alpha = isEnabled ? 1 : 0.5
	}

	final class Coordinator: NSObject {
		var action: () -> Void

		init(action: @escaping () -> Void) {
			self.action = action
		}

		@objc func buttonTapped() {
			action()
		}
	}
}

#Preview("Light") {
	AppleSignInButton {}
		.padding()
}

#Preview("Dark") {
	AppleSignInButton {}
		.padding()
		.preferredColorScheme(.dark)
}

#Preview("Disabled") {
	AppleSignInButton {}
		.disabled(true)
		.padding()
}

#Preview("Accessibility text size") {
	AppleSignInButton {}
		.padding()
		.environment(\.dynamicTypeSize, .accessibility5)
}
