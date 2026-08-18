import Testing

@testable import FeedUI

import Foundation
import SecretDJDomain

/// Item-tap coverage — default per-payload dispatch, the item-level action
/// override, and promotion deep-link routing. The generic `Action` → outcome
/// mapping shared with nav-bar buttons lives in
/// `FeedActionRouterActionMappingTests`, split out to keep this file under
/// the project's file-length limit.
enum FeedActionRouterTests {
	struct `Default item taps` {
		@Test func `a song shows TuneIn for that song`() {
			let router = FeedActionRouter(installedApps: FakeInstalledApps())
			let item = displayItem(.song(makeSong(songId: "42")))

			#expect(router.outcome(forTap: item) == .showSong(.song(songId: "42")))
		}

		@Test func `the intermission song produces no outcome`() {
			let router = FeedActionRouter(installedApps: FakeInstalledApps())
			let item = displayItem(.song(makeSong(songId: Song.intermissionSongId)))

			#expect(router.outcome(forTap: item) == nil)
		}

		@Test func `a venue shows the venue feed`() {
			let router = FeedActionRouter(installedApps: FakeInstalledApps())
			let item = displayItem(.venue(makeVenue(venueId: "v1")))

			#expect(router.outcome(forTap: item) == .showVenue(venueId: "v1"))
		}

		@Test func `a person shows their profile`() {
			let router = FeedActionRouter(installedApps: FakeInstalledApps())
			let item = displayItem(.person(makePerson(personId: "p1")))

			#expect(router.outcome(forTap: item) == .showPerson(personId: "p1"))
		}

		@Test func `an artist with one song shows TuneIn keyed by name`() {
			let router = FeedActionRouter(installedApps: FakeInstalledApps())
			let item = displayItem(.artist(makeArtist(name: "Adele", numSongs: 1)))

			#expect(router.outcome(forTap: item) == .showSong(.artist(name: "Adele")))
		}

		@Test func `an artist with more than one song shows the songs list`() {
			let router = FeedActionRouter(installedApps: FakeInstalledApps())
			let item = displayItem(.artist(makeArtist(name: "Adele", numSongs: 3)))

			#expect(router.outcome(forTap: item) == .showSongsForArtist(artist: "Adele"))
		}

		@Test func `a jukebox row navigates into that jukebox`() {
			let router = FeedActionRouter(installedApps: FakeInstalledApps())
			let action = makeAction(kind: .jukeboxGotoItem)
			let item = displayItem(.jukebox(makeJukebox(jukeboxId: 7, action: action)))

			#expect(router.outcome(forTap: item) == .showJukebox(jukeboxId: 7))
		}

		@Test func `a top-up bundle produces no outcome`() {
			let router = FeedActionRouter(installedApps: FakeInstalledApps())
			let item = displayItem(.topUp(makeTopUp()))

			#expect(router.outcome(forTap: item) == nil)
		}

		@Test func `a control tile with no action produces no outcome`() {
			let router = FeedActionRouter(installedApps: FakeInstalledApps())
			let item = displayItem(.control(makeControl()))

			#expect(router.outcome(forTap: item) == nil)
		}

		@Test func `an unsupported item produces no outcome`() {
			let router = FeedActionRouter(installedApps: FakeInstalledApps())
			let item = displayItem(.unsupported(Template(rawValue: 4242)))

			#expect(router.outcome(forTap: item) == nil)
		}
	}

	struct `Item-level action override` {
		@Test func `an item carrying a recognized action routes via that action instead of its default`() {
			let router = FeedActionRouter(installedApps: FakeInstalledApps())
			let action = makeAction(kind: .jukeboxChangeAtmosphere, itemId: 99)
			let item = displayItem(.control(makeControl(action: action)))

			#expect(router.outcome(forTap: item) == .changeAtmosphere(itemId: 99))
		}

