import FeedUI
import SecretDJDomain
import UIKit

/// The production ``InstalledApps``: probes a companion app's URL scheme via
/// `canOpenURL` (`secretdjv3/URLSchemeHandler.swift`'s `isSchemeRegistered`).
/// Every scheme queried here must also be declared in `Info.plist`'s
/// `LSApplicationQueriesSchemes` or `canOpenURL` always reports `false`
/// regardless of whether the app is actually installed — everything worth
/// testing (the router's use of the answer) lives in FeedUI's
/// `FeedActionRouter` instead, over a fake, so this thin bridge has no tests
/// of its own (mirrors ``CLLocationManagerLocationProviding``'s doc comment).
struct URLSchemeInstalledApps: InstalledApps {
	/// `InstalledApps.isInstalled(_:)` is a plain nonisolated requirement
	/// (FeedUI sets no default actor isolation), but every real caller in
	/// this app — `FeedActionRouter`, reached from `FeedScreenModel`'s own
	/// `@MainActor` tap handling — is already on the main actor by the time
	/// it gets here, matching `UIApplication.shared`'s own isolation
	/// (mirrors ``CLLocationManagerLocationProviding``'s `MainActor
	/// .assumeIsolated` use for the same kind of known-actually-isolated
	/// call).
	func isInstalled(_ platform: SocialPlatform) -> Bool {
		guard let url = URL(string: scheme(for: platform)) else { return false }

		return MainActor.assumeIsolated {
			UIApplication.shared.canOpenURL(url)
		}
	}

	private func scheme(for platform: SocialPlatform) -> String {
		switch platform {
		case .facebook: "fb://"
		case .twitter: "twitter://"
		case .instagram: "instagram://"
		// No installed-app affordance for a plain website — always
		// unreachable via `canOpenURL`.
		case .website: ""
		}
	}
}
