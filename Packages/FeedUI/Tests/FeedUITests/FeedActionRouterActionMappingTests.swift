import Testing

@testable import FeedUI

import Foundation
import SecretDJDomain

/// Coverage for the generic `Action` → `FeedActionOutcome` mapping, entered
/// via nav-bar action buttons (`outcome(forBarButton:)`) — the same mapping
/// an item-level action override reuses (see `FeedActionRouterTests`, which
/// this file was split from to keep it under the project's file-length
/// limit; fixtures `FakeInstalledApps`/`makeAction` live there).
enum FeedActionRouterActionMappingTests {
	struct `Action routing` {
		@Test func `showTopup shows the insert-coin top-up screen`() {
			let router = FeedActionRouter(installedApps: FakeInstalledApps())

			#expect(router.outcome(forBarButton: makeAction(kind: .showTopup)) == .showTopUps(context: .insertCoin))
		}

		@Test func `launchUberApp with a URL hails a ride`() throws {
			let router = FeedActionRouter(installedApps: FakeInstalledApps())
			let action = makeAction(kind: .launchUberApp, url: "https://uber.com/ride")

			#expect(try router
				.outcome(forBarButton: action) == .hailRide(url: #require(URL(string: "https://uber.com/ride"))))
		}

		@Test func `launchUberApp with no URL produces no outcome`() {
			let router = FeedActionRouter(installedApps: FakeInstalledApps())

			#expect(router.outcome(forBarButton: makeAction(kind: .launchUberApp)) == nil)
		}

		@Test func `launchUberSignup with a URL hails a ride`() throws {
			let router = FeedActionRouter(installedApps: FakeInstalledApps())
			let action = makeAction(kind: .launchUberSignup, url: "https://uber.com/signup")

			#expect(try router
				.outcome(forBarButton: action) == .hailRide(url: #require(URL(string: "https://uber.com/signup"))))
		}

		@Test func `launchSearch launches search`() {
			let router = FeedActionRouter(installedApps: FakeInstalledApps())

			#expect(router.outcome(forBarButton: makeAction(kind: .launchSearch)) == .launchSearch)
		}

		@Test func `jukeboxChangeAtmosphere with an item id changes atmosphere`() {
			let router = FeedActionRouter(installedApps: FakeInstalledApps())
			let action = makeAction(kind: .jukeboxChangeAtmosphere, itemId: 12)

			#expect(router.outcome(forBarButton: action) == .changeAtmosphere(itemId: 12))
		}

		@Test func `jukeboxChangeAtmosphere with no item id produces no outcome`() {
			let router = FeedActionRouter(installedApps: FakeInstalledApps())

			#expect(router.outcome(forBarButton: makeAction(kind: .jukeboxChangeAtmosphere)) == nil)
		}

		@Test func `jukeboxSkipSong requests a skip machine control`() {
			let router = FeedActionRouter(installedApps: FakeInstalledApps())
			let action = makeAction(kind: .jukeboxSkipSong, itemId: 42)

			#expect(router.outcome(forBarButton: action) == .machineControl(action: .skip, itemId: 42))
		}

		@Test func `the never-play jukebox action requests a never-play machine control`() {
			let router = FeedActionRouter(installedApps: FakeInstalledApps())
			let action = makeAction(kind: .jukeboxBlacklistSong, itemId: 42)

			#expect(router.outcome(forBarButton: action) == .machineControl(action: .neverPlay, itemId: 42))
		}

		@Test func `jukeboxRequestSong requests that song`() {
			let router = FeedActionRouter(installedApps: FakeInstalledApps())
			let action = makeAction(kind: .jukeboxRequestSong, itemId: 42)

			#expect(router.outcome(forBarButton: action) == .requestSong(itemId: 42))
		}

		@Test func `gotoURL opens in-app`() throws {
			let router = FeedActionRouter(installedApps: FakeInstalledApps())
			let action = makeAction(kind: .gotoURL, url: "https://secretdj.com/news/1")

			#expect(try router
				.outcome(forBarButton: action) ==
				.openURL(.inApp(#require(URL(string: "https://secretdj.com/news/1")))))
		}

		@Test func `gotoURL with no URL produces no outcome`() {
			let router = FeedActionRouter(installedApps: FakeInstalledApps())

			#expect(router.outcome(forBarButton: makeAction(kind: .gotoURL)) == nil)
		}

		@Test func `a bare jukeboxGotoItem action produces no outcome without item context`() {
			let router = FeedActionRouter(installedApps: FakeInstalledApps())

			#expect(router.outcome(forBarButton: makeAction(kind: .jukeboxGotoItem)) == nil)
		}

		@Test func `an unsupported action code produces no outcome`() {
			let router = FeedActionRouter(installedApps: FakeInstalledApps())

			#expect(router.outcome(forBarButton: makeAction(kind: .unsupported(9999))) == nil)
		}

		@Test func `insert-coin, hail-taxi, and search bar buttons follow the same action-kind mapping`() throws {
			let router = FeedActionRouter(installedApps: FakeInstalledApps())

			#expect(
				router.outcome(forBarButton: makeAction(kind: .showTopup, button: .insertCoin))
					== .showTopUps(context: .insertCoin),
			)
			#expect(
				try router.outcome(forBarButton: makeAction(
					kind: .launchUberApp,
					url: "https://uber.com/ride",
					button: .hailTaxi,
				))
					== .hailRide(url: #require(URL(string: "https://uber.com/ride"))),
			)
			#expect(
				router.outcome(forBarButton: makeAction(kind: .launchSearch, button: .launchSearch)) == .launchSearch,
			)
		}
	}
}
