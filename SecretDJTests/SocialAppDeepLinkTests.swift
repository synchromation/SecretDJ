import FeedUI
import Foundation
import SecretDJDomain
import Testing

@testable import SecretDJ

/// ``SocialAppDeepLink`` — converts a routed
/// ``FeedActionOutcome/openSocialApp(platform:identifier:webFallbackURL:)``
/// into the native app URL legacy constructed at the point of use
/// (`secretdjv3/FeedActionProvider.swift:319-324`: `instagram://user?username=…`
/// / `twitter://user?screen_name=…`) — kept out of ``FeedUI/FeedActionRouter``
/// since that router only decides *which* platform to target, not this app's
/// URL-scheme contract (its own doc comment on `openSocialApp`).
struct SocialAppDeepLinkTests {
	@Test func `builds an Instagram profile deep link from the identifier`() throws {
		let url = try #require(SocialAppDeepLink.url(platform: .instagram, identifier: "secretdj"))

		#expect(url.absoluteString == "instagram://user?username=secretdj")
	}

	@Test func `builds a Twitter profile deep link from the identifier`() throws {
		let url = try #require(SocialAppDeepLink.url(platform: .twitter, identifier: "secretdj"))

		#expect(url.absoluteString == "twitter://user?screen_name=secretdj")
	}

	@Test func `has no native deep link for Facebook`() {
		#expect(SocialAppDeepLink.url(platform: .facebook, identifier: "secretdj") == nil)
	}

	@Test func `has no native deep link for a plain website`() {
		#expect(SocialAppDeepLink.url(platform: .website, identifier: "secretdj") == nil)
	}
}
