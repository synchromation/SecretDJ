import Testing

@testable import FeedUI

import SecretDJDomain

enum FeedChangeDetectorTests {
	struct `Establishing a feed` {
		@Test func `a fresh detector has no tracked hash`() {
			let detector = FeedChangeDetector(policy: .surfaceChange)

			#expect(detector.hash == nil)
		}

		@Test func `an initial load establishes the tracked hash`() {
			var detector = FeedChangeDetector(policy: .surfaceChange)

			detector.establish(FeedHash(rawValue: "v1"))

			#expect(detector.hash == FeedHash(rawValue: "v1"))
		}

		@Test func `a refresh re-establishes cleanly even when the hash changed`() {
			var detector = FeedChangeDetector(policy: .surfaceChange)
			detector.establish(FeedHash(rawValue: "v1"))

			detector.establish(FeedHash(rawValue: "v2"))

			#expect(detector.hash == FeedHash(rawValue: "v2"))
		}

		@Test func `a refresh with the same hash re-establishes cleanly`() {
			var detector = FeedChangeDetector(policy: .reloadInPlace)
			detector.establish(FeedHash(rawValue: "v1"))

			detector.establish(FeedHash(rawValue: "v1"))

			#expect(detector.hash == FeedHash(rawValue: "v1"))
		}
	}

	struct `Paginating under the surfaceChange policy (consumer)` {
		@Test func `a same-hash page reports unchanged`() {
			var detector = FeedChangeDetector(policy: .surfaceChange)
			detector.establish(FeedHash(rawValue: "v1"))

			let outcome = detector.page(FeedHash(rawValue: "v1"))

			#expect(outcome == .unchanged)
		}

		@Test func `a hash change mid-pagination reports jukeboxChanged`() {
			var detector = FeedChangeDetector(policy: .surfaceChange)
			detector.establish(FeedHash(rawValue: "v1"))

			let outcome = detector.page(FeedHash(rawValue: "v2"))

			#expect(outcome == .jukeboxChanged)
		}

		@Test func `the tracked hash is untouched after a jukeboxChanged page`() {
			var detector = FeedChangeDetector(policy: .surfaceChange)
			detector.establish(FeedHash(rawValue: "v1"))

			_ = detector.page(FeedHash(rawValue: "v2"))

			#expect(detector.hash == FeedHash(rawValue: "v1"))
		}
	}

	struct `Paginating under the reloadInPlace policy (kiosk digest)` {
		@Test func `a same-hash page reports unchanged`() {
			var detector = FeedChangeDetector(policy: .reloadInPlace)
			detector.establish(FeedHash(rawValue: "v1"))

			let outcome = detector.page(FeedHash(rawValue: "v1"))

			#expect(outcome == .unchanged)
		}

		@Test func `a hash change mid-pagination is absorbed and reports unchanged`() {
			var detector = FeedChangeDetector(policy: .reloadInPlace)
			detector.establish(FeedHash(rawValue: "v1"))

			let outcome = detector.page(FeedHash(rawValue: "v2"))

			#expect(outcome == .unchanged)
		}

		@Test func `absorbing a hash change adopts the new hash`() {
			var detector = FeedChangeDetector(policy: .reloadInPlace)
			detector.establish(FeedHash(rawValue: "v1"))

			_ = detector.page(FeedHash(rawValue: "v2"))

			#expect(detector.hash == FeedHash(rawValue: "v2"))
		}

		@Test func `a later page compares against the newly adopted hash`() {
			var detector = FeedChangeDetector(policy: .reloadInPlace)
			detector.establish(FeedHash(rawValue: "v1"))
			_ = detector.page(FeedHash(rawValue: "v2"))

			let outcome = detector.page(FeedHash(rawValue: "v2"))

			#expect(outcome == .unchanged)
		}
	}

	struct `Paginating before any load` {
		@Test func `a page with no tracked hash establishes it instead of reporting a change`() {
			var detector = FeedChangeDetector(policy: .surfaceChange)

			let outcome = detector.page(FeedHash(rawValue: "v1"))

			#expect(outcome == .unchanged)
			#expect(detector.hash == FeedHash(rawValue: "v1"))
		}
	}
}
