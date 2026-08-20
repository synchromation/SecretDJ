import FeedUI
import Foundation
import Observability
import SwiftUI
import Testing

@testable import SecretDJ

/// ``OpenURLOutcomeHandling`` — the shared second move every outcome-forwarding
/// screen makes, right after ``HailRideOutcomeHandling`` (S8.5 cross-check:
/// ``FeedUI/FeedActionOutcome/openURL(_:)`` was previously a no-op on four of
/// five consumer feed screens, since neither ``AppDestination/init(outcome:)``
/// nor ``TabRouter`` resolves it).
@MainActor
enum OpenURLOutcomeHandlingTests {
	struct `Handling an external openURL outcome` {
		@Test func `opens the url and reports it handled`() throws {
			let url = try #require(URL(string: "https://secretdj.com/promo"))
			var openedURL: URL?
			let openURL = OpenURLAction { requested in
				openedURL = requested
				return .handled
			}

			let handled = OpenURLOutcomeHandling.handle(
				.openURL(.external(url)),
				openURL: openURL,
				presentInApp: { _ in Issue.record("presentInApp should not be called for an external URL") },
				observability: .disabled,
			)

			#expect(handled)
			#expect(openedURL == url)
		}

		@Test func `breadcrumbs the interaction`() throws {
			let url = try #require(URL(string: "https://secretdj.com/promo"))
			let recorder = RecordingDestination()
			let openURL = OpenURLAction { _ in .handled }

			OpenURLOutcomeHandling.handle(
				.openURL(.external(url)),
				openURL: openURL,
				presentInApp: { _ in },
				observability: ObservabilityPipeline(destinations: [recorder]),
			)

			#expect(recorder.breadcrumbs.contains(.interaction(description: "openPromotionURL")))
		}
	}

	struct `Handling an in-app openURL outcome` {
		@Test func `presents the url in-app and reports it handled, without opening it externally`() throws {
			let url = try #require(URL(string: "https://secretdj.com/promo"))
			var presentedURL: URL?
			let openURL = OpenURLAction { _ in
				Issue.record("openURL should not be called for an in-app URL")
				return .handled
			}

			let handled = OpenURLOutcomeHandling.handle(
				.openURL(.inApp(url)),
				openURL: openURL,
				presentInApp: { presentedURL = $0 },
				observability: .disabled,
			)

			#expect(handled)
			#expect(presentedURL == url)
		}

		@Test func `breadcrumbs the interaction`() throws {
			let url = try #require(URL(string: "https://secretdj.com/promo"))
			let recorder = RecordingDestination()
			let openURL = OpenURLAction { _ in .handled }

			OpenURLOutcomeHandling.handle(
				.openURL(.inApp(url)),
				openURL: openURL,
				presentInApp: { _ in },
				observability: ObservabilityPipeline(destinations: [recorder]),
			)

			#expect(recorder.breadcrumbs.contains(.interaction(description: "openPromotionURL")))
		}
	}

	struct `Handling any other outcome` {
		@Test func `does nothing and reports it unhandled`() {
			var wasOpened = false
			var wasPresented = false
			let openURL = OpenURLAction { _ in
				wasOpened = true
				return .handled
			}

			let handled = OpenURLOutcomeHandling.handle(
				.showVenue(venueId: "v1"),
				openURL: openURL,
				presentInApp: { _ in wasPresented = true },
				observability: .disabled,
			)

			#expect(!handled)
			#expect(!wasOpened)
			#expect(!wasPresented)
		}
	}
}
