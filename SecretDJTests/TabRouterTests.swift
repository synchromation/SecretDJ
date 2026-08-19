import FeedUI
import Testing

@testable import SecretDJ

/// One tab's own back stack (PLAN.md S5.2 — a `NavigationStack` per tab):
/// routes a feed outcome to its destination and mirrors SwiftUI's own pops
/// back into the model.
@MainActor
enum TabRouterTests {
	struct `Starting up` {
		@Test func `starts with an empty path`() {
			let router = TabRouter()

			#expect(router.path.isEmpty)
		}
	}

	struct `Routing outcomes` {
		@Test func `a navigational outcome pushes its destination`() {
			let router = TabRouter()

			router.handle(outcome: .showVenue(venueId: "v1"))

			#expect(router.path == [.venue(venueId: "v1")])
		}

		@Test func `several navigational outcomes push in order`() {
			let router = TabRouter()

			router.handle(outcome: .showVenue(venueId: "v1"))
			router.handle(outcome: .showPerson(personId: "p1"))

			#expect(router.path == [.venue(venueId: "v1"), .person(personId: "p1")])
		}

		@Test func `a non-navigational outcome pushes nothing`() {
			let router = TabRouter()

			router.handle(outcome: .requestSong(itemId: 1))

			#expect(router.path.isEmpty)
		}
	}

	struct `Routing venue-context outcomes` {
		@Test func `showJukebox pushes the jukebox destination with the supplied venue id`() {
			let router = TabRouter()

			router.handle(outcome: .showJukebox(jukeboxId: 7), venueId: "v1")

			#expect(router.path == [.jukebox(venueId: "v1", jukeboxId: 7)])
		}

		@Test func `launchSearch pushes the search destination with the supplied venue id`() {
			let router = TabRouter()

			router.handle(outcome: .launchSearch, venueId: "v1")

			#expect(router.path == [.search(venueId: "v1")])
		}

		@Test func `showSongsForArtist pushes the songsForArtist destination with the supplied venue id`() {
			let router = TabRouter()

			router.handle(outcome: .showSongsForArtist(artist: "Adele"), venueId: "v1")

			#expect(router.path == [.songsForArtist(venueId: "v1", artist: "Adele")])
		}

		@Test func `an outcome AppDestination already resolves ignores the supplied venue id`() {
			let router = TabRouter()

			router.handle(outcome: .showVenue(venueId: "v2"), venueId: "v1")

			#expect(router.path == [.venue(venueId: "v2")])
		}

		@Test func `a non-navigational outcome pushes nothing`() {
			let router = TabRouter()

			router.handle(outcome: .requestSong(itemId: 1), venueId: "v1")

			#expect(router.path.isEmpty)
		}
	}

	struct `Mirroring SwiftUI's own pops` {
		@Test func `setPath replaces the router's path`() {
			let router = TabRouter()
			router.handle(outcome: .showVenue(venueId: "v1"))

			router.setPath([])

			#expect(router.path.isEmpty)
		}
	}

	struct `Pushing a destination directly` {
		@Test func `push appends a destination not reachable through a feed outcome`() {
			let router = TabRouter()

			router.push(.nowPlaying(venueId: "v1"))

			#expect(router.path == [.nowPlaying(venueId: "v1")])
		}

		@Test func `push appends after any outcome-routed destinations`() {
			let router = TabRouter()
			router.handle(outcome: .showVenue(venueId: "v1"))

			router.push(.nowPlaying(venueId: "v1"))

			#expect(router.path == [.venue(venueId: "v1"), .nowPlaying(venueId: "v1")])
		}
	}
}
