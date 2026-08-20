import FeedUI
import Observability
import SwiftUI

/// Every screen that forwards a ``FeedUI/FeedActionOutcome`` to
/// ``TabRouter`` calls this first, ahead of the router — intercepting
/// ``FeedUI/FeedActionOutcome/hailRide(url:)`` and opening its
/// server-supplied URL externally rather than routing it.
/// ``TabRouter/handle(outcome:)``'s own doc comment leaves exactly this kind
/// of external hand-off to the caller, alongside ``OpenURLOutcomeHandling``/
/// ``SocialAppOutcomeHandling`` (S8.5 cross-check) — every S6 feed screen
/// tries all three before falling back to the router. LEGACY.md "Gaps and
/// cross-checks": the server only ever sends this action once the client's
/// `appmask` reports Uber installed, so no local installed-app check
/// happens here — the URL is simply opened.
enum HailRideOutcomeHandling {
	/// Opens `outcome`'s URL and returns `true` when it's a hail-ride
	/// hand-off; otherwise does nothing and returns `false`, leaving the
	/// caller to route `outcome` normally.
	@MainActor
	@discardableResult
	static func handle(
		_ outcome: FeedActionOutcome,
		openURL: OpenURLAction,
		observability: ObservabilityPipeline,
	) -> Bool {
		guard case .hailRide(let url) = outcome else { return false }

		observability.interaction("hailRide")
		openURL(url)
		return true
	}
}
