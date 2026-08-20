import FeedUI
import Observability
import SwiftUI

/// Every screen that forwards a ``FeedUI/FeedActionOutcome`` to
/// ``TabRouter`` calls this alongside ``HailRideOutcomeHandling``/
/// ``OpenURLOutcomeHandling`` — intercepting
/// ``FeedUI/FeedActionOutcome/openSocialApp(platform:identifier:webFallbackURL:)``
/// before it reaches ``AppDestination/init(outcome:)`` (which returns `nil`
/// for it) and ``TabRouter``, which would otherwise silently drop it (S8.5
/// cross-check: previously only ``VenueScreen`` handled this outcome).
/// `secretdjv3/FeedActionProvider.swift:319-324`'s deep-link-else-browser
/// rule: try the native app first (``SocialAppDeepLink``), falling back to
/// the web profile URL either when no native scheme exists for this
/// platform or when opening it didn't succeed.
enum SocialAppOutcomeHandling {
	/// Handles `outcome` and returns `true` when it's an `openSocialApp`
	/// hand-off; otherwise does nothing and returns `false`, leaving the
	/// caller to route `outcome` normally.
	@MainActor
	@discardableResult
	static func handle(
		_ outcome: FeedActionOutcome,
		openURL: OpenURLAction,
		observability: ObservabilityPipeline,
	) -> Bool {
		guard case .openSocialApp(let platform, let identifier, let webFallbackURL) = outcome else { return false }

		observability.interaction("openSocialApp")

		guard let nativeURL = SocialAppDeepLink.url(platform: platform, identifier: identifier) else {
			openURL(webFallbackURL)
			return true
		}

		openURL(nativeURL) { accepted in
			if !accepted {
				openURL(webFallbackURL)
			}
		}
		return true
	}
}
