import FeedUI
import Foundation
import SecretDJDomain
import Testing

@testable import SecretDJ

/// Coverage for ``AppDestination/init(outcome:)`` — the outcome→destination
/// mapping `TabRouter` pushes onto a tab's `NavigationPath` (PLAN.md S5.2).
/// `showJukebox`/`launchSearch`/`showSongsForArtist` map to `nil` here: none
/// of FeedUI's outcome vocabulary carries venue identity, so those three
/// destinations (which need one) are resolved by ``TabRouter/handle(outcome:venueId:)``
/// instead — see `TabRouterTests`.
enum AppDestinationTests {
	struct `Navigational outcomes map to a destination` {
		@Test func `showSong maps to the song destination`() {
			let outcome = FeedActionOutcome.showSong(.song(songId: "42"))

			#expect(AppDestination(outcome: outcome) == .song(.song(songId: "42")))
		}

		@Test func `showVenue maps to the venue destination`() {
			let outcome = FeedActionOutcome.showVenue(venueId: "v1")

			#expect(AppDestination(outcome: outcome) == .venue(venueId: "v1"))
		}

		@Test func `showPerson maps to the person destination`() {
			let outcome = FeedActionOutcome.showPerson(personId: "p1")

			#expect(AppDestination(outcome: outcome) == .person(personId: "p1"))
		}

		@Test func `showTopUps maps to the topUps destination, keeping its context`() {
			let outcome = FeedActionOutcome.showTopUps(context: .noCredits)

			#expect(AppDestination(outcome: outcome) == .topUps(context: .noCredits))
		}
	}

	struct `Venue-context outcomes map to no destination, needing TabRouter's venueId-aware routing instead` {
		@Test func `showSongsForArtist produces no destination`() {
			#expect(AppDestination(outcome: .showSongsForArtist(artist: "Adele")) == nil)
		}

		@Test func `showJukebox produces no destination`() {
			#expect(AppDestination(outcome: .showJukebox(jukeboxId: 7)) == nil)
		}

		@Test func `launchSearch produces no destination`() {
			#expect(AppDestination(outcome: .launchSearch) == nil)
		}
	}

	struct `Non-navigational outcomes map to no destination` {
		@Test func `changeAtmosphere produces no destination`() {
			#expect(AppDestination(outcome: .changeAtmosphere(itemId: 1)) == nil)
		}

		@Test func `requestSong produces no destination`() {
			#expect(AppDestination(outcome: .requestSong(itemId: 1)) == nil)
		}

		@Test func `machineControl produces no destination`() {
			#expect(AppDestination(outcome: .machineControl(action: .skip, itemId: 1)) == nil)
		}

		@Test func `openURL produces no destination`() throws {
			let url = try #require(URL(string: "https://secretdj.com"))

			#expect(AppDestination(outcome: .openURL(.inApp(url))) == nil)
		}

		@Test func `openSocialApp produces no destination`() throws {
			let url = try #require(URL(string: "https://instagram.com/secretdj"))

			#expect(AppDestination(outcome: .openSocialApp(
				platform: .instagram,
				identifier: "secretdj",
				webFallbackURL: url,
			)) == nil)
		}

		@Test func `engagePromotion produces no destination`() {
			#expect(AppDestination(outcome: .engagePromotion(promotionId: 1)) == nil)
		}

		@Test func `hailRide produces no destination`() throws {
			let url = try #require(URL(string: "https://m.uber.com"))

			#expect(AppDestination(outcome: .hailRide(url: url)) == nil)
		}
	}
}
