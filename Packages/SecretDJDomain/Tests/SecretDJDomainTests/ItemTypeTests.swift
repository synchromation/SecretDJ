import Foundation
import Testing

@testable import SecretDJDomain

enum ItemTypeTests {
	struct `Mapping known flags` {
		static let rawValues: [Int64] = [
			1, 2, 8, 65536, 262_144, 1_048_576, 16_777_216, 33_554_432, 67_108_864, 134_217_728, 268_435_456,
			536_870_912, 1_073_741_824, 2_147_483_648,
		]

		static let flags: [ItemType] = [
			.album, .song, .artist, .genre, .control, .promotion, .action, .topUp, .musicSelection, .jukebox,
			.news, .venue, .person, .event,
		]

		@Test(arguments: zip(rawValues, flags))
		func `each named flag carries its documented raw bit`(rawValue: Int64, flag: ItemType) {
			#expect(flag.rawValue == rawValue)
		}
	}

	struct `Bitmask composition` {
		@Test func `a single flag contains only itself`() {
			#expect(ItemType.song.contains(.song))
			#expect(!ItemType.song.contains(.venue))
		}

		@Test func `unioning two flags contains both but not a third`() {
			let combined: ItemType = [.song, .venue]

			#expect(combined.contains(.song))
			#expect(combined.contains(.venue))
			#expect(!combined.contains(.person))
		}

		@Test func `inserting a flag composes it into the set`() {
			var mask: ItemType = [.song]

			mask.insert(.person)

			#expect(mask == [.song, .person])
		}

		@Test func `the empty set contains no known flag`() {
			let empty: ItemType = []

			#expect(!empty.contains(.song))
			#expect(empty.rawValue == 0)
		}
	}

	struct Coding {
		@Test func `a single flag round-trips through JSON as its raw value`() throws {
			let encoded = try JSONEncoder().encode(ItemType.venue)

			#expect(String(data: encoded, encoding: .utf8) == "536870912")
			#expect(try JSONDecoder().decode(ItemType.self, from: encoded) == .venue)
		}

		@Test func `an unrecognised bit is preserved rather than rejected`() throws {
			let data = Data("4".utf8) // no named flag uses raw value 4

			let decoded = try JSONDecoder().decode(ItemType.self, from: data)

			#expect(decoded.rawValue == 4)
			#expect(!decoded.contains(.song))
		}
	}
}
