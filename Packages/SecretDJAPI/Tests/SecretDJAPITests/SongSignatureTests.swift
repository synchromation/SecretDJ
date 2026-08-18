import Foundation
import Testing

@testable import SecretDJAPI

enum SongSignatureTests {
	struct `Fixed-date signature` {
		/// `date`/`calendar` are injected, never `Date()` (tdd/ios-architecture
		/// determinism rule). Expected signature computed independently:
		/// `"140875_" + sha1("140875" + "73" + "9cx63a21cqdc782ed6b05ww124447f8e15c8")`
		/// — day 74 of 2026 (a non-leap year) minus one is 73, matching the
		/// legacy `day - 1` adjustment
		/// (`secretdjv3/SongSigGenerator.swift`'s "Adjusted to match PHP behavior").
		@Test func `matches an independently computed known-answer signature`() throws {
			var calendar = Calendar(identifier: .gregorian)
			calendar.timeZone = .gmt
			let date = try #require(
				calendar.date(from: DateComponents(year: 2026, month: 3, day: 15, hour: 12)),
			)

			let signature = SongSignature.signedSongId(songId: "140875", date: date, calendar: calendar)

			#expect(signature == "140875_89f726e83e43befd234c602cc1fbacbf593eb695")
		}

		@Test func `is prefixed with the plain song id, unsigned`() throws {
			var calendar = Calendar(identifier: .gregorian)
			calendar.timeZone = .gmt
			let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 0)))

			let signature = SongSignature.signedSongId(songId: "42", date: date, calendar: calendar)

			#expect(signature.hasPrefix("42_"))
		}

		@Test func `a different song id changes the signature`() throws {
			var calendar = Calendar(identifier: .gregorian)
			calendar.timeZone = .gmt
			let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 9)))

			let first = SongSignature.signedSongId(songId: "1", date: date, calendar: calendar)
			let second = SongSignature.signedSongId(songId: "2", date: date, calendar: calendar)

			#expect(first != second)
		}
	}
}
