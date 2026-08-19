import SecretDJDomain
import Testing

@testable import SecretDJ

/// ``ExtraContentEntry`` — the ticker's per-item display value, derived once
/// from a fetched ``Item`` (PLAN.md S6.9). Mirrors
/// `secretdjv3/ExtraContentManager.swift`'s `extraContentViewConfig(song:)`/
/// `extraContentViewConfig(person:)` line-splitting exactly, including their
/// asymmetric fallback branches.
enum ExtraContentEntryTests {
	struct `Building from a song item` {
		@Test func `adds the localized caption and splits title-subtitle when the text has three or more lines`() {
			let entry = ExtraContentEntry(item: .song(makeSong(text: "Bobby Womack\nAcross 110th Street\nLiked by 3")))

			#expect(entry?.caption == "Now playing…")
			#expect(entry?.title == "Bobby Womack")
			#expect(entry?.subtitle == "Across 110th Street")
		}

		@Test func `has no caption and splits title-subtitle when the text has exactly two lines`() {
			let entry = ExtraContentEntry(item: .song(makeSong(text: "Bobby Womack\nAcross 110th Street")))

			#expect(entry?.caption == nil)
			#expect(entry?.title == "Bobby Womack")
			#expect(entry?.subtitle == "Across 110th Street")
		}

		@Test func `puts the whole text in the title and leaves the subtitle nil when the text has one line`() {
			let entry = ExtraContentEntry(item: .song(makeSong(text: "Bobby Womack")))

			#expect(entry?.caption == nil)
			#expect(entry?.title == "Bobby Womack")
			#expect(entry?.subtitle == nil)
		}

		@Test func `resolves the artwork at the 4x4 size class`() {
			let song = makeSong(text: "A\nB", image: ItemImage(
				itemType: .song,
				uri: "s1/s1.jpg",
				size: 1,
				resolutions: .large,
			))

			let entry = ExtraContentEntry(item: .song(song))

			#expect(entry?.imageURL == song.image?.url(for: .size4x4))
		}

		@Test func `ids itself from the song id`() {
			let entry = ExtraContentEntry(item: .song(makeSong(songId: "42", text: "A")))

			#expect(entry?.id == "song-42")
		}
	}

	struct `Building from a person item` {
		@Test func `splits into three lines when the text has three or more lines`() {
			let entry = ExtraContentEntry(item: .person(makePerson(
				text: "Nick Banks\n12 places visited\n134 people like you",
			)))

			#expect(entry?.caption == "Nick Banks")
			#expect(entry?.title == "12 places visited")
			#expect(entry?.subtitle == "134 people like you")
		}

		@Test func `leaves every line nil when the text has fewer than three lines`() {
			let entry = ExtraContentEntry(item: .person(makePerson(text: "Nick Banks\n12 places visited")))

			#expect(entry?.caption == nil)
			#expect(entry?.title == nil)
			#expect(entry?.subtitle == nil)
		}

		@Test func `ids itself from the person id`() {
			let entry = ExtraContentEntry(item: .person(makePerson(personId: "p9", text: "A\nB\nC")))

			#expect(entry?.id == "person-p9")
		}
	}

	struct `Building from every other item kind` {
		@Test func `returns nil`() {
			let entry = ExtraContentEntry(item: .unsupported(.checkIn))

			#expect(entry == nil)
		}
	}
}

// MARK: - Fixtures

private func makeSong(songId: String = "1", text: String, image: ItemImage? = nil) -> Song {
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
		image: image,
	)
}

private func makePerson(personId: String = "1", text: String) -> Person {
	Person(
		personId: personId,
		screenName: "dj",
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
