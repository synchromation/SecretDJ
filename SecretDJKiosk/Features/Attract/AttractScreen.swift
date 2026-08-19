import DesignSystem
import Observability
import SwiftUI
import WebKit

/// The kiosk's screensaver — a full-screen, server-hosted web page at the
/// venue skin's attract URL. Ports `secretdjv3/AttractViewController.swift`
/// exactly: "simply a full-screen `WKWebView` loading the skin's
/// `attractURL`, with an invisible full-screen button that dismisses it on
/// any tap" (LEGACY.md "Attract loop and timers") — the whole screen is one
/// ``Button`` over the (non-interactive) web content, so a raw tap anywhere
/// dismisses exactly like legacy, and VoiceOver gets the same affordance as
/// a real, labelled control instead of relying on an unlabelled touch
/// (accessibility skill: "every interactive control gets its meaning from a
/// real, localized title"). The visible "Tap to Continue" hint that rides
/// along with it is new — legacy's invisible button had nothing sighted
/// users could see either, but a self-service terminal shouldn't require
/// blind guessing to get back to it.
struct AttractScreen: View {
	let url: URL
	let onDismiss: () -> Void

	var body: some View {
		Button(action: onDismiss) {
			ZStack(alignment: .bottom) {
				AttractWebView(url: url)
					.accessibilityHidden(true)

				dismissHint
					.padding(.bottom, Spacing.large)
					.accessibilityHidden(true)
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.background(Color.black)
			.ignoresSafeArea()
		}
		.buttonStyle(.plain)
		.accessibilityLabel(dismissLabel)
		.tracksScreen("KioskAttract")
	}

	/// A fixed white-on-black pill rather than `DesignSystem` theme colors:
	/// this sits over an arbitrary venue-supplied web page, not one of this
	/// app's own backgrounds, so it needs contrast that holds regardless of
	/// what that page draws underneath, not a role tuned for this app's own
	/// surfaces.
	private var dismissHint: some View {
		dismissLabel
			.font(Theme.TextStyle.button.font)
			.foregroundStyle(.white)
			.padding(.horizontal, Spacing.medium)
			.padding(.vertical, Spacing.small)
			.background(Color.black.opacity(0.6), in: Capsule())
	}

	private var dismissLabel: Text {
		Text(
			"Tap to Continue",
			comment: "Visible hint and VoiceOver label on the kiosk's full-screen attract-mode screensaver; tapping anywhere dismisses it.",
		)
	}
}

/// Loads ``AttractScreen``'s web content read-only: legacy's own attract
/// view "the web content is inert" — every tap is handled by the
/// surrounding ``Button`` instead, never the web view's own scrolling or
/// link-following, so user interaction is disabled outright rather than
/// merely unused.
private struct AttractWebView: UIViewRepresentable {
	let url: URL

	func makeUIView(context: Context) -> WKWebView {
		let webView = WKWebView()
		webView.isUserInteractionEnabled = false
		webView.load(URLRequest(url: url))
		return webView
	}

	func updateUIView(_ webView: WKWebView, context: Context) {
		guard webView.url != url else { return }
		webView.load(URLRequest(url: url))
	}
}

#Preview("Attract") {
	AttractScreen(url: URL(string: "https://example.com/attract.html")!, onDismiss: {})
}

#Preview("Accessibility text size") {
	AttractScreen(url: URL(string: "https://example.com/attract.html")!, onDismiss: {})
		.environment(\.dynamicTypeSize, .accessibility5)
}