		@Test func `an item carrying an unsupported action code falls back to its default`() {
			let router = FeedActionRouter(installedApps: FakeInstalledApps())
			let action = makeAction(kind: .unsupported(9999))
			let item = displayItem(.venue(makeVenue(venueId: "v1", action: action)))

			#expect(router.outcome(forTap: item) == .showVenue(venueId: "v1"))
		}
	}

	struct `Song jukebox correlation` {
		@Test func `a song's jukeboxGotoItem action navigates to the jukebox sharing its itemId`() {
			let router = FeedActionRouter(installedApps: FakeInstalledApps())
			let jukeboxes = [
				makeJukebox(jukeboxId: 1, action: makeAction(kind: .jukeboxGotoItem, itemId: 100)),
				makeJukebox(jukeboxId: 2, action: makeAction(kind: .jukeboxGotoItem, itemId: 200)),
			]
			let item = displayItem(.song(makeSong(
				songId: "1",
				action: makeAction(kind: .jukeboxGotoItem, itemId: 200),
			)))

			#expect(router.outcome(forTap: item, jukeboxList: jukeboxes) == .showJukebox(jukeboxId: 2))
		}

		@Test func `a song's jukeboxGotoItem action with no matching jukebox produces no outcome`() {
			let router = FeedActionRouter(installedApps: FakeInstalledApps())
			let jukeboxes = [makeJukebox(jukeboxId: 1, action: makeAction(kind: .jukeboxGotoItem, itemId: 100))]
			let item = displayItem(.song(makeSong(
				songId: "1",
				action: makeAction(kind: .jukeboxGotoItem, itemId: 999),
			)))

			#expect(router.outcome(forTap: item, jukeboxList: jukeboxes) == nil)
		}

		@Test func `a song's jukeboxGotoItem action produces no outcome when no jukebox list is supplied`() {
			let router = FeedActionRouter(installedApps: FakeInstalledApps())
			let item = displayItem(.song(makeSong(
				songId: "1",
				action: makeAction(kind: .jukeboxGotoItem, itemId: 100),
			)))

			#expect(router.outcome(forTap: item) == nil)
		}
	}

	struct `Promotion routing` {
		@Test func `a promotion with no URL pings the engagement endpoint`() {
			let router = FeedActionRouter(installedApps: FakeInstalledApps())
			let item = displayItem(.promotion(makePromotion(promotionId: 5, url: nil)))

			#expect(router.outcome(forTap: item) == .engagePromotion(promotionId: 5))
		}

