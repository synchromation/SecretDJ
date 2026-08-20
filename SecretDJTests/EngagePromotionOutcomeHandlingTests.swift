import FeedUI
import Foundation
import Observability
import Testing

@testable import SecretDJ

/// ``EngagePromotionOutcomeHandling`` — the shared fourth move every
/// outcome-forwarding screen makes, right after ``SocialAppOutcomeHandling``
/// (S8.5 cross-check: ``FeedUI/FeedActionOutcome/engagePromotion(promotionId:)``
/// was previously only handled by ``VenueScreen``'s own inline code, a no-op
/// everywhere else since neither ``AppDestination/init(outcome:)`` nor
/// ``TabRouter`` resolves it). `venueId` is threaded through rather than
/// resolved here — `nil` on a screen with no single venue in view (Places
/// Nearby, Activity, Profile); ``PromotionEngaging`` decides what to do with
/// that (``APIClientPromotionEngagingTests``'s own coverage).
@MainActor
enum EngagePromotionOutcomeHandlingTests {
	struct `Handling an engagePromotion outcome` {
		@Test func `fires the engage call and reports it handled`() async {
			let promotionEngaging = InMemoryPromotionEngaging()

			let handled = EngagePromotionOutcomeHandling.handle(
				.engagePromotion(promotionId: 42),
				venueId: "v1",
				promotionEngaging: promotionEngaging,
				observability: .disabled,
			)
			await Task.yield()

			#expect(handled)
			#expect(promotionEngaging.invocations == [.init(venueId: "v1", promotionId: 42)])
		}

		@Test func `passes a nil venueId through unchanged, for a screen with no single venue in view`() async {
			let promotionEngaging = InMemoryPromotionEngaging()

			EngagePromotionOutcomeHandling.handle(
				.engagePromotion(promotionId: 7),
				venueId: nil,
				promotionEngaging: promotionEngaging,
				observability: .disabled,
			)
			await Task.yield()

			#expect(promotionEngaging.invocations == [.init(venueId: nil, promotionId: 7)])
		}

		@Test func `breadcrumbs the interaction`() async {
			let recorder = RecordingDestination()

			EngagePromotionOutcomeHandling.handle(
				.engagePromotion(promotionId: 42),
				venueId: "v1",
				promotionEngaging: InMemoryPromotionEngaging(),
				observability: ObservabilityPipeline(destinations: [recorder]),
			)
			await Task.yield()

			#expect(recorder.breadcrumbs.contains(.interaction(description: "engagePromotion")))
		}
	}

	struct `Handling any other outcome` {
		@Test func `does nothing and reports it unhandled`() async {
			let promotionEngaging = InMemoryPromotionEngaging()

			let handled = EngagePromotionOutcomeHandling.handle(
				.showVenue(venueId: "v1"),
				venueId: "v1",
				promotionEngaging: promotionEngaging,
				observability: .disabled,
			)
			await Task.yield()

			#expect(!handled)
			#expect(promotionEngaging.invocations.isEmpty)
		}
	}
}
