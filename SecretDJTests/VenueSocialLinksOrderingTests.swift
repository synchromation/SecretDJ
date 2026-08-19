import FeedUI
import SecretDJDomain
import Testing

@testable import SecretDJ

/// ``VenueSocialLinksOrdering`` — the client-side "Instagram first, max
/// three" rule LEGACY.md's business-rule list carries forward
/// (`secretdjv3/VenueFeedViewController.swift`'s `filterSocials`/
/// `prioritiseSocialItems`), ported onto Domain's `SectionList`.
enum VenueSocialLinksOrderingTests {
	struct `Sections untouched` {
		@Test func `a section whose itemType isn't event passes through unchanged`() {
			let section = makeSection(itemType: .venue, items: [.venue(makeVenue(venueId: "v1"))])
			let sectionList = SectionList(hash: FeedHash(rawValue: "h1"), sections: [section], actions: [])

			let result = VenueSocialLinksOrdering.prioritized(sectionList)

			#expect(result.sections == [section])
		}

		@Test func `an event section with no promotions passes through unchanged`() {
			let section = makeSection(itemType: .event, items: [])
			let sectionList = SectionList(hash: FeedHash(rawValue: "h1"), sections: [section], actions: [])

			let result = VenueSocialLinksOrdering.prioritized(sectionList)

			#expect(result.sections == [section])
		}

		@Test func `an event section whose promotions are all empty-url drops every item, not just caps them`() {
			// Legacy always caps an event section to three regardless of
			// validity (`prioritiseSocialItems`'s final "ensure is no greater
			// than max length" step runs unconditionally); this port instead
			// drops invalid (empty-url) promotions outright rather than
			// carrying legacy's "pad with empty socials" behavior forward
			// (`VenueSocialLinksOrdering`'s own doc comment) — either way, a
			// section of nothing-but-invalid promotions must never render
			// more than the cap, so it must not pass through untouched.
			let items = (0 ..< 4).map { makePromotion(socialId: -100 - $0, url: "") }
			let section = makeSection(itemType: .event, items: items)
			let sectionList = SectionList(hash: FeedHash(rawValue: "h1"), sections: [section], actions: [])

			let result = VenueSocialLinksOrdering.prioritized(sectionList)

			#expect(result.sections[0].items.isEmpty)
		}

		@Test func `every other section stays in its original order around the reordered one`() {
			let venueSection = makeSection(itemType: .venue, items: [.venue(makeVenue(venueId: "v1"))])
			let eventSection = makeSection(itemType: .event, items: [
				makePromotion(socialId: SocialPlatform.instagram.rawValue, url: "https://instagram.com/secretdj"),
			])
			let sectionList = SectionList(
				hash: FeedHash(rawValue: "h1"),
				sections: [venueSection, eventSection],
				actions: [],
			)

			let result = VenueSocialLinksOrdering.prioritized(sectionList)

			#expect(result.sections.count == 2)
			#expect(result.sections[0] == venueSection)
		}
	}

	struct `Without Instagram` {
		@Test func `keeps every valid link in its original order`() {
			let facebook = makePromotion(
				socialId: SocialPlatform.facebook.rawValue,
				url: "https://facebook.com/secretdj",
			)
			let website = makePromotion(socialId: SocialPlatform.website.rawValue, url: "https://secretdj.com")
			let section = makeSection(itemType: .event, items: [facebook, website])
			let sectionList = SectionList(hash: FeedHash(rawValue: "h1"), sections: [section], actions: [])

			let result = VenueSocialLinksOrdering.prioritized(sectionList)

			#expect(result.sections[0].items == [facebook, website])
		}

		@Test func `still caps at three when more than three are present`() {
			let items = (0 ..< 4).map { makePromotion(socialId: -100 - $0, url: "https://example.com/\($0)") }
			let section = makeSection(itemType: .event, items: items)
			let sectionList = SectionList(hash: FeedHash(rawValue: "h1"), sections: [section], actions: [])

			let result = VenueSocialLinksOrdering.prioritized(sectionList)

			#expect(result.sections[0].items == Array(items.prefix(3)))
		}

		@Test func `drops a promotion with an empty url`() {
			let facebook = makePromotion(
				socialId: SocialPlatform.facebook.rawValue,
				url: "https://facebook.com/secretdj",
			)
			let emptyURL = makePromotion(socialId: SocialPlatform.website.rawValue, url: "")
			let section = makeSection(itemType: .event, items: [facebook, emptyURL])
			let sectionList = SectionList(hash: FeedHash(rawValue: "h1"), sections: [section], actions: [])

			let result = VenueSocialLinksOrdering.prioritized(sectionList)

			#expect(result.sections[0].items == [facebook])
		}
	}

