import Testing

@testable import FeedUI

import SecretDJDomain

enum ItemFeedDisplayTests {
	struct `Stable identity` {
		@Test func `a song's identity is derived from its songId`() {
			let item = Item.song(makeSong(songId: "42", text: "Bohemian Rhapsody"))

			#expect(item.stableID == "song-42")
		}

		@Test func `a venue's identity is derived from its venueId`() {
			let item = Item.venue(makeVenue(venueId: "v1", text: "The Fox"))

			#expect(item.stableID == "venue-v1")
		}

		@Test func `a person's identity is derived from its personId`() {
			let item = Item.person(makePerson(personId: "p1", text: "Nick"))

			#expect(item.stableID == "person-p1")
		}

		@Test func `an artist's identity is derived from its artist name`() {
			let item = Item.artist(makeArtist(artist: "The Beatles"))

			#expect(item.stableID == "artist-The Beatles")
		}

		@Test func `a jukebox's identity is derived from its jukeboxId`() {
			let item = Item.jukebox(makeJukebox(jukeboxId: 7, text: "Rock"))

			#expect(item.stableID == "jukebox-7")
		}

		@Test func `a top-up's identity is derived from its sku`() {
			let item = Item.topUp(makeTopUp(sku: "credits.20", text: "20 credits"))

			#expect(item.stableID == "topUp-credits.20")
		}

		@Test func `a promotion's identity is derived from its promotionId`() {
			let item = Item.promotion(makePromotion(promotionId: -4, text: "Follow us"))

			#expect(item.stableID == "promotion--4")
		}

		@Test func `a control's identity is derived from its action's itemId when it has one`() {
			let action = Action(
				kind: .jukeboxChangeAtmosphere,
				itemId: 99,
				itemTypeId: nil,
				value: "30",
				url: nil,
				button: .unsupported(0),
			)
			let item = Item.control(makeControl(text: "Chilled", action: action))

			#expect(item.stableID == "control-99")
		}

		@Test func `a control with no action falls back to its text`() {
			let item = Item.control(makeControl(text: "Chilled", action: nil))

			#expect(item.stableID == "control-Chilled")
		}

		@Test func `an unsupported item's identity is derived from its raw template code`() {
			let item = Item.unsupported(Template(rawValue: 4242))

			#expect(item.stableID == "unsupported-4242")
		}
	}

	struct `Display text` {
		@Test func `a song displays its pre-formatted text`() {
			let item = Item.song(makeSong(songId: "42", text: "Bohemian Rhapsody\nQueen"))

			#expect(item.displayText == "Bohemian Rhapsody\nQueen")
		}

		@Test func `a venue displays its pre-formatted text`() {
			let item = Item.venue(makeVenue(venueId: "v1", text: "The Fox\nChiswick"))

			#expect(item.displayText == "The Fox\nChiswick")
		}

		@Test func `a person displays its pre-formatted text`() {
			let item = Item.person(makePerson(personId: "p1", text: "Nick"))

			#expect(item.displayText == "Nick")
		}

		@Test func `a jukebox displays its pre-formatted text`() {
			let item = Item.jukebox(makeJukebox(jukeboxId: 7, text: "Rock"))

			#expect(item.displayText == "Rock")
		}

		@Test func `a top-up displays its pre-formatted text`() {
			let item = Item.topUp(makeTopUp(sku: "credits.20", text: "20 credits"))

			#expect(item.displayText == "20 credits")
		}

		@Test func `a promotion displays its pre-formatted text`() {
			let item = Item.promotion(makePromotion(promotionId: -4, text: "Follow us"))

			#expect(item.displayText == "Follow us")
		}

		@Test func `a control displays its pre-formatted text`() {
			let item = Item.control(makeControl(text: "Chilled", action: nil))

			#expect(item.displayText == "Chilled")
		}

		@Test func `an artist displays its client-synthesized display text, not its raw item text`() {
			let item = Item.artist(makeArtist(artist: "The Beatles", numSongs: 3))

			#expect(item.displayText == "The Beatles ...")
		}

		@Test func `an unsupported item has no display text`() {
			let item = Item.unsupported(Template(rawValue: 4242))

			#expect(item.displayText == nil)
		}
	}
}

// MARK: - Fixtures

private func makeSong(songId: String, text: String) -> Song {
	Song(
		songId: songId,
		title: "",
		artist: "",
		previewURL: nil,
		likeInfo: LikeInfo(likedByYou: false, info: ""),
		text: text,
		sortIndex: 0,
		action: nil,
		actions: [],
	)
}

private func makeVenue(venueId: String, text: String) -> Venue {
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
		text: text,
		sortIndex: 0,
		action: nil,
		actions: [],
	)
}

private func makePerson(personId: String, text: String) -> Person {
	Person(
		personId: personId,
		screenName: "",
		gender: .unisex,
		likeInfo: LikeInfo(likedByYou: false, info: ""),
		email: nil,
		firstName: nil,
		lastName: nil,
		text: text,
		sortIndex: 0,
		action: nil,
		actions: [],
	)
}

private func makeArtist(artist: String, numSongs: Int = 1) -> Artist {
	Artist(name: "", artist: artist, numSongs: numSongs, sortIndex: 0, action: nil, actions: [])
}

private func makeJukebox(jukeboxId: Int, text: String) -> Jukebox {
	Jukebox(
		itemType: [],
		jukeboxId: jukeboxId,
		textColour: "#000000",
		subtitle: "",
		text: text,
		sortIndex: 0,
		action: nil,
		actions: [],
	)
}

private func makeTopUp(sku: String, text: String) -> TopUp {
	TopUp(
		sku: sku,
		vendor: .unknown,
		name: "",
		productDescription: "",
		price: "",
		displayPrice: "",
		currencyCode: "",
		url: nil,
		numCredits: 0,
		text: text,
		sortIndex: 0,
		action: nil,
		actions: [],
	)
}

private func makePromotion(promotionId: Int, text: String) -> Promotion {
	Promotion(
		promotionId: promotionId,
		url: nil,
		externalBrowser: false,
		height: 0,
		text: text,
		sortIndex: 0,
		action: nil,
		actions: [],
	)
}

private func makeControl(text: String, action: Action?) -> Control {
	Control(fgColour: "#FFFFFF", bgColour: "#000000", text: text, sortIndex: 0, action: action, actions: [])
}
