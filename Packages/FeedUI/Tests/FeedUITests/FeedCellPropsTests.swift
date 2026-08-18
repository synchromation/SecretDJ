import DesignSystem
import Testing

@testable import FeedUI

import SecretDJDomain

enum FeedCellPropsTests {
	struct `Song props` {
		@Test func `maps title and subtitle from the first two tagged lines`() {
			let item = makeItem(.song(makeSong(text: "Bohemian Rhapsody\nQueen")), template: .song)

			guard case .media(let props) = item.props else {
				Issue.record("expected .media")
				return
			}

			#expect(props.title == "Bohemian Rhapsody")
			#expect(props.subtitle == "Queen")
			#expect(props.placeholderIcon == .song)
			#expect(props.artworkURL == nil)
		}

		@Test func `a liked song carries its server like summary as the accessory`() {
			let song = makeSong(
				text: "Bohemian Rhapsody\nQueen",
				likeInfo: LikeInfo(likedByYou: true, info: "12 people buzzed this"),
			)
			let item = makeItem(.song(song), template: .song)

			guard case .media(let props) = item.props else {
				Issue.record("expected .media")
				return
			}

			#expect(props.accessory == .like(isLiked: true, summary: "12 people buzzed this"))
		}

		@Test func `the intermission song carries no like accessory`() {
			let song = makeSong(songId: Song.intermissionSongId, text: "Taking a break\nBack soon")
			let item = makeItem(.song(song), template: .song)

			guard case .media(let props) = item.props else {
				Issue.record("expected .media")
				return
			}

			#expect(props.accessory == nil)
		}
	}

	struct `Venue props` {
		@Test func `a plain venue template maps to venue props with its badges`() {
			let venue = makeVenue(
				text: "The Fox\n123 High Street",
				properties: .hasJukebox,
				checkedIn: true,
			)
			let item = makeItem(.venue(venue), template: .venue)

			guard case .venue(let props) = item.props else {
				Issue.record("expected .venue")
				return
			}

			#expect(props.name == "The Fox")
			#expect(props.address == "123 High Street")
			#expect(props.hasJukebox == true)
			#expect(props.isCheckedIn == true)
		}

		@Test(arguments: [Template.checkIn, .award])
		func `check-in and award templates map to event props instead of venue props`(template: Template) {
			let venue = makeVenue(text: "You checked in at The Fox\nChiswick · 2 hours ago")
			let item = makeItem(.venue(venue), template: template)

			guard case .event(let props) = item.props else {
				Issue.record("expected .event")
				return
			}

			#expect(props.lines == ["You checked in at The Fox", "Chiswick · 2 hours ago"])
		}

		@Test func `checkIn events use the check-in icon`() {
			let item = makeItem(.venue(makeVenue(text: "Checked in")), template: .checkIn)

			guard case .event(let props) = item.props else {
				Issue.record("expected .event")
				return
			}

			#expect(props.icon == .checkIn)
		}

		@Test func `award events use the award icon`() {
			let item = makeItem(.venue(makeVenue(text: "Badge unlocked")), template: .award)

			guard case .event(let props) = item.props else {
				Issue.record("expected .event")
				return
			}

			#expect(props.icon == .award)
		}

		@Test func `a horizontal award template stays venue-shaped, not event-shaped`() {
			let venue = makeVenue(text: "The Fox\n123 High Street")
			let item = makeItem(.venue(venue), template: .horizontalAward)

			guard case .venue = item.props else {
				Issue.record("expected .venue")
				return
			}
		}
	}

