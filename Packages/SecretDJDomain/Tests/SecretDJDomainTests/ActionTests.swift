import Foundation
import Testing

@testable import SecretDJDomain

enum ActionTests {
	struct `Decoding a well-formed action` {
		@Test func `reads every documented field`() throws {
			let json = Data(
				"""
				{"Id": 403, "ItemId": 42, "ItemTypeId": 2, "Value": "5", "Url": "https://example.com", "Button": 100}
				""".utf8,
			)

			let action = try JSONDecoder().decode(Action.self, from: json)

			#expect(action.kind == .jukeboxRequestSong)
			#expect(action.itemId == 42)
			#expect(action.itemTypeId == 2)
			#expect(action.value == "5")
			#expect(action.url == "https://example.com")
			#expect(action.button == .insertCoin)
		}

		@Test func `omitted optional fields decode to nil and an unsupported button`() throws {
			let json = Data(#"{"Id": 500}"#.utf8)

			let action = try JSONDecoder().decode(Action.self, from: json)

			#expect(action.kind == .gotoURL)
			#expect(action.itemId == nil)
			#expect(action.itemTypeId == nil)
			#expect(action.value == nil)
			#expect(action.url == nil)
			#expect(action.button == .unsupported(0))
		}

		@Test func `an unrecognised Id decodes to an unsupported kind carrying the raw code`() throws {
			let json = Data(#"{"Id": 999}"#.utf8)

			let action = try JSONDecoder().decode(Action.self, from: json)

			#expect(action.kind == .unsupported(999))
		}
	}

	struct `ItemId decodes leniently across wire representations` {
		/// `secretdjv3` sends `ItemId` as a JSON string for
		/// `jukeboxRequestSong` actions — the song id, e.g. `"152380"` in
		/// `MusicSelection.json`.
		@Test func `a string ItemId decodes to its integer value`() throws {
			let json = Data(#"{"Id": 403, "ItemId": "152380"}"#.utf8)

			let action = try JSONDecoder().decode(Action.self, from: json)

			#expect(action.itemId == 152_380)
		}

		/// `secretdjv3` sends `ItemId` as a JSON number for
		/// `jukeboxChangeAtmosphere` actions — a mood/control id, e.g. `679`
		/// in `StyleInfo-Short.json`.
		@Test func `an int ItemId decodes to its integer value`() throws {
			let json = Data(#"{"Id": 400, "ItemId": 679}"#.utf8)

			let action = try JSONDecoder().decode(Action.self, from: json)

			#expect(action.itemId == 679)
		}
	}

	struct `Malformed actions` {
		@Test func `a missing Id fails to decode`() {
			let json = Data(#"{"ItemId": 1}"#.utf8)

			#expect(throws: (any Error).self) {
				try JSONDecoder().decode(Action.self, from: json)
			}
		}
	}

	struct ActionKindTests {
		static let rawValues = [1, 100, 101, 200, 300, 400, 401, 402, 403, 500]
		static let kinds: [ActionKind] = [
			.showTopup, .launchUberApp, .launchUberSignup, .launchSearch, .jukeboxGotoItem,
			.jukeboxChangeAtmosphere, .jukeboxSkipSong, .jukeboxBlacklistSong, .jukeboxRequestSong, .gotoURL,
		]

		@Test(arguments: zip(rawValues, kinds))
		func `raw value initializes the matching case`(rawValue: Int, kind: ActionKind) {
			#expect(ActionKind(rawValue: rawValue) == kind)
		}

		@Test(arguments: zip(rawValues, kinds))
		func `rawValue round-trips back to the original code`(rawValue: Int, kind: ActionKind) {
			#expect(kind.rawValue == rawValue)
		}

		@Test func `an unrecognised code is unsupported`() {
			#expect(ActionKind(rawValue: 42) == .unsupported(42))
		}
	}

	struct ActionButtonTests {
		static let rawValues = [100, 200, 300]
		static let buttons: [ActionButton] = [.insertCoin, .hailTaxi, .launchSearch]

		@Test(arguments: zip(rawValues, buttons))
		func `raw value initializes the matching case`(rawValue: Int, button: ActionButton) {
			#expect(ActionButton(rawValue: rawValue) == button)
		}

		@Test(arguments: zip(rawValues, buttons))
		func `rawValue round-trips back to the original code`(rawValue: Int, button: ActionButton) {
			#expect(button.rawValue == rawValue)
		}

		@Test func `an unrecognised code is unsupported`() {
			#expect(ActionButton(rawValue: 7) == .unsupported(7))
		}
	}
}