		@Test func `an Instagram profile URL converts to a native deep link when Instagram is installed`() throws {
			let router = FeedActionRouter(installedApps: FakeInstalledApps(installed: [.instagram]))
			let item = displayItem(.promotion(makePromotion(url: "https://instagram.com/secretdj")))

			#expect(try router.outcome(forTap: item) == .openSocialApp(
				platform: .instagram,
				identifier: "secretdj",
				webFallbackURL: #require(URL(string: "https://instagram.com/secretdj")),
			))
		}

		@Test func `an Instagram profile URL falls through to the browser when Instagram is not installed`() throws {
			let router = FeedActionRouter(installedApps: FakeInstalledApps())
			let item = displayItem(.promotion(makePromotion(
				url: "https://instagram.com/secretdj",
				externalBrowser: true,
			)))

			#expect(try router
				.outcome(forTap: item) ==
				.openURL(.external(#require(URL(string: "https://instagram.com/secretdj")))))
		}

		@Test func `a Twitter profile URL converts to a native deep link when Twitter is installed`() throws {
			let router = FeedActionRouter(installedApps: FakeInstalledApps(installed: [.twitter]))
			let item = displayItem(.promotion(makePromotion(url: "https://twitter.com/secretdj")))

			#expect(try router.outcome(forTap: item) == .openSocialApp(
				platform: .twitter,
				identifier: "secretdj",
				webFallbackURL: #require(URL(string: "https://twitter.com/secretdj")),
			))
		}

		@Test func `a Twitter profile URL falls through to the browser when Twitter is not installed`() throws {
			let router = FeedActionRouter(installedApps: FakeInstalledApps())
			let item = displayItem(.promotion(makePromotion(url: "https://twitter.com/secretdj")))

			#expect(try router
				.outcome(forTap: item) == .openURL(.inApp(#require(URL(string: "https://twitter.com/secretdj")))))
		}

		@Test func `an external-browser promotion opens externally`() throws {
			let router = FeedActionRouter(installedApps: FakeInstalledApps())
			let item = displayItem(.promotion(makePromotion(url: "https://example.com/promo", externalBrowser: true)))

			#expect(try router
				.outcome(forTap: item) == .openURL(.external(#require(URL(string: "https://example.com/promo")))))
		}

		@Test func `an in-app promotion opens in-app`() throws {
			let router = FeedActionRouter(installedApps: FakeInstalledApps())
			let item = displayItem(.promotion(makePromotion(url: "https://example.com/promo", externalBrowser: false)))

			#expect(try router
				.outcome(forTap: item) == .openURL(.inApp(#require(URL(string: "https://example.com/promo")))))
		}

		@Test func `a Facebook profile URL falls through to the browser, out of S3.3's scope`() throws {
			let router = FeedActionRouter(installedApps: FakeInstalledApps(installed: [.facebook]))
			let item = displayItem(.promotion(makePromotion(
				url: "https://facebook.com/secretdj",
				externalBrowser: true,
			)))

			#expect(try router
				.outcome(forTap: item) ==
				.openURL(.external(#require(URL(string: "https://facebook.com/secretdj")))))
		}
	}
}

// MARK: - Fixtures

struct FakeInstalledApps: InstalledApps {
	var installed: Set<SocialPlatform> = []

	func isInstalled(_ platform: SocialPlatform) -> Bool {
		installed.contains(platform)
	}
}

func makeAction(
	kind: ActionKind,
	itemId: Int? = nil,
	url: String? = nil,
	button: ActionButton = .unsupported(0),
) -> Action {
	Action(kind: kind, itemId: itemId, itemTypeId: nil, value: nil, url: url, button: button)
}

private func displayItem(_ item: Item) -> FeedDisplayItem {
	FeedDisplayItem(id: item.stableID, item: item, text: item.displayText ?? "", template: .song)
}

private func makeSong(songId: String, action: Action? = nil) -> Song {
	Song(
		songId: songId,
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

private func makeVenue(venueId: String, action: Action? = nil) -> Venue {
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
		action: action,
		actions: [],
	)
}

private func makePerson(personId: String) -> Person {
	Person(
		personId: personId,
		screenName: "",
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

private func makeArtist(name: String, numSongs: Int) -> Artist {
	Artist(name: name, artist: name, numSongs: numSongs, sortIndex: 0, action: nil, actions: [])
}

private func makeJukebox(jukeboxId: Int, action: Action? = nil) -> Jukebox {
	Jukebox(
		itemType: [],
		jukeboxId: jukeboxId,
		textColour: "#000000",
		subtitle: "",
		text: "",
		sortIndex: 0,
		action: action,
		actions: [],
	)
}

private func makeTopUp() -> TopUp {
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
		action: nil,
		actions: [],
	)
}

private func makePromotion(
	promotionId: Int = 1,
	url: String?,
	externalBrowser: Bool = false,
	action: Action? = nil,
) -> Promotion {
	Promotion(
		promotionId: promotionId,
		url: url,
		externalBrowser: externalBrowser,
		height: 0,
		text: "",
		sortIndex: 0,
		action: action,
		actions: [],
	)
}

private func makeControl(action: Action? = nil) -> Control {
	Control(fgColour: "#FFFFFF", bgColour: "#000000", text: "", sortIndex: 0, action: action, actions: [])
}
