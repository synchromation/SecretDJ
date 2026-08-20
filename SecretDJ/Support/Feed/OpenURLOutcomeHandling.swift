import FeedUI
import Observability
import SwiftUI

/// Every screen that forwards a ``FeedUI/FeedActionOutcome`` to
/// ``TabRouter`` calls this right after ``HailRideOutcomeHandling`` —
/// intercepting ``FeedUI/FeedActionOutcome/openURL(_:)`` before it reaches
/// ``AppDestination/init(outcome:)`` (which returns `nil` for it) and
/// ``TabRouter``, which would otherwise silently drop it (S8.5 cross-check:
/// previously only ``VenueScreen`` handled this outcome). `.external` opens
/// through the `openURL` environment action; `.inApp` hands the URL to
/// `presentInApp` instead — a static helper can't own the `@State` a sheet's
/// presented URL needs, so the caller supplies that as a closure and keeps
/// the state itself, presenting ``LegalWebScreen``'s in-app browser exactly
/// as `SettingsScreen`'s legal links already do.
enum OpenURLOutcomeHandling {
	/// Handles `outcome` and returns `true` when it's an `openURL` hand-off;
	/// otherwise does nothing and returns `false`, leaving the caller to
	/// route `outcome` normally.
	@MainActor
	@discardableResult
	static func handle(
		_ outcome: FeedActionOutcome,
		openURL: OpenURLAction,
		presentInApp: (URL) -> Void,
		observability: ObservabilityPipeline,
	) -> Bool {
		switch outcome {
		case .openURL(.external(let url)):
			observability.interaction("openPromotionURL")
			openURL(url)
			return true

		case .openURL(.inApp(let url)):
			observability.interaction("openPromotionURL")
			presentInApp(url)
			return true

		default:
			return false
		}
	}
}

/// Wraps a URL so it can drive `.sheet(item:)` — `Foundation.URL` has no
/// `Identifiable` conformance of its own. Every screen presenting
/// ``OpenURLOutcomeHandling``'s in-app browser stores one of these as the
/// `presentInApp` closure's target.
struct InAppBrowserURL: Identifiable {
	let url: URL
	var id: URL {
		url
	}
}
