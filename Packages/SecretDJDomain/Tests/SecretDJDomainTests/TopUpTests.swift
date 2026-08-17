import Foundation
import Testing

@testable import SecretDJDomain

enum TopUpTests {
	struct `Decoding a well-formed top-up` {
		@Test func `reads every documented field`() throws {
			let json = Data(
				"""
				{"Text": "10 credits", "Index": 0, "Data": {
				  "SKU": "com.secretdj.credits10", "VendorId": 2, "Name": "10 Credits",
				  "Description": "Ten jukebox credits", "Price": "1.99", "DisplayPrice": "£1.99",
				  "CurrencyCode": "GBP", "Url": "https://example.com/topup", "NumCredits": 10,
				  "Action": {"Id": 1}, "Actions": []
				}}
				""".utf8,
			)

			let topUp = try JSONDecoder().decode(TopUp.self, from: json)

			#expect(topUp.sku == "com.secretdj.credits10")
			#expect(topUp.vendor == .appleAppStore)
			#expect(topUp.name == "10 Credits")
			#expect(topUp.productDescription == "Ten jukebox credits")
			#expect(topUp.price == "1.99")
			#expect(topUp.displayPrice == "£1.99")
			#expect(topUp.currencyCode == "GBP")
			#expect(topUp.url == "https://example.com/topup")
			#expect(topUp.numCredits == 10)
			#expect(topUp.text == "10 credits")
			#expect(topUp.action?.kind == .showTopup)
		}

		@Test func `an empty URL decodes to no URL`() throws {
			let json = Data(#"{"Data": {"SKU": "sku", "Url": ""}}"#.utf8)

			let topUp = try JSONDecoder().decode(TopUp.self, from: json)

			#expect(topUp.url == nil)
		}
	}

	struct `Identity validation` {
		@Test func `a missing SKU fails to decode`() {
			let json = Data(#"{"Data": {"Name": "10 Credits"}}"#.utf8)

			#expect(throws: (any Error).self) {
				try JSONDecoder().decode(TopUp.self, from: json)
			}
		}

		@Test func `an empty SKU fails to decode`() {
			let json = Data(#"{"Data": {"SKU": ""}}"#.utf8)

			#expect(throws: (any Error).self) {
				try JSONDecoder().decode(TopUp.self, from: json)
			}
		}
	}

	struct VendorTests {
		static let rawValues = [0, 1, 2]
		static let vendors: [Vendor] = [.unknown, .googlePlayStore, .appleAppStore]

		@Test(arguments: zip(rawValues, vendors))
		func `raw value initializes the matching case`(rawValue: Int, vendor: Vendor) {
			#expect(Vendor(rawValue: rawValue) == vendor)
		}

		@Test func `an unrecognised VendorId decodes to unknown rather than crashing`() throws {
			// Deliberately does NOT reproduce the legacy `as? Vendor` cast bug
			// (TopUp.swift:35, LEGACY.md "Tech debt in this dimension") that made
			// every vendor read back as `.unknown` even for real Apple purchases.
			let json = Data(#"{"Data": {"SKU": "sku", "VendorId": 99}}"#.utf8)

			let topUp = try JSONDecoder().decode(TopUp.self, from: json)

			#expect(topUp.vendor == .unknown)
		}
	}
}
