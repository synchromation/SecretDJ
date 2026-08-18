import Testing

@testable import FeedUI

import SecretDJDomain

enum FeedSectionKindTests {
	struct `Mapping known templates` {
		@Test(
			arguments: [
				Template.venue, .award, .checkIn, .song, .feedItem, .vip, .person, .promotion, .advert,
				.jukeboxList, .topUp, .artist,
			],
		)
		func `plain templates map to list`(template: Template) {
			#expect(FeedSectionKind(template: template) == .list)
		}

		@Test(arguments: [Template.horizontalAward, .horizontalSong, .horizontalVIP, .horizontalPerson, .container])
		func `horizontal templates and the legacy container map to carousel`(template: Template) {
			#expect(FeedSectionKind(template: template) == .carousel)
		}

		@Test(
			arguments: [
				Template.matrixAwardSmall, .matrixAwardMedium, .matrixSongSmall, .matrixSongMedium,
				.matrixPersonSmall, .matrixPersonMedium, .matrixPromotionMedium, .matrixJukeboxLarge,
				.matrixControlLarge,
			],
		)
		func `matrix templates map to grid`(template: Template) {
			#expect(FeedSectionKind(template: template) == .grid)
		}

		@Test(
			arguments: [
				Template.hiddenVenueDetails, .hiddenUserDetails, .hiddenProfile, .hiddenJukeboxList,
				.hiddenExtraContentSong,
			],
		)
		func `hidden templates map to hidden`(template: Template) {
			#expect(FeedSectionKind(template: template) == .hidden)
		}
	}

	struct `Dropping unknown templates` {
		@Test func `a template this build doesn't recognize maps to nil`() {
			let template = Template(rawValue: 424_242)

			#expect(FeedSectionKind(template: template) == nil)
		}
	}
}
