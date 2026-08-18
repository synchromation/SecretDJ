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

	struct `Image decoding` {
		/// `Image` is a sibling of `Text`/`Index`/`Data`, matching every other
		/// payload type — no live fixture carries a promotion `Image` (none
		/// of this package's fixtures include a promotion row), so this shape
		/// follows `secretdjv3/ItemImage.swift`'s documented wire contract
		/// rather than a captured payload. `event`/`promotion` share the
		/// `promotions/` bucket in legacy's `imageBaseURL()`.
		@Test func `decodes a present Image object into artwork`() throws {
			let json = Data(
				"""
				{"Data": {"Id": 1},
				 "Image": {"ItemTypeId": 1048576, "Resolutions": 5503, "Size": 9, "Uri": "p-1.jpg"}}
				""".utf8,
			)

			let promotion = try JSONDecoder().decode(Promotion.self, from: json)

			#expect(promotion.image?.url(for: .size1x1) ==
				URL(string: "https://secretdj.s3.amazonaws.com/promotions/640x640/p-1.jpg?9"))
		}

		@Test func `a missing Image decodes to no artwork`() throws {
			let json = Data(#"{"Data": {"Id": 1}}"#.utf8)

			let promotion = try JSONDecoder().decode(Promotion.self, from: json)

			#expect(promotion.image == nil)
		}

		@Test func `a malformed Image never fails the whole item`() throws {
			let json = Data(#"{"Data": {"Id": 1}, "Image": "not an object"}"#.utf8)

			let promotion = try JSONDecoder().decode(Promotion.self, from: json)

			#expect(promotion.image == nil)
			#expect(promotion.promotionId == 1)
		}
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
