import Testing

@testable import FeedUI

import SecretDJDomain

/// ``FeedDisplayModel/actionButtons`` — the nav-bar buttons a section
/// list's top-level `actions` carry (S6.12), split from
/// ``FeedDisplayModelTests`` per that file's own split precedent
/// (``FeedDisplayModel+HiddenSections.swift``'s tests live in
/// ``FeedDisplayModelTests``'s "Hidden sections" group; this is the
/// analogous "Action buttons" group, kept in its own file to stay under
/// the project's file-length guidance).
enum FeedDisplayModelActionButtonsTests {
	struct `Action buttons` {
		@Test func `keeps a recognized action in the server's own order`() {
			let insertCoin = makeAction(kind: .showTopup, button: .insertCoin)
			let hailTaxi = makeAction(kind: .launchUberApp, url: "https://m.uber.com", button: .hailTaxi)
			let search = makeAction(kind: .launchSearch, button: .launchSearch)
			let sectionList = SectionList(
				hash: FeedHash(rawValue: "h1"),
				sections: [],
				actions: [insertCoin, hailTaxi, search],
			)

			let model = FeedDisplayModel(sectionList: sectionList)

			#expect(model.actionButtons == [insertCoin, hailTaxi, search])
		}

		@Test func `drops an action whose button icon this build doesn't recognize`() {
			// The legacy "no button" sentinel (raw 0) and any other unmapped
			// code both become `.unsupported` — `ActionBarButtonItem.customButton(_:)`'s
			// gate never rendered these.
			let unbuttoned = makeAction(kind: .showTopup, button: .unsupported(0))
			let sectionList = SectionList(hash: FeedHash(rawValue: "h1"), sections: [], actions: [unbuttoned])

			let model = FeedDisplayModel(sectionList: sectionList)

			#expect(model.actionButtons.isEmpty)
		}

		@Test func `drops an action whose underlying action kind this build doesn't recognize`() {
			// `ActionBarButtonItem.init?`'s other half of the same guard:
			// `appAction.actionType != .unknown`, even when the button icon
			// itself is recognized.
			let unknownKind = makeAction(kind: .unsupported(999), button: .insertCoin)
			let sectionList = SectionList(hash: FeedHash(rawValue: "h1"), sections: [], actions: [unknownKind])

			let model = FeedDisplayModel(sectionList: sectionList)

			#expect(model.actionButtons.isEmpty)
		}

		@Test func `is empty for a section list with no actions`() {
			let sectionList = SectionList(hash: FeedHash(rawValue: "h1"), sections: [], actions: [])

			let model = FeedDisplayModel(sectionList: sectionList)

			#expect(model.actionButtons.isEmpty)
		}
	}
}
