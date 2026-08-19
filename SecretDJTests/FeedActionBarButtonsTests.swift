import DesignSystem
import SecretDJDomain
import Testing

@testable import SecretDJ

/// ``FeedActionBarButtons``'s icon/title mapping (S6.12) — the SwiftUI
/// replacement for legacy's `ActionBarButtonItem.customButton(_:)` switch.
/// `FeedUI/FeedDisplayModel/actionButtons` already filters out any
/// unrecognized button before this component ever sees it, so `.unsupported`
/// coverage here is defensive, not exercising a path the app hits in
/// practice.
enum FeedActionBarButtonsTests {
	struct `Icon mapping` {
		@Test func `insertCoin maps to the topUp icon`() {
			#expect(FeedActionBarButtons.icon(for: .insertCoin) == .topUp)
		}

		@Test func `hailTaxi maps to the taxi icon`() {
			#expect(FeedActionBarButtons.icon(for: .hailTaxi) == .taxi)
		}

		@Test func `launchSearch maps to the search icon`() {
			#expect(FeedActionBarButtons.icon(for: .launchSearch) == .search)
		}

		@Test func `an unsupported button maps to no icon`() {
			#expect(FeedActionBarButtons.icon(for: .unsupported(0)) == nil)
		}
	}

	struct `Title mapping` {
		@Test func `every recognized button has a title`() {
			#expect(FeedActionBarButtons.title(for: .insertCoin) != nil)
			#expect(FeedActionBarButtons.title(for: .hailTaxi) != nil)
			#expect(FeedActionBarButtons.title(for: .launchSearch) != nil)
		}

		@Test func `an unsupported button has no title`() {
			#expect(FeedActionBarButtons.title(for: .unsupported(0)) == nil)
		}
	}
}
