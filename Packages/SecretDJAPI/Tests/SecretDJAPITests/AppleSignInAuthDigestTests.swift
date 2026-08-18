import Foundation
import Testing

@testable import SecretDJAPI

enum AppleSignInAuthDigestTests {
	struct `Fixed-date digest` {
		/// `date`/`calendar` are injected, never `Date()` (tdd/ios-architecture
		/// determinism rule). Expected digest computed independently:
		/// `sha1("00001234_a1b2c3d4" + "73" + "a199eb60aad211ea")` — day 74
		/// of 2026 (a non-leap year) minus one is 73, matching the legacy
		/// `dayInYear - 1` adjustment (`secretdjv3/LoginAPIAccess.swift:313-321`).
		@Test func `matches an independently computed known-answer digest`() throws {
			var calendar = Calendar(identifier: .gregorian)
			calendar.timeZone = Calendar.utcTimeZone
			let date = try #require(
				calendar.date(from: DateComponents(year: 2026, month: 3, day: 15, hour: 12)),
			)

			let digest = AppleSignInAuthDigest.compute(appleUserId: "00001234_a1b2c3d4", date: date, calendar: calendar)

			#expect(digest == "eae8553337dc56bfe2bffa3d39a9a5c5c3126282")
		}

		@Test func `is deterministic for the same instant and calendar`() throws {
			var calendar = Calendar(identifier: .gregorian)
			calendar.timeZone = Calendar.utcTimeZone
			let date = try #require(
				calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 9)),
			)

			let first = AppleSignInAuthDigest.compute(appleUserId: "user-1", date: date, calendar: calendar)
			let second = AppleSignInAuthDigest.compute(appleUserId: "user-1", date: date, calendar: calendar)

			#expect(first == second)
		}

		@Test func `a different appleUserId changes the digest`() throws {
			var calendar = Calendar(identifier: .gregorian)
			calendar.timeZone = Calendar.utcTimeZone
			let date = try #require(
				calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 9)),
			)

			let first = AppleSignInAuthDigest.compute(appleUserId: "user-1", date: date, calendar: calendar)
			let second = AppleSignInAuthDigest.compute(appleUserId: "user-2", date: date, calendar: calendar)

			#expect(first != second)
		}
	}

	/// LEGACY.md flags the legacy `DateFormatter`'s "DDD" pattern as
	/// timezone-sensitive: it resolves in the formatter's current time
	/// zone, not UTC, so the same instant can land on different calendar
	/// days near midnight depending on the device's zone. This rewrite
	/// ports that fragility deliberately (D7) rather than silently fixing
	/// it, so the same instant interpreted in two time zones must produce
	/// two different — but each individually correct — digests.
	struct `Timezone sensitivity (ported, not fixed, per D7)` {
		@Test func `the same instant near midnight can fall on different local days in different zones`() throws {
			let instant = try #require(
				DateFormatter.iso8601UTC.date(from: "2026-03-14T23:30:00Z"),
			)

			var utcCalendar = Calendar(identifier: .gregorian)
			utcCalendar.timeZone = Calendar.utcTimeZone
			var aheadCalendar = Calendar(identifier: .gregorian)
			aheadCalendar.timeZone = try #require(TimeZone(secondsFromGMT: 3600))

			let utcDigest = AppleSignInAuthDigest.compute(
				appleUserId: "00001234_a1b2c3d4",
				date: instant,
				calendar: utcCalendar,
			)
			let aheadDigest = AppleSignInAuthDigest.compute(
				appleUserId: "00001234_a1b2c3d4",
				date: instant,
				calendar: aheadCalendar,
			)

			#expect(utcDigest == "b09df5508701e68586f6983fe59f97736db2aaa4")
			#expect(aheadDigest == "eae8553337dc56bfe2bffa3d39a9a5c5c3126282")
			#expect(utcDigest != aheadDigest)
		}
	}
}

extension Calendar {
	fileprivate static let utcTimeZone = TimeZone.gmt
}

extension DateFormatter {
	fileprivate static let iso8601UTC: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
		formatter.timeZone = Calendar.utcTimeZone
		formatter.locale = Locale(identifier: "en_US_POSIX")
		return formatter
	}()
}