	struct `With Instagram` {
		@Test func `puts Instagram first regardless of its original position`() {
			let facebook = makePromotion(
				socialId: SocialPlatform.facebook.rawValue,
				url: "https://facebook.com/secretdj",
			)
			let instagram = makePromotion(
				socialId: SocialPlatform.instagram.rawValue,
				url: "https://instagram.com/secretdj",
			)
			let section = makeSection(itemType: .event, items: [facebook, instagram])
			let sectionList = SectionList(hash: FeedHash(rawValue: "h1"), sections: [section], actions: [])

			let result = VenueSocialLinksOrdering.prioritized(sectionList)

			#expect(result.sections[0].items.first == instagram)
		}

		@Test func `orders Twitter and website ahead of Facebook`() {
			let facebook = makePromotion(
				socialId: SocialPlatform.facebook.rawValue,
				url: "https://facebook.com/secretdj",
			)
			let instagram = makePromotion(
				socialId: SocialPlatform.instagram.rawValue,
				url: "https://instagram.com/secretdj",
			)
			let twitter = makePromotion(socialId: SocialPlatform.twitter.rawValue, url: "https://twitter.com/secretdj")
			let website = makePromotion(socialId: SocialPlatform.website.rawValue, url: "https://secretdj.com")
			let section = makeSection(itemType: .event, items: [facebook, website, twitter, instagram])
			let sectionList = SectionList(hash: FeedHash(rawValue: "h1"), sections: [section], actions: [])

			let result = VenueSocialLinksOrdering.prioritized(sectionList)

			#expect(result.sections[0].items == [instagram, twitter, website])
		}

		@Test func `Facebook is dropped once Instagram, Twitter, and website already fill the cap`() {
			let facebook = makePromotion(
				socialId: SocialPlatform.facebook.rawValue,
				url: "https://facebook.com/secretdj",
			)
			let instagram = makePromotion(
				socialId: SocialPlatform.instagram.rawValue,
				url: "https://instagram.com/secretdj",
			)
			let twitter = makePromotion(socialId: SocialPlatform.twitter.rawValue, url: "https://twitter.com/secretdj")
			let website = makePromotion(socialId: SocialPlatform.website.rawValue, url: "https://secretdj.com")
			let section = makeSection(itemType: .event, items: [facebook, website, twitter, instagram])
			let sectionList = SectionList(hash: FeedHash(rawValue: "h1"), sections: [section], actions: [])

			let result = VenueSocialLinksOrdering.prioritized(sectionList)

			#expect(!result.sections[0].items.contains(facebook))
		}

		@Test func `Facebook fills a spare slot when Twitter or website is missing`() {
			let facebook = makePromotion(
				socialId: SocialPlatform.facebook.rawValue,
				url: "https://facebook.com/secretdj",
			)
			let instagram = makePromotion(
				socialId: SocialPlatform.instagram.rawValue,
				url: "https://instagram.com/secretdj",
			)
			let section = makeSection(itemType: .event, items: [facebook, instagram])
			let sectionList = SectionList(hash: FeedHash(rawValue: "h1"), sections: [section], actions: [])

			let result = VenueSocialLinksOrdering.prioritized(sectionList)

			#expect(result.sections[0].items == [instagram, facebook])
		}

		@Test func `an Instagram promotion with an empty url is treated as absent`() {
			let facebook = makePromotion(
				socialId: SocialPlatform.facebook.rawValue,
				url: "https://facebook.com/secretdj",
			)
			let emptyInstagram = makePromotion(socialId: SocialPlatform.instagram.rawValue, url: "")
			let section = makeSection(itemType: .event, items: [facebook, emptyInstagram])
			let sectionList = SectionList(hash: FeedHash(rawValue: "h1"), sections: [section], actions: [])

			let result = VenueSocialLinksOrdering.prioritized(sectionList)

			#expect(result.sections[0].items == [facebook])
		}
	}
}

// MARK: - Fixtures

private func makeSection(itemType: ItemType, items: [Item]) -> Section {
	Section(itemType: itemType, template: .promotion, title: "", index: 0, store: nil, hash: nil, items: items)
}

private func makePromotion(socialId: Int, url: String) -> Item {
	.promotion(Promotion(
		promotionId: socialId,
		url: url.isEmpty ? nil : url,
		externalBrowser: true,
		height: 60,
		text: "",
		sortIndex: 0,
		action: nil,
		actions: [],
	))
}

private func makeVenue(venueId: String) -> Venue {
	Venue(
		venueId: venueId,
		name: "",
		address: "",
		telephone: "",
		lat: 0,
		lng: 0,
		zoneName: "",
		promotionURL: nil,
		likeInfo: LikeInfo(likedByYou: false, info: ""),
		properties: [],
		checkedIn: false,
		hasMachineControl: false,
		text: "",
		sortIndex: 0,
		action: nil,
		actions: [],
	)
}
