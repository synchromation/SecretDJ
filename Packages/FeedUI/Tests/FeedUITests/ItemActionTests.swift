import Testing

@testable import FeedUI

import SecretDJDomain

struct ItemActionTests {
	@Test func `a song's action is its own action field`() {
		let action = makeAction()
		let item = Item.song(makeSong(action: action))

		#expect(item.action == action)
	}

	@Test func `a venue's action is its own action field`() {
		let action = makeAction()
		let item = Item.venue(makeVenue(action: action))

		#expect(item.action == action)
	}

	@Test func `a person's action is its own action field`() {
		let action = makeAction()
		let item = Item.person(makePerson(action: action))

		#expect(item.action == action)
	}

	@Test func `an artist's action is its own action field`() {
		let action = makeAction()
		let item = Item.artist(makeArtist(action: action))

		#expect(item.action == action)
	}

	@Test func `a jukebox's action is its own action field`() {
		let action = makeAction()
		let item = Item.jukebox(makeJukebox(action: action))

		#expect(item.action == action)
	}

	@Test func `a top-up's action is its own action field`() {
		let action = makeAction()
		let item = Item.topUp(makeTopUp(action: action))

		#expect(item.action == action)
	}

	@Test func `a promotion's action is its own action field`() {
		let action = makeAction()
		let item = Item.promotion(makePromotion(action: action))

		#expect(item.action == action)
	}

	@Test func `a control's action is its own action field`() {
		let action = makeAction()
		let item = Item.control(makeControl(action: action))

		#expect(item.action == action)
	}

	@Test func `an unsupported item has no action`() {
		let item = Item.unsupported(Template(rawValue: 4242))

		#expect(item.action == nil)
	}
}

// MARK: - Fixtures

private func makeAction() -> Action {
	Action(kind: .jukeboxRequestSong, itemId: 1, itemTypeId: nil, value: nil, url: nil, button: .unsupported(0))
}

private func makeSong(action: Action?) -> Song {
	Song(
		songId: "1",
		title: "",
		artist: "",
		previewURL: nil,
		likeInfo: LikeInfo(likedByYou: false, info: ""),
		text: "",
		sortIndex: 0,
		action: action,
		actions: [],
	)
}

private func makeVenue(action: Action?) -> Venue {
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
		properties: [],
		checkedIn: false,
		hasMachineControl: false,
		text: "",
		sortIndex: 0,
		action: action,
		actions: [],
	)
}

private func makePerson(action: Action?) -> Person {
	Person(
		personId: "p1",
		screenName: "",
		gender: .unisex,
		likeInfo: LikeInfo(likedByYou: false, info: ""),
		email: nil,
		firstName: nil,
		lastName: nil,
		text: "",
		sortIndex: 0,
		action: action,
		actions: [],
	)
}

private func makeArtist(action: Action?) -> Artist {
	Artist(name: "The Beatles", artist: "The Beatles", numSongs: 1, sortIndex: 0, action: action, actions: [])
}

private func makeJukebox(action: Action?) -> Jukebox {
	Jukebox(
		itemType: [],
		jukeboxId: 7,
		textColour: "#000000",
		subtitle: "",
		text: "",
		sortIndex: 0,
		action: action,
		actions: [],
	)
}

private func makeTopUp(action: Action?) -> TopUp {
	TopUp(
		sku: "sku",
		vendor: .unknown,
		name: "",
		productDescription: "",
		price: "",
		displayPrice: "",
		currencyCode: "",
		url: nil,
		numCredits: 0,
		text: "",
		sortIndex: 0,
		action: action,
		actions: [],
	)
}

private func makePromotion(action: Action?) -> Promotion {
	Promotion(
		promotionId: 1,
		url: nil,
		externalBrowser: false,
		height: 0,
		text: "",
		sortIndex: 0,
		action: action,
		actions: [],
	)
}

private func makeControl(action: Action?) -> Control {
	Control(fgColour: "#FFFFFF", bgColour: "#000000", text: "", sortIndex: 0, action: action, actions: [])
}
