import SafariServices
import SwiftUI

/// An in-app browser for the About/Legal section's external links (S6.11) —
/// `SFSafariViewController` wrapped for SwiftUI, presented as a sheet.
/// Neither the legacy app nor its SwiftUI Settings pilot has a web-view
/// screen to port from for these particular rows (LEGACY.md's legacy web
/// views are elsewhere, unrelated to Settings); `SFSafariViewController`
/// supplies its own "Done" button, so no extra chrome is added here.
struct LegalWebScreen: UIViewControllerRepresentable {
	let url: URL

	func makeUIViewController(context: Context) -> SFSafariViewController {
		SFSafariViewController(url: url)
	}

	func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
