import DesignSystem
import Testing

@testable import FeedUI

import SecretDJDomain

/// Coverage for mapping a `.person` item's up to four positional tagged
/// lines onto `FeedCellProps.PersonProps.lines` — split out of
/// `FeedCellPropsTests` to keep that file under the project's file-length
/// limit (same rationale as `FeedCellPropsArtworkTests`).
///
/// Legacy carries a person row's up to four labels by fixed array index —
/// `FeedCellConfigurator.populateFields`
/// (`secretdjv3/FeedCellConfigurator.swift:270-275`) binds tag 101→line 0,
/// 102→1, 103→2, 104→3 regardless of how many the server actually sent — so
/// this mapping's only job is carrying every tagged line through unsplit;
/// which lines stack at the top vs. pin to the bottom is `PersonRowCell`'s
/// own (preview-covered) rendering concern, not tested here.
enum FeedCellPropsPersonTests {
	struct `Person props` {
		@Test func `carries all four tagged lines, not just the first two`() {
			let text = "Nick Banks\nRequested Levitating\nat The Fox, Chiswick\n2 hours ago"
			let item = makeItem(.person(makePerson(text: text)), template: .feedItem)

			guard case .person(let props) = item.props else {
				Issue.record("expected .person")
				return
			}

			#expect(props.lines == ["Nick Banks", "Requested Levitating", "at The Fox, Chiswick", "2 hours ago"])
		}

		@Test func `carries fewer lines as-is when the server sends fewer than four`() {
			let item = makeItem(.person(makePerson(text: "Nick Banks\n12 places visited")), template: .person)

			guard case .person(let props) = item.props else {
				Issue.record("expected .person")
				return
			}

			#expect(props.lines == ["Nick Banks", "12 places visited"])
		}

		@Test func `carries a single tagged line as-is`() {
			let item = makeItem(.person(makePerson(text: "Nick Banks")), template: .person)

			guard case .person(let props) = item.props else {
				Issue.record("expected .person")
				return
			}

			#expect(props.lines == ["Nick Banks"])
		}

		@Test func `falls back to the person's screen name when the item has no tagged lines`() {
			let item = makeItem(.person(makePerson(text: "", screenName: "TurboTim")), template: .person)

			guard case .person(let props) = item.props else {
				Issue.record("expected .person")
				return
			}

			#expect(props.lines == ["TurboTim"])
		}

		@Test func `drops a fifth tagged line, matching legacy's four-label cap`() {
			let text = "Line one\nLine two\nLine three\nLine four\nLine five"
			let item = makeItem(.person(makePerson(text: text)), template: .feedItem)

			guard case .person(let props) = item.props else {
				Issue.record("expected .person")
				return
			}

			#expect(props.lines == ["Line one", "Line two", "Line three", "Line four"])
		}

		@Test func `carries the server like summary as the accessory`() {
			let person = makePerson(
				text: "Nick Banks",
				likeInfo: LikeInfo(likedByYou: false, info: ""),
			)
			let item = makeItem(.person(person), template: .person)

			guard case .person(let props) = item.props else {
				Issue.record("expected .person")
				return
			}

			#expect(props.accessory == .like(isLiked: false, summary: nil))
		}
	}
}

// MARK: - Fixtures

private func makeItem(_ item: Item, template: Template) -> FeedDisplayItem {
	FeedDisplayItem(id: item.stableID, item: item, text: item.displayText ?? "", template: template)
}

private func makePerson(
	text: String,
	screenName: String = "",
	likeInfo: LikeInfo = LikeInfo(likedByYou: false, info: ""),
) -> Person {
	Person(
		personId: "p1",
		screenName: screenName,
		gender: .unisex,
		likeInfo: likeInfo,
		email: nil,
		firstName: nil,
		lastName: nil,
		text: text,
		sortIndex: 0,
		action: nil,
		actions: [],
	)
}
