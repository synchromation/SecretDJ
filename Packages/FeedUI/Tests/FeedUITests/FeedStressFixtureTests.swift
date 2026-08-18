import Testing

@testable import FeedUI

enum FeedStressFixtureTests {
	struct Shape {
		@Test func `builds sixty sections, twenty of each kind`() {
			let sections = FeedStressFixture.makeSections()

			#expect(sections.count == 60)
			#expect(sections.count(where: { $0.kind == .list }) == 20)
			#expect(sections.count(where: { $0.kind == .carousel }) == 20)
			#expect(sections.count(where: { $0.kind == .grid }) == 20)
		}

		@Test func `list sections carry thirty items, carousels twenty, grids forty`() {
			let sections = FeedStressFixture.makeSections()

			#expect(sections.filter { $0.kind == .list }.allSatisfy { $0.items.count == 30 })
			#expect(sections.filter { $0.kind == .carousel }.allSatisfy { $0.items.count == 20 })
			#expect(sections.filter { $0.kind == .grid }.allSatisfy { $0.items.count == 40 })
		}

		@Test func `every section and item id is unique, never derived from array position alone`() {
			let sections = FeedStressFixture.makeSections()

			let sectionIDs = sections.map(\.id)
			#expect(Set(sectionIDs).count == sectionIDs.count)

			let itemIDs = sections.flatMap(\.items).map(\.id)
			#expect(Set(itemIDs).count == itemIDs.count)
		}
	}

	struct Determinism {
		@Test func `building the fixture twice from scratch produces identical sections`() {
			#expect(FeedStressFixture.makeSections() == FeedStressFixture.makeSections())
		}

		@Test func `the cached sections property matches a fresh build`() {
			#expect(FeedStressFixture.sections == FeedStressFixture.makeSections())
		}
	}
}
