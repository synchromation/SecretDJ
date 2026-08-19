import Foundation
import SecretDJDomain

/// Builds the native app URL for a routed
/// ``FeedUI/FeedActionOutcome/openSocialApp(platform:identifier:webFallbackURL:)`` —
/// ``FeedUI/FeedActionRouter`` only decides *which* platform a promotion
/// targets and whether its app is installed; constructing the actual scheme
/// URL is this app's own side effect (its doc comment: "S6 hangs its own
/// handling... directly off the outcome"). Ported from
/// `secretdjv3/FeedActionProvider.swift:319-324`, which only ever builds
/// Instagram/Twitter links — matching ``FeedUI/FeedActionRouter``'s own
/// `outcome(forPromotion:)`, which never emits `.openSocialApp` for
/// Facebook or a plain website.
enum SocialAppDeepLink {
	static func url(platform: SocialPlatform, identifier: String) -> URL? {
		switch platform {
		case .instagram:
			URL(string: "instagram://user?username=\(identifier)")

		case .twitter:
			URL(string: "twitter://user?screen_name=\(identifier)")

		case .facebook,
		     .website:
			nil
		}
	}
}
