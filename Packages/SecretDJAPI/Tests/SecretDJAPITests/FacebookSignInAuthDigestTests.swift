import Foundation
import Testing

@testable import SecretDJAPI

enum FacebookSignInAuthDigestTests {
	struct `Fixed-date digest` {
		/// `date`/`calendar` are injected, never `Date()` (tdd/ios-architecture
		/// determinism rule). Expected digest computed independently:
		/// `sha1("10154089931213890" + "73" + "a23167ehxwxzf9Fd4")` — day 74
		/// of 2026 (a non-leap year) minus one is 73, matching the legacy
		/// `dayInYear - 1` adjustment (`secretdjv3/LoginAPIAccess.swift:313-321`).
		@Test func `matches an independently computed known-answer digest`() throws {
			var calendar = Calendar(identifier: .gregorian)
			calendar.timeZone = .gmt
			let date = try #require(
				calendar.date(from: DateComponents(year: 2026, month: 3, day: 15, hour: 12)),
			)

			let digest = FacebookSignInAuthDigest.compute(
				facebookUserId: "10154089931213890",
				date: date,
				calendar: calendar,
			)

			#expect(digest == "ff0561b5213f171a49ac04dcdef50edee0a5bd12")
		}

		@Test func `is deterministic for the same instant and calendar`() throws {
			var calendar = Calendar(identifier: .gregorian)
			calendar.timeZone = .gmt
			let date = try #require(
				calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 9)),
			)

			let first = FacebookSignInAuthDigest.compute(facebookUserId: "fb-user-1", date: date, calendar: calendar)
			let second = FacebookSignInAuthDigest.compute(facebookUserId: "fb-user-1", date: date, calendar: calendar)

			#expect(first == second)
		}

		@Test func `a different facebookUserId changes the digest`() throws {
			var calendar = Calendar(identifier: .gregorian)
			calendar.timeZone = .gmt
			let date = try #require(
				calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 9)),
			)

			let first = FacebookSignInAuthDigest.compute(facebookUserId: "fb-user-1", date: date, calendar: calendar)
			let second = FacebookSignInAuthDigest.compute(facebookUserId: "fb-user-2", date: date, calendar: calendar)

			#expect(first != second)
		}

		/// A different app's salt (Apple's) must never collide with
		/// Facebook's, even for the same id/date — the two endpoints are
		/// deliberately not interchangeable.
		@Test func `uses a different salt than AppleSignInAuthDigest`() throws {
			var calendar = Calendar(identifier: .gregorian)
			calendar.timeZone = .gmt
			let date = try #require(
				calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 9)),
			)

			let facebookDigest = FacebookSignInAuthDigest.compute(
				facebookUserId: "shared-id",
				date: date,
				calendar: calendar,
			)
			let appleDigest = AppleSignInAuthDigest.compute(appleUserId: "shared-id", date: date, calendar: calendar)

			#expect(facebookDigest != appleDigest)
		}
	}
}
