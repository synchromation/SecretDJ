import Foundation
import Testing

@testable import SecretDJDomain

struct SectionTests {
	@Test func `stores every field it is constructed with`() {
		let section = Section(
			itemType: .song,
			template: .song,
			title: "Now Playing",
			index: 0,
			store: nil,
			hash: FeedHash(rawValue: "abc"),
			items: [],
		)

		#expect(section.itemType == .song)
		#expect(section.template == .song)
		#expect(section.title == "Now Playing")
		#expect(section.index == 0)
		#expect(section.hash == FeedHash(rawValue: "abc"))
		#expect(section.items.isEmpty)
	}

	@Test func `two sections with identical fields are equal`() {
		let makeSection = {
			Section(itemType: .venue, template: .venue, title: "", index: 0, store: nil, hash: nil, items: [])
		}

		#expect(makeSection() == makeSection())
	}

	struct AffiliateStoreTests {
		@Test func `decodes the iTunes affiliate override fields`() throws {
			let json = Data(
				"""
				{"SearchUrl": "https://itunes.apple.com/search", "PageUrlPrefix": "https://click.example/",
				 "PageUrlSuffix": "?ref=sdj"}
				""".utf8,
			)

			let store = try JSONDecoder().decode(AffiliateStore.self, from: json)

			#expect(store.searchURL == "https://itunes.apple.com/search")
			#expect(store.pageURLPrefix == "https://click.example/")
			#expect(store.pageURLSuffix == "?ref=sdj")
		}

		@Test func `missing fields decode to nil rather than failing`() throws {
			let json = Data("{}".utf8)

			let store = try JSONDecoder().decode(AffiliateStore.self, from: json)

			#expect(store.searchURL == nil)
			#expect(store.pageURLPrefix == nil)
			#expect(store.pageURLSuffix == nil)
		}
	}
}
