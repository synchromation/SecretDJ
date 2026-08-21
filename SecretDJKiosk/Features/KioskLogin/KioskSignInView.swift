import DesignSystem
import Observability
import SwiftUI

/// The kiosk's venue sign-in screen: screen name and password only — no
/// sign-up, Apple/Facebook, or forgotten-password routes (LEGACY.md
/// "Venue login and the skin system": legacy's `KioskLoginViewController`
/// is "a plain username/password form, no Facebook/Apple sign-in on
/// kiosk"; venue accounts are provisioned out of band and entered once by
/// staff).
///
/// "Kiosk-scale" here means generous field/button heights and a
/// comfortably wide, centered card for a landscape iPad at arm's length —
/// not fixed font sizes: `DesignSystem` has no kiosk-specific text styles
/// yet (that reconciliation is D10/S7.2's job), so this screen stays on
/// the same Dynamic-Type-aware tokens every other screen uses.
struct KioskSignInView: View {
	let model: KioskSignInModel

	@FocusState private var focusedField: Field?

	private enum Field {
		case screenName
		case password
	}

	var body: some View {
		VStack(spacing: Spacing.large) {
			Text("Venue Sign In", comment: "Title on the kiosk's venue sign-in screen.")
				.font(Theme.TextStyle.screenTitle.font)
				.foregroundStyle(Theme.ColorRole.primaryText.color)
				.accessibilityAddTraits(.isHeader)

			fields

			signInButton

			if let errorMessage = model.errorMessage {
				errorText(errorMessage)
			}
		}
		.padding(Spacing.large)
		.frame(maxWidth: 560)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.themedScreen()
		.tracksScreen("KioskSignIn")
	}

	private var fields: some View {
		VStack(spacing: Spacing.medium) {
			TextField("Venue screen name", text: Binding(get: { model.screenName }, set: model.updateScreenName))
				.textContentType(.username)
				.textInputAutocapitalization(.never)
				.autocorrectionDisabled()
				.focused($focusedField, equals: .screenName)
				.submitLabel(.next)
				.onSubmit { focusedField = .password }
				.font(Theme.TextStyle.body.font)
				.padding(Spacing.medium)
				.frame(minHeight: 64)
				.background(Theme.ColorRole.cellSurface.color, in: .rect(cornerRadius: 12))

			// S8.2-FOLLOWUP: performAccessibilityAudit() flags this field's
			// text as possibly clipped at larger Dynamic Type sizes
			// (SwiftUI.UIKitTextField) — mirrors the consumer app's own
			// LoginView password field (`SecretDJ/Features/Login/LoginView.swift`'s
			// own `// S8.2-FOLLOWUP:` comment); the plain TextField above
			// shares identical layout and passes clean, so this looks like
			// SecureField's own UIKit-bridged implementation, not app layout.
			SecureField("Venue password", text: Binding(get: { model.password }, set: model.updatePassword))
				.textContentType(.password)
				.focused($focusedField, equals: .password)
				.submitLabel(.go)
				.onSubmit(signIn)
				.font(Theme.TextStyle.body.font)
				.padding(Spacing.medium)
				.frame(minHeight: 64)
				.background(Theme.ColorRole.cellSurface.color, in: .rect(cornerRadius: 12))
		}
	}

	private var signInButton: some View {
		Button(action: signIn) {
			Group {
				if model.isSigningIn {
					Text("SIGNING IN...")
				} else {
					Text("SIGN IN")
				}
			}
			.frame(maxWidth: .infinity, minHeight: 64)
		}
		.buttonStyle(.primary)
		.disabled(!model.canSignIn)
	}

	private func errorText(_ message: String) -> some View {
		Text(message)
			.font(Theme.TextStyle.body.font)
			.foregroundStyle(Theme.ColorRole.danger.color)
			.multilineTextAlignment(.center)
			.accessibilityAddTraits(.updatesFrequently)
	}

	private func signIn() {
		focusedField = nil
		Task {
			await model.signIn()
		}
	}
}

#Preview("Fresh") {
	KioskSignInView(model: KioskSignInModel(
		signInService: InMemoryKioskSignInService(),
		sessionStore: PreviewKioskSessionStore.signedOut(),
	))
}

#Preview("Sign-in error") {
	let model = KioskSignInModel(
		signInService: InMemoryKioskSignInService(signInResult: .failure(.notAVenueAccount)),
		sessionStore: PreviewKioskSessionStore.signedOut(),
	)
	model.updateScreenName("TheDuke")
	model.updatePassword("wrongpass")
	return KioskSignInView(model: model)
}

#Preview("Landscape iPad") {
	KioskSignInView(model: KioskSignInModel(
		signInService: InMemoryKioskSignInService(),
		sessionStore: PreviewKioskSessionStore.signedOut(),
	))
}

#Preview("Accessibility text size") {
	KioskSignInView(model: KioskSignInModel(
		signInService: InMemoryKioskSignInService(),
		sessionStore: PreviewKioskSessionStore.signedOut(),
	))
	.environment(\.dynamicTypeSize, .accessibility5)
}
