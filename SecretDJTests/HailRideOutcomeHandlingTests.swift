import FeedUI
import Foundation
import Observability
import SwiftUI
import Testing

@testable import SecretDJ

/// ``HailRideOutcomeHandling`` — the shared first move every outcome-forwarding
/// screen makes before handing off to ``TabRouter`` (S6.10: wiring
/// ``FeedUI/FeedActionOutcome/hailRide(url:)``, previously a no-op
/// everywhere — `AppDestinationTests`'s "hailRide produces no destination"
/// coverage still holds, since this interception happens before the outcome
/// ever reaches `TabRouter`/`AppDestination`).
@MainActor
enum HailRideOutcomeHandlingTests {
	struct `Handling a hail-ride outcome` {
		@Test func `opens the url and reports it handled`() throws {
			let url = try #require(URL(string: "https://m.uber.com/ul/?action=setPickup"))
			var openedURL: URL?
			let openURL = OpenURLAction { requested in
				openedURL = requested
				return .handled
			}

			let handled = HailRideOutcomeHandling.handle(
				.hailRide(url: url),
				openURL: openURL,
				observability: .disabled,
			)

			#expect(handled)
			#expect(openedURL == url)
		}

		@Test func `breadcrumbs the interaction`() throws {
			let url = try #require(URL(string: "https://m.uber.com"))
			let recorder = RecordingDestination()
			let openURL = OpenURLAction { _ in .handled }

			HailRideOutcomeHandling.handle(
				.hailRide(url: url),
				openURL: openURL,
				observability: ObservabilityPipeline(destinations: [recorder]),
			)

			#expect(recorder.breadcrumbs.contains(.interaction(description: "hailRide")))
		}
	}

	struct `Handling any other outcome` {
		@Test func `does nothing and reports it unhandled`() {
			var wasOpened = false
			let openURL = OpenURLAction { _ in
				wasOpened = true
				return .handled
			}

			let handled = HailRideOutcomeHandling.handle(
				.showVenue(venueId: "v1"),
				openURL: openURL,
				observability: .disabled,
			)

			#expect(!handled)
			#expect(!wasOpened)
		}
	}
}
