import FeedUI
import Foundation
import Observability
import SecretDJDomain
import SwiftUI
import Testing

@testable import SecretDJ

/// ``SocialAppOutcomeHandling`` — the shared handling every outcome-forwarding
/// screen gives ``FeedUI/FeedActionOutcome/openSocialApp(platform:identifier:webFallbackURL:)``
/// (S8.5 cross-check: previously only ``VenueScreen`` handled it, so it was a
/// no-op on the other four consumer feed screens). Deep-link-else-browser
/// rule ported from `secretdjv3/FeedActionProvider.swift:319-324`.
@MainActor
enum SocialAppOutcomeHandlingTests {
	struct `Handling an openSocialApp outcome for a platform with a native scheme` {
		@Test func `opens the native deep link and reports it handled`() throws {
			let webFallbackURL = try #require(URL(string: "https://instagram.com/secretdj"))
			var openedURLs: [URL] = []
			let openURL = OpenURLAction { requested in
				openedURLs.append(requested)
				return .handled
			}

			let handled = SocialAppOutcomeHandling.handle(
				.openSocialApp(platform: .instagram, identifier: "secretdj", webFallbackURL: webFallbackURL),
				openURL: openURL,
				observability: .disabled,
			)

			#expect(handled)
			#expect(try openedURLs == [#require(URL(string: "instagram://user?username=secretdj"))])
		}

		@Test func `falls back to the web url when the native app doesn't accept the deep link`() throws {
			let nativeURL = try #require(URL(string: "instagram://user?username=secretdj"))
			let webFallbackURL = try #require(URL(string: "https://instagram.com/secretdj"))
			var openedURLs: [URL] = []
			let openURL = OpenURLAction { requested in
				openedURLs.append(requested)
				return requested == nativeURL ? .discarded : .handled
			}

			let handled = SocialAppOutcomeHandling.handle(
				.openSocialApp(platform: .instagram, identifier: "secretdj", webFallbackURL: webFallbackURL),
				openURL: openURL,
				observability: .disabled,
			)

			#expect(handled)
			#expect(openedURLs == [nativeURL, webFallbackURL])
		}

		@Test func `breadcrumbs the interaction`() throws {
			let webFallbackURL = try #require(URL(string: "https://twitter.com/secretdj"))
			let recorder = RecordingDestination()
			let openURL = OpenURLAction { _ in .handled }

			SocialAppOutcomeHandling.handle(
				.openSocialApp(platform: .twitter, identifier: "secretdj", webFallbackURL: webFallbackURL),
				openURL: openURL,
				observability: ObservabilityPipeline(destinations: [recorder]),
			)

			#expect(recorder.breadcrumbs.contains(.interaction(description: "openSocialApp")))
		}
	}

	struct `Handling an openSocialApp outcome for a platform with no native scheme` {
		@Test func `opens the web fallback url directly and reports it handled`() throws {
			let webFallbackURL = try #require(URL(string: "https://facebook.com/secretdj"))
			var openedURL: URL?
			let openURL = OpenURLAction { requested in
				openedURL = requested
				return .handled
			}

			let handled = SocialAppOutcomeHandling.handle(
				.openSocialApp(platform: .facebook, identifier: "secretdj", webFallbackURL: webFallbackURL),
				openURL: openURL,
				observability: .disabled,
			)

			#expect(handled)
			#expect(openedURL == webFallbackURL)
		}
	}

	struct `Handling any other outcome` {
		@Test func `does nothing and reports it unhandled`() {
			var wasOpened = false
			let openURL = OpenURLAction { _ in
				wasOpened = true
				return .handled
			}

			let handled = SocialAppOutcomeHandling.handle(
				.showVenue(venueId: "v1"),
				openURL: openURL,
				observability: .disabled,
			)

			#expect(!handled)
			#expect(!wasOpened)
		}
	}
}