	struct `Person props` {
		@Test func `maps name and subtitle from the first two tagged lines`() {
			let item = makeItem(.person(makePerson(text: "Nick Banks\n12 places visited")), template: .person)

			guard case .person(let props) = item.props else {
				Issue.record("expected .person")
				return
			}

			#expect(props.name == "Nick Banks")
			#expect(props.subtitle == "12 places visited")
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

	struct `Artist props` {
		@Test func `uses the client synthesized display text, not tagged lines`() {
			let artist = Artist(name: "", artist: "The Beatles", numSongs: 3, sortIndex: 0, action: nil, actions: [])
			let item = makeItem(.artist(artist), template: .artist)

			guard case .media(let props) = item.props else {
				Issue.record("expected .media")
				return
			}

			#expect(props.title == "The Beatles ...")
			#expect(props.subtitle == nil)
		}
	}

	struct `Jukebox props` {
		@Test func `prefers the structured subtitle field over a second tagged line`() {
			let jukebox = Jukebox(
				itemType: [],
				jukeboxId: 7,
				textColour: "#000000",
				subtitle: "42 songs",
				text: "Rock Classics",
				sortIndex: 0,
				action: nil,
				actions: [],
			)
			let item = makeItem(.jukebox(jukebox), template: .jukeboxList)

			guard case .media(let props) = item.props else {
				Issue.record("expected .media")
				return
			}

			#expect(props.title == "Rock Classics")
			#expect(props.subtitle == "42 songs")
			#expect(props.accessory == .chevron)
		}
	}

	struct `TopUp props` {
		@Test func `prefers the structured display price`() {
			let topUp = makeTopUp(text: "20 credits\nBest value", displayPrice: "£1.99", price: "1.99")
			let item = makeItem(.topUp(topUp), template: .topUp)

			guard case .topUp(let props) = item.props else {
				Issue.record("expected .topUp")
				return
			}

			#expect(props.title == "20 credits")
			#expect(props.subtitle == "Best value")
			#expect(props.priceText == "£1.99")
		}

		@Test func `falls back to the raw price when no display price is set`() {
			let topUp = makeTopUp(text: "20 credits", displayPrice: "", price: "1.99")
			let item = makeItem(.topUp(topUp), template: .topUp)

			guard case .topUp(let props) = item.props else {
				Issue.record("expected .topUp")
				return
			}

			#expect(props.priceText == "1.99")
		}
	}

	struct `Promotion props` {
		@Test func `carries the item's text as its caption`() {
			let item = makeItem(.promotion(makePromotion(text: "Follow us")), template: .promotion)

			guard case .promotion(let props) = item.props else {
				Issue.record("expected .promotion")
				return
			}

			#expect(props.caption == "Follow us")
			#expect(props.artworkURL == nil)
		}

		@Test func `an empty text has no caption`() {
			let item = makeItem(.promotion(makePromotion(text: "")), template: .advert)

			guard case .promotion(let props) = item.props else {
				Issue.record("expected .promotion")
				return
			}

			#expect(props.caption == nil)
		}
	}

	struct `Control props` {
		@Test func `parses the background color from its hex string`() {
			let control = makeControl(text: "Chilled", bgColour: "#6C2BD9")
			let item = makeItem(.control(control), template: .matrixControlLarge)

			guard case .controlTile(let props) = item.props else {
				Issue.record("expected .controlTile")
				return
			}

			#expect(props.title == "Chilled")
			#expect(props.color == Theme.RGBAComponents(hex: "#6C2BD9"))
			#expect(props.icon == .mood)
		}

		@Test func `an unparseable color falls back rather than crashing`() {
			let control = makeControl(text: "Chilled", bgColour: "not-a-color")
			let item = makeItem(.control(control), template: .matrixControlLarge)

			guard case .controlTile(let props) = item.props else {
				Issue.record("expected .controlTile")
				return
			}

			#expect(props.color.alpha == 1)
		}
	}

	struct `Unsupported items` {
		@Test func `an unsupported item safely drops instead of crashing`() {
			let item = FeedDisplayItem(
				id: "x",
				item: .unsupported(Template(rawValue: 999)),
				text: "",
				template: Template(rawValue: 999),
			)

			#expect(item.props == .dropped)
		}
	}
}

// MARK: - Fixtures

private func makeItem(_ item: Item, template: Template) -> FeedDisplayItem {
	FeedDisplayItem(id: item.stableID, item: item, text: item.displayText ?? "", template: template)
}

private func makeSong(
	songId: String = "1",
	text: String = "",
	likeInfo: LikeInfo = LikeInfo(likedByYou: false, info: ""),
) -> Song {
	Song(
		songId: songId,
		title: "",
		artist: "",
		previewURL: nil,
		likeInfo: likeInfo,
		text: text,
		sortIndex: 0,
		action: nil,
		actions: [],
	)
}

private func makeVenue(
	text: String,
	properties: VenueProperties = [],
	checkedIn: Bool = false,
) -> Venue {
	Venue(
		venueId: "v1",
		name: "",
		address: "",
		telephone: "",
		lat: 0,
		lng: 0,
		zoneName: "",
		promotionURL: nil,
		likeInfo: LikeInfo(likedByYou: false, info: ""),
		properties: properties,
		checkedIn: checkedIn,
		hasMachineControl: false,
		text: text,
		sortIndex: 0,
		action: nil,
		actions: [],
	)
}

private func makePerson(text: String, likeInfo: LikeInfo = LikeInfo(likedByYou: false, info: "")) -> Person {
	Person(
		personId: "p1",
		screenName: "",
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

private func makeTopUp(text: String, displayPrice: String, price: String) -> TopUp {
	TopUp(
		sku: "sku",
		vendor: .unknown,
		name: "",
		productDescription: "",
		price: price,
		displayPrice: displayPrice,
		currencyCode: "",
		url: nil,
		numCredits: 0,
		text: text,
		sortIndex: 0,
		action: nil,
		actions: [],
	)
}

private func makePromotion(text: String) -> Promotion {
	Promotion(
		promotionId: 1,
		url: nil,
		externalBrowser: false,
		height: 0,
		text: text,
		sortIndex: 0,
		action: nil,
		actions: [],
	)
}

private func makeControl(text: String, bgColour: String) -> Control {
	Control(fgColour: "#FFFFFF", bgColour: bgColour, text: text, sortIndex: 0, action: nil, actions: [])
}
