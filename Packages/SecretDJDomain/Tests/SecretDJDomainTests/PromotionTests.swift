import Foundation
import Testing

@testable import SecretDJDomain

struct PromotionTests {
	@Test func `reads every documented field`() throws {
		let json = Data(
			"""
			{"Text": "50% off", "Index": 0, "Data": {
			  "Id": 12, "Url": "https://instagram.com/secretdj", "ExternalBrowser": true, "Height": 120,
			  "Action": {"Id": 500}, "Actions": []
			}}
			""".utf8,
		)

		let promotion = try JSONDecoder().decode(Promotion.self, from: json)

		#expect(promotion.promotionId == 12)
		#expect(promotion.url == "https://instagram.com/secretdj")
		#expect(promotion.externalBrowser)
		#expect(promotion.height == 120)
		#expect(promotion.text == "50% off")
		#expect(promotion.action?.kind == .gotoURL)
	}

	@Test func `an empty URL decodes to no URL`() throws {
		// A URL-less promotion is engaged by pinging the server's `promote`
		// endpoint instead of navigating — dispatch lives in FeedUI (S3.3),
		// not here; the domain model just needs `url` to be a real optional.
		let json = Data(#"{"Data": {"Id": 1, "Url": ""}}"#.utf8)

		let promotion = try JSONDecoder().decode(Promotion.self, from: json)

		#expect(promotion.url == nil)
	}

	struct SocialPlatformTests {
		static let rawValues = [-1, -2, -3, -4]
		static let platforms: [SocialPlatform] = [.facebook, .twitter, .website, .instagram]

		@Test(arguments: zip(rawValues, platforms))
		func `raw value initializes the matching case`(rawValue: Int, platform: SocialPlatform) {
			#expect(SocialPlatform(rawValue: rawValue) == platform)
		}

		@Test func `a promotion's well-known negative id identifies its social platform`() throws {
			let json = Data(#"{"Data": {"Id": -4}}"#.utf8)

			let promotion = try JSONDecoder().decode(Promotion.self, from: json)

			#expect(promotion.socialPlatform == .instagram)
		}

		@Test func `an ordinary positive id has no social platform`() throws {
			let json = Data(#"{"Data": {"Id": 12}}"#.utf8)

			let promotion = try JSONDecoder().decode(Promotion.self, from: json)

			#expect(promotion.socialPlatform == nil)
		}
	}
}
