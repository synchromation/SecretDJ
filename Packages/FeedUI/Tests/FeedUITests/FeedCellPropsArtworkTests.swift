import DesignSystem
import Foundation
import Testing

@testable import FeedUI

import SecretDJDomain

/// Coverage for resolving `FeedCellProps`' `artworkURL`/`avatarURL` fields
/// from each payload's decoded `SecretDJDomain.ItemImage` — split out of
/// `FeedCellPropsTests` to keep that file under the project's file-length
/// limit.
enum FeedCellPropsArtworkTests {
	struct `Song artwork` {
		@Test func `resolves from the song's decoded image at the row bucket`() {
			let song = makeSong(text: "Bohemian Rhapsody\nQueen", image: makeItemImage(itemType: .song))
			let item = makeItem(.song(song), template: .song)

			guard case .media(let props) = item.props else {
				Issue.record("expected .media")
				return
			}

			#expect(props.artworkURL == URL(string: "https://secretdj.s3.amazonaws.com/songcovers/260x260/x.jpg?1"))
		}

		@Test func `stays nil when the song has no decoded image`() {
			let item = makeItem(.song(makeSong(text: "Bohemian Rhapsody\nQueen")), template: .song)

			guard case .media(let props) = item.props else {
				Issue.record("expected .media")
				return
			}

			#expect(props.artworkURL == nil)
		}
	}

	struct `Venue artwork` {
		@Test func `resolves from the venue's decoded image at the row bucket`() {
			let venue = makeVenue(text: "The Fox\n123 High Street", image: makeItemImage(itemType: .venue))
			let item = makeItem(.venue(venue), template: .venue)

			guard case .venue(let props) = item.props else {
				Issue.record("expected .venue")
				return
			}

			#expect(props.artworkURL == URL(string: "https://secretdj.s3.amazonaws.com/venues/260x260/x.jpg?1"))
		}
	}

	struct `Person avatar` {
		@Test func `resolves from the person's decoded image at the row bucket`() {
			let person = makePerson(text: "Nick Banks", image: makeItemImage(itemType: .person))
			let item = makeItem(.person(person), template: .person)

			guard case .person(let props) = item.props else {
				Issue.record("expected .person")
				return
			}

			#expect(props.avatarURL == URL(string: "https://secretdj.s3.amazonaws.com/useravatars/260x260/x.jpg?1"))
		}
	}

	struct `Jukebox artwork` {
		@Test func `resolves from the jukebox's decoded image at the row bucket`() {
			let jukebox = Jukebox(
				itemType: [],
				jukeboxId: 7,
				textColour: "#000000",
				subtitle: "42 songs",
				text: "Rock Classics",
				sortIndex: 0,
				action: nil,
				actions: [],
				image: makeItemImage(itemType: .jukebox),
			)
			let item = makeItem(.jukebox(jukebox), template: .jukeboxList)

			guard case .media(let props) = item.props else {
				Issue.record("expected .media")
				return
			}

			#expect(props.artworkURL == URL(string: "https://secretdj.s3.amazonaws.com/jukeboxes/260x260/x.jpg?1"))
		}
	}

	struct `Promotion artwork` {
		@Test func `resolves from the promotion's decoded image at the row bucket`() {
			let promotion = makePromotion(text: "Follow us", image: makeItemImage(itemType: .promotion))
			let item = makeItem(.promotion(promotion), template: .promotion)

			guard case .promotion(let props) = item.props else {
				Issue.record("expected .promotion")
				return
			}

			#expect(props.artworkURL == URL(string: "https://secretdj.s3.amazonaws.com/promotions/260x260/x.jpg?1"))
		}
	}

	struct `Artist artwork` {
		/// Legacy never resolved a real image bucket for artist rows
		/// (`ItemImage.swift`'s `imageBaseURL()` has no `.artist` case), so
		/// even a present `Image` maps to no artwork here.
		@Test func `stays nil even with a decoded image, matching legacy's unmapped bucket`() {
			let artist = Artist(
				name: "",
				artist: "The Beatles",
				numSongs: 1,
				sortIndex: 0,
				action: nil,
				actions: [],
				image: makeItemImage(itemType: .artist),
			)
			let item = makeItem(.artist(artist), template: .artist)

			guard case .media(let props) = item.props else {
				Issue.record("expected .media")
				return
			}

			#expect(props.artworkURL == nil)
		}
	}
}

// MARK: - Fixtures

private func makeItem(_ item: Item, template: Template) -> FeedDisplayItem {
	FeedDisplayItem(id: item.stableID, item: item, text: item.displayText ?? "", template: template)
}

/// A fully-available image at every resolution bucket, so any requested size
/// class resolves without a fallback-ladder walk complicating the assertion.
private func makeItemImage(itemType: ItemType) -> ItemImage {
	ItemImage(itemType: itemType, uri: "x.jpg", size: 1, resolutions: ImageResolution(rawValue: 5503))
}

private func makeSong(text: String, image: ItemImage? = nil) -> Song {
	Song(
		songId: "1",
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

private func makeVenue(text: String, image: ItemImage? = nil) -> Venue {
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
		text: text,
		sortIndex: 0,
		action: nil,
		actions: [],
		image: image,
	)
}

private func makePerson(text: String, image: ItemImage? = nil) -> Person {
	Person(
		personId: "p1",
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
		image: image,
	)
}

private func makePromotion(text: String, image: ItemImage? = nil) -> Promotion {
	Promotion(
		promotionId: 1,
		url: nil,
		externalBrowser: false,
		height: 0,
		text: text,
		sortIndex: 0,
		action: nil,
		actions: [],
		image: image,
	)
}
