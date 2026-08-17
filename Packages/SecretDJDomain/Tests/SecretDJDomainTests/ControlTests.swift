import Foundation
import Testing

@testable import SecretDJDomain

struct ControlTests {
	@Test func `reads the mood tile's colours and action`() throws {
		let json = Data(
			"""
			{"Text": "Chilled", "Index": 0, "Data": {
			  "FgCol": "#000000", "BgCol": "#FFCC00", "Action": {"Id": 400, "ItemId": 3, "Value": "30"},
			  "Actions": []
			}}
			""".utf8,
		)

		let control = try JSONDecoder().decode(Control.self, from: json)

		#expect(control.fgColour == "#000000")
		#expect(control.bgColour == "#FFCC00")
		#expect(control.text == "Chilled")
		#expect(control.action?.kind == .jukeboxChangeAtmosphere)
		#expect(control.action?.itemId == 3)
		#expect(control.action?.value == "30")
	}

	@Test func `missing colours fall back to white foreground and black background`() throws {
		// The legacy default for BgCol is the malformed literal "#00000" (five
		// digits) — deliberately not carried forward; see TopUp's VendorId note
		// for the sibling decision on not reproducing legacy decode bugs.
		let json = Data("{\"Data\": {}}".utf8)

		let control = try JSONDecoder().decode(Control.self, from: json)

		#expect(control.fgColour == "#FFFFFF")
		#expect(control.bgColour == "#000000")
	}
}
