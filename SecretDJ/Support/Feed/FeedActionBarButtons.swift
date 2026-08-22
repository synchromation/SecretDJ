import DesignSystem
import FeedUI
import SecretDJDomain
import SwiftUI

/// Renders the nav-bar buttons a loaded feed's ``FeedUI/FeedScreenModel/actionButtons``
/// carries (S6.12) — the SwiftUI replacement for legacy's
/// `ActionBarButtonProvider`/`ActionBarButtonItem` (LEGACY.md "Top-bar
/// action buttons ... are likewise server-driven: insert-coin, hail-Uber,
/// search icons").
///
/// Every S6 feed screen wires this the same way: pass
/// ``FeedUI/FeedScreenModel/actionButtons`` and a closure that resolves the
/// tap through ``FeedUI/FeedScreenModel/outcome(forBarButton:)`` into the
/// screen's own *existing* `handle(outcome:)` — the same path every cell tap
/// already takes, so hail-taxi's breadcrumb (``HailRideOutcomeHandling``)
/// and every other outcome-specific side effect apply here unchanged, with
/// no new instrumentation needed.
///
/// No UIKit-style reversal of the server's order is needed —
/// ``FeedUI/FeedDisplayModel/actionButtons``'s own doc comment covers why:
/// `rightBarButtonItems` lays its array out right-to-left (so
/// `ActionBarButtonProvider` reversed it), while `ToolbarItemGroup` already
/// lays its items out left-to-right in declaration order.
struct FeedActionBarButtons: ToolbarContent {
	let actions: [Action]
	let onTap: (Action) -> Void

	var body: some ToolbarContent {
		ToolbarItemGroup(placement: .topBarTrailing) {
			ForEach(actions, id: \.self) { action in
				if let icon = Self.icon(for: action.button), let title = Self.title(for: action.button) {
					Button {
						onTap(action)
					} label: {
						Label { Text(title) } icon: { icon.image }
					}
					.labelStyle(.iconOnly)
				}
			}
		}
	}

	/// Icon mapping mirrors `ActionBarButtonItem.customButton(_:)`'s switch.
	/// `nil` for a button ``FeedUI/FeedDisplayModel/actionButtons`` should
	/// already have filtered out before this component ever sees it —
	/// defensive, not a path the app hits in practice.
	static func icon(for button: ActionButton) -> Theme.Icon? {
		switch button {
		case .insertCoin: .topUp
		case .hailTaxi: .taxi
		case .launchSearch: .search
		case .unsupported: nil
		}
	}

	/// Localized, accessible label for each button — read by VoiceOver even
	/// though the button itself renders icon-only (`.labelStyle(.iconOnly)`),
	/// mirroring ``ProfileScreen``'s gear button and ``PlacesNearbyScreen``'s
	/// map button.
	static func title(for button: ActionButton) -> LocalizedStringResource? {
		switch button {
		case .insertCoin:
			LocalizedStringResource(
				"Top Up",
				comment: "Label of the insert-coin nav-bar action button, and the credits top-up screen's coming-soon placeholder title.",
			)

		case .hailTaxi:
			LocalizedStringResource(
				"Get a Taxi",
				comment: "Label of the hail-taxi nav-bar action button, offered when the server detects a ride-hailing app installed.",
			)

		case .launchSearch:
			LocalizedStringResource(
				"Search",
				comment: "Label of the search nav-bar action button, and the music search screen's coming-soon placeholder title.",
			)

		case .unsupported:
			nil
		}
	}
}
