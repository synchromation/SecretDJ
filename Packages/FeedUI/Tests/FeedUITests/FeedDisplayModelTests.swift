import Testing

@testable import FeedUI

import SecretDJDomain

enum FeedDisplayModelTests {
	struct `Visible sections` {
		@Test func `a plain-template section becomes a list-kind visible section`() {
			let sectionList = SectionList(
				hash: FeedHash(rawValue: "h1"),
				sections: [makeSection(template: .song, title: "Now Playing", index: 0, items: [.song(makeSong())])],
				actions: [],
			)

			let model = FeedDisplayModel(sectionList: sectionList)

			#expect(model.visibleSections.count == 1)
			#expect(model.visibleSections[0].kind == .list)
			#expect(model.visibleSections[0].title == "Now Playing")
		}

		@Test func `a container-template section becomes a carousel-kind visible section`() {
			let sectionList = SectionList(
				hash: FeedHash(rawValue: "h1"),
				sections: [makeSection(template: .container, title: "Trending", index: 0, items: [])],
				actions: [],
			)

			let model = FeedDisplayModel(sectionList: sectionList)

			#expect(model.visibleSections[0].kind == .carousel)
		}

		@Test func `a matrix-template section becomes a grid-kind visible section`() {
			let sectionList = SectionList(
				hash: FeedHash(rawValue: "h1"),
				sections: [makeSection(template: .matrixSongSmall, title: "More songs", index: 0, items: [])],
				actions: [],
			)

			let model = FeedDisplayModel(sectionList: sectionList)

			#expect(model.visibleSections[0].kind == .grid)
		}

		@Test func `visible sections carry render-ready items with stable ids and display text`() {
			let sectionList = SectionList(
				hash: FeedHash(rawValue: "h1"),
				sections: [
					makeSection(
						template: .song,
						title: "Now Playing",
						index: 0,
						items: [.song(makeSong(songId: "42", text: "Bohemian Rhapsody"))],
					),
				],
				actions: [],
			)

			let model = FeedDisplayModel(sectionList: sectionList)

			let items = model.visibleSections[0].items
			#expect(items.count == 1)
			#expect(items[0].id == "song-42")
			#expect(items[0].text == "Bohemian Rhapsody")
		}

		@Test func `visible items carry their section's template, since cell selection needs it`() {
			let sectionList = SectionList(
				hash: FeedHash(rawValue: "h1"),
				sections: [
					makeSection(
						template: .checkIn,
						title: "Activity",
						index: 0,
						items: [.venue(makeVenue(venueId: "v1", name: "The Fox"))],
					),
				],
				actions: [],
			)

			let model = FeedDisplayModel(sectionList: sectionList)

			#expect(model.visibleSections[0].items[0].template == .checkIn)
		}

		@Test func `visible sections stay ordered as the server sent them`() {
			let sectionList = SectionList(
				hash: FeedHash(rawValue: "h1"),
				sections: [
					makeSection(template: .song, title: "First", index: 0, items: []),
					makeSection(template: .venue, title: "Second", index: 1, items: []),
				],
				actions: [],
			)

			let model = FeedDisplayModel(sectionList: sectionList)

			#expect(model.visibleSections.map(\.title) == ["First", "Second"])
		}

		@Test func `two sections at different indices get different ids`() {
			let sectionList = SectionList(
				hash: FeedHash(rawValue: "h1"),
				sections: [
					makeSection(template: .song, title: "First", index: 0, items: []),
					makeSection(template: .song, title: "Second", index: 1, items: []),
				],
				actions: [],
			)

			let model = FeedDisplayModel(sectionList: sectionList)

			#expect(model.visibleSections[0].id != model.visibleSections[1].id)
		}

		@Test func `an item this build can't map to a payload is dropped from an otherwise-visible section`() {
			let sectionList = SectionList(
				hash: FeedHash(rawValue: "h1"),
				sections: [
					makeSection(
						template: .song,
						title: "Now Playing",
						index: 0,
						items: [
							.song(makeSong(songId: "42", text: "Bohemian Rhapsody")),
							.unsupported(Template(rawValue: 9)),
						],
					),
				],
				actions: [],
			)

			let model = FeedDisplayModel(sectionList: sectionList)

			#expect(model.visibleSections[0].items.count == 1)
		}
	}

