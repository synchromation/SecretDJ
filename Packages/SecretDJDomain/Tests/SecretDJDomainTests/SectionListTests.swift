import Testing

@testable import SecretDJDomain

struct SectionListTests {
	@Test func `stores its hash, sections, and actions`() {
		let section = Section(itemType: .venue, template: .venue, title: "", index: 0, store: nil, hash: nil, items: [])
		let action = Action(kind: .showTopup, itemId: nil, itemTypeId: nil, value: nil, url: nil, button: .insertCoin)

		let sectionList = SectionList(hash: FeedHash(rawValue: "xyz"), sections: [section], actions: [action])

		#expect(sectionList.hash == FeedHash(rawValue: "xyz"))
		#expect(sectionList.sections == [section])
		#expect(sectionList.actions == [action])
	}

	@Test func `two section lists with identical fields are equal`() {
		let makeList = { SectionList(hash: FeedHash(rawValue: "same"), sections: [], actions: []) }

		#expect(makeList() == makeList())
	}
}
