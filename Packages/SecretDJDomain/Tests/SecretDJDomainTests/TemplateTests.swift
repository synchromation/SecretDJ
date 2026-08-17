import Foundation
import Testing

@testable import SecretDJDomain

enum TemplateTests {
	struct `Mapping known codes` {
		static let rawValues = [
			100, 101, 102, 103, 104, 105, 106, 200, 201, 202, 203, 300, 301, 302, 303, 304, 305, 306, 307, 308, 400,
			401, 402, 600, 601, 602, 700, 800, 900, 1000, 9999,
		]

		static let templates: [Template] = [
			.venue, .hiddenVenueDetails, .award, .checkIn, .horizontalAward, .matrixAwardSmall, .matrixAwardMedium,
			.song, .matrixSongSmall, .matrixSongMedium, .horizontalSong, .feedItem, .hiddenUserDetails,
			.hiddenProfile, .vip, .person, .horizontalVIP, .horizontalPerson, .matrixPersonSmall,
			.matrixPersonMedium, .promotion, .advert, .matrixPromotionMedium, .jukeboxList, .matrixJukeboxLarge,
			.hiddenJukeboxList, .topUp, .artist, .hiddenExtraContentSong, .matrixControlLarge, .container,
		]

		@Test(arguments: zip(rawValues, templates))
		func `raw value initializes the matching case`(rawValue: Int, template: Template) {
			#expect(Template(rawValue: rawValue) == template)
		}

		@Test(arguments: zip(rawValues, templates))
		func `rawValue round-trips back to the original code`(rawValue: Int, template: Template) {
			#expect(template.rawValue == rawValue)
		}
	}

	struct `Unknown codes` {
		@Test func `an unrecognised code decodes to unsupported carrying the raw value`() {
			#expect(Template(rawValue: 12345) == .unsupported(12345))
		}

		@Test func `unsupported's rawValue returns the original unrecognised code`() {
			#expect(Template.unsupported(777).rawValue == 777)
		}

		@Test func `the retired news template code is unsupported`() {
			// The News tab is deliberately not ported (PLAN.md scope exclusions);
			// its template code simply falls into the unsupported bucket.
			#expect(Template(rawValue: 500) == .unsupported(500))
		}

		@Test func `two unsupported values with different codes are not equal`() {
			#expect(Template.unsupported(1) != Template.unsupported(2))
		}

		@Test func `two unsupported values with the same code are equal`() {
			#expect(Template.unsupported(1) == Template.unsupported(1))
		}
	}

	struct Coding {
		@Test func `a known case encodes to its raw int and decodes back`() throws {
			let encoded = try JSONEncoder().encode(Template.song)

			#expect(String(data: encoded, encoding: .utf8) == "200")
			#expect(try JSONDecoder().decode(Template.self, from: encoded) == .song)
		}

		@Test func `an unrecognised int decodes to unsupported`() throws {
			let data = Data("54321".utf8)

			let decoded = try JSONDecoder().decode(Template.self, from: data)

			#expect(decoded == .unsupported(54321))
		}

		@Test func `unsupported encodes back to its raw int`() throws {
			let encoded = try JSONEncoder().encode(Template.unsupported(54321))

			#expect(String(data: encoded, encoding: .utf8) == "54321")
		}
	}
}