	struct `Dropped sections` {
		@Test func `an unrecognized template drops the section instead of guessing a layout`() {
			let sectionList = SectionList(
				hash: FeedHash(rawValue: "h1"),
				sections: [makeSection(template: Template(rawValue: 424_242), title: "Mystery", index: 3, items: [])],
				actions: [],
			)

			let model = FeedDisplayModel(sectionList: sectionList)

			#expect(model.visibleSections.isEmpty)
			#expect(model.droppedSections == [
				DroppedSection(template: Template(rawValue: 424_242), title: "Mystery", index: 3),
			])
		}

		@Test func `a recognized template never appears in droppedSections`() {
			let sectionList = SectionList(
				hash: FeedHash(rawValue: "h1"),
				sections: [makeSection(template: .song, title: "Now Playing", index: 0, items: [])],
				actions: [],
			)

			let model = FeedDisplayModel(sectionList: sectionList)

			#expect(model.droppedSections.isEmpty)
		}
	}

	struct `Hidden sections` {
		@Test func `hiddenVenueDetails exposes the venue payload by type`() {
			let venue = makeVenue(venueId: "v1", name: "The Fox")
			let sectionList = SectionList(
				hash: FeedHash(rawValue: "h1"),
				sections: [makeSection(template: .hiddenVenueDetails, title: "", index: 0, items: [.venue(venue)])],
				actions: [],
			)

			let model = FeedDisplayModel(sectionList: sectionList)

			#expect(model.venueDetails == venue)
			#expect(model.visibleSections.isEmpty)
		}

		@Test func `hiddenUserDetails exposes the signed-in user's profile by type`() {
			let person = makePerson(personId: "p1", screenName: "Nick")
			let sectionList = SectionList(
				hash: FeedHash(rawValue: "h1"),
				sections: [makeSection(template: .hiddenUserDetails, title: "", index: 0, items: [.person(person)])],
				actions: [],
			)

			let model = FeedDisplayModel(sectionList: sectionList)

			#expect(model.userDetails == person)
		}

		@Test func `hiddenProfile exposes another user's profile by type`() {
			let person = makePerson(personId: "p2", screenName: "Someone Else")
			let sectionList = SectionList(
				hash: FeedHash(rawValue: "h1"),
				sections: [makeSection(template: .hiddenProfile, title: "", index: 0, items: [.person(person)])],
				actions: [],
			)

			let model = FeedDisplayModel(sectionList: sectionList)

			#expect(model.profile == person)
		}

		@Test func `hiddenJukeboxList exposes every jukebox by type`() {
			let jukeboxes = [makeJukebox(jukeboxId: 1), makeJukebox(jukeboxId: 2)]
			let sectionList = SectionList(
				hash: FeedHash(rawValue: "h1"),
				sections: [
					makeSection(template: .hiddenJukeboxList, title: "", index: 0, items: jukeboxes.map(Item.jukebox)),
				],
				actions: [],
			)

			let model = FeedDisplayModel(sectionList: sectionList)

			#expect(model.jukeboxList == jukeboxes)
		}

		@Test func `hiddenExtraContentSong exposes the rotating ticker songs by type`() {
			let songs = [makeSong(songId: "1"), makeSong(songId: "2")]
			let sectionList = SectionList(
				hash: FeedHash(rawValue: "h1"),
				sections: [
					makeSection(template: .hiddenExtraContentSong, title: "", index: 0, items: songs.map(Item.song)),
				],
				actions: [],
			)

			let model = FeedDisplayModel(sectionList: sectionList)

			#expect(model.extraContentSongs == songs)
		}

		@Test func `an absent hidden template reads as nil or empty rather than crashing`() {
			let model = FeedDisplayModel(sectionList: SectionList(
				hash: FeedHash(rawValue: "h1"),
				sections: [],
				actions: [],
			))

			#expect(model.venueDetails == nil)
			#expect(model.userDetails == nil)
			#expect(model.profile == nil)
			#expect(model.jukeboxList.isEmpty)
			#expect(model.extraContentSongs.isEmpty)
		}
	}
}

// MARK: - Fixtures

private func makeSection(template: Template, title: String, index: Int, items: [Item]) -> Section {
	Section(itemType: [], template: template, title: title, index: index, store: nil, hash: nil, items: items)
}

private func makeSong(songId: String = "1", text: String = "") -> Song {
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

private func makeVenue(venueId: String, name: String) -> Venue {
	Venue(
		venueId: venueId,
		name: name,
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

private func makePerson(personId: String, screenName: String) -> Person {
	Person(
		personId: personId,
		screenName: screenName,
		gender: .unisex,
		likeInfo: LikeInfo(likedByYou: false, info: ""),
		email: nil,
		firstName: nil,
		lastName: nil,
		text: "",
		sortIndex: 0,
		action: nil,
		actions: [],
	)
}

private func makeJukebox(jukeboxId: Int) -> Jukebox {
	Jukebox(
		itemType: [],
		jukeboxId: jukeboxId,
		textColour: "#000000",
		subtitle: "",
		text: "",
		sortIndex: 0,
		action: nil,
		actions: [],
	)
}
