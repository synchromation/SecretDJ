import Foundation
import Testing

@testable import SecretDJDomain

/// `secretdjv3/RichToastView.swift`'s `populateViews(_:)`/`setupVip(_:)`
/// contract — see ``RichToastData``'s own doc comment for the LIVE-CAPTURE
/// citation: no fixture in this repo or the legacy checkout's own test
/// bundle carries a real `Data` payload shaped like this, so every JSON
/// literal below is synthesized straight from the dictionary-subscript
/// reads in `RichToastView.swift`, not a captured response.
enum RichToastDataTests {
	struct `Decoding a well-formed rich toast` {
		@Test func `reads Title, Headline, and BodyText`() throws {
			let json = Data(
				"""
				{
				  "Title": "Reward!",
				  "Headline": "You earned DJ status",
				  "BodyText": "Thanks for checking in.\\n\\nEnjoy your reward."
				}
				""".utf8,
			)

			let data = try JSONDecoder().decode(RichToastData.self, from: json)

			#expect(data.title == "Reward!")
			#expect(data.headline == "You earned DJ status")
			#expect(data.bodyText == "Thanks for checking in.\n\nEnjoy your reward.")
		}

		@Test func `decodes a Vip object as a Person`() throws {
			let json = Data(
				"""
				{
				  "Title": "Reward!",
				  "Vip": {
				    "Text": "oliverk\\nis DJ of Bench",
				    "Data": {"User": "00000087_feae54c9", "ScreenName": "oliverk", "GenderId": 2},
				    "Image": {"Uri": "u-00000087-feae54c9.jpg", "Size": 3176, "ItemTypeId": 1073741824, "Resolutions": 127}
				  }
				}
				""".utf8,
			)

			let data = try JSONDecoder().decode(RichToastData.self, from: json)

			#expect(data.vip?.personId == "00000087_feae54c9")
			#expect(data.vip?.screenName == "oliverk")
			#expect(data.vip?.gender == .male)
			#expect(data.vip?.text == "oliverk\nis DJ of Bench")
			#expect(data.vip?.image != nil)
		}

		@Test func `missing fields default to empty strings`() throws {
			let data = try JSONDecoder().decode(RichToastData.self, from: Data("{}".utf8))

			#expect(data.title.isEmpty)
			#expect(data.headline.isEmpty)
			#expect(data.bodyText.isEmpty)
			#expect(data.vip == nil)
		}

		@Test func `a missing Vip decodes to no VIP row`() throws {
			let json = Data(#"{"Headline": "Nice one"}"#.utf8)

			let data = try JSONDecoder().decode(RichToastData.self, from: json)

			#expect(data.vip == nil)
		}

		/// `setupVip(_:)`'s `Data` check is independent of its `Image`/`Text`
		/// reads, but no captured response has ever shown a `Vip` with `Image`/
		/// `Text` and no `Data` — this port collapses that combination to no
		/// VIP row at all (``RichToastData/vip``'s own doc comment).
		@Test func `a Vip with malformed Data never fails the whole toast`() throws {
			let json = Data(
				"""
				{"Vip": {"Text": "oliverk", "Data": {"ScreenName": "oliverk"}}}
				""".utf8,
			)

			let data = try JSONDecoder().decode(RichToastData.self, from: json)

			#expect(data.vip == nil)
			#expect(data.title.isEmpty)
		}
	}
}
