import Foundation
import Testing

@testable import SecretDJDomain

enum ItemImageTests {
	struct `Decoding the wire's Image object` {
		/// The real `Image` payload from `PlayHistory.json`'s first song —
		/// `ItemTypeId` 2 is the song bucket, not the item's own type field.
		@Test func `reads every documented field`() throws {
			let json = Data(
				"""
				{"ItemTypeId": 2, "Resolutions": 5503, "Size": 4483, "Uri": "s102000/s102698.jpg"}
				""".utf8,
			)

			let image = try JSONDecoder().decode(ItemImage.self, from: json)

			#expect(image.itemType == .song)
			#expect(image.uri == "s102000/s102698.jpg")
			#expect(image.size == 4483)
			#expect(image.resolutions == [
				.small, .resolution120, .large, .resolution160, .resolution195,
				.resolution250, .resolution260, .resolution400, .resolution480, .resolution640,
			])
		}

		@Test func `a missing ItemTypeId decodes to an empty type mask`() throws {
			let json = Data(#"{"Uri": "x.jpg"}"#.utf8)

			let image = try JSONDecoder().decode(ItemImage.self, from: json)

			#expect(image.itemType.isEmpty)
		}

		@Test func `a missing Uri decodes to an empty string`() throws {
			let json = Data(#"{"ItemTypeId": 2}"#.utf8)

			let image = try JSONDecoder().decode(ItemImage.self, from: json)

			#expect(image.uri.isEmpty)
		}

		@Test func `a missing Resolutions defaults to legacy's 0x7F fallback`() throws {
			// `secretdjv3/ItemImage.swift:84`: `dictionary["Resolutions"] as? Int
			// ?? 0x7F` — every bucket up to 260x260, never the three largest.
			let json = Data(#"{"ItemTypeId": 2, "Uri": "x.jpg"}"#.utf8)

			let image = try JSONDecoder().decode(ItemImage.self, from: json)

			#expect(image.resolutions == [
				.small, .resolution120, .large, .resolution160, .resolution195,
				.resolution250, .resolution260,
			])
			#expect(!image.resolutions.contains(.resolution640))
		}
	}

	struct `Resolving a URL for a size class` {
		@Test func `size1x1 resolves to the largest bucket when every bucket is available`() throws {
			// `VenueFeed.json`'s "The Lamb" venue image.
			let json = Data(
				#"{"ItemTypeId": 536870912, "Resolutions": 5503, "Size": 5278, "Uri": "v-00003960-a53e3169.jpg"}"#
					.utf8,
			)
			let image = try JSONDecoder().decode(ItemImage.self, from: json)

			#expect(
				image.url(for: .size1x1) ==
					URL(string: "https://secretdj.s3.amazonaws.com/venues/640x640/v-00003960-a53e3169.jpg?5278"),
			)
		}

		@Test func `size4x4 resolves to the large bucket`() throws {
			// `MusicSelection.json`'s "Recently Added" jukebox image.
			let json = Data(
				#"{"ItemTypeId": 134217728, "Resolutions": 5503, "Size": 2, "Uri": "j-1879048193.jpg"}"#.utf8,
			)
			let image = try JSONDecoder().decode(ItemImage.self, from: json)

			#expect(
				image.url(for: .size4x4) ==
					URL(string: "https://secretdj.s3.amazonaws.com/jukeboxes/large/j-1879048193.jpg?2"),
			)
		}

		@Test func `size3x3 resolves to the 195x195 bucket`() throws {
			let json = Data(
				#"{"ItemTypeId": 134217728, "Resolutions": 5503, "Size": 2, "Uri": "j-1879048193.jpg"}"#.utf8,
			)
			let image = try JSONDecoder().decode(ItemImage.self, from: json)

			#expect(
				image.url(for: .size3x3) ==
					URL(string: "https://secretdj.s3.amazonaws.com/jukeboxes/195x195/j-1879048193.jpg?2"),
			)
		}

		@Test func `size2x2 resolves to the 260x260 bucket`() throws {
			let json = Data(
				#"{"ItemTypeId" : 1073741824, "Resolutions" : 5503, "Size" : 3345, "Uri" : "u-01256912-5442fc6c.jpg"}"#
					.utf8,
			)
			let image = try JSONDecoder().decode(ItemImage.self, from: json)

			#expect(
				image.url(for: .size2x2) ==
					URL(string: "https://secretdj.s3.amazonaws.com/useravatars/260x260/u-01256912-5442fc6c.jpg?3345"),
			)
		}

		/// A song whose cover is an album image (`Image.ItemTypeId` 1, not 2)
		/// — `PlayHistory.json`'s "Confines" item. The base bucket follows the
		/// image's own carried type, not the owning item's.
		@Test func `an album-bucketed image uses the album covers path`() throws {
			let json = Data(
				#"{"ItemTypeId" : 1, "Resolutions" : 1407, "Size" : 4195, "Uri" : "a303085.jpg"}"#.utf8,
			)
			let image = try JSONDecoder().decode(ItemImage.self, from: json)

			#expect(
				image.url(for: .size2x2) ==
					URL(string: "https://secretdj.s3.amazonaws.com/albumcovers/260x260/a303085.jpg?4195"),
			)
		}
	}

	struct `Falling back down the resolution ladder` {
		/// `PlayHistory.json`'s "Confines" album image: `Resolutions` 1407 has
		/// every bucket except 640x640 — requesting size1x1 (640x640) should
		/// fall back one rung to 480x480.
		@Test func `size1x1 falls back to 480x480 when 640x640 is unavailable`() throws {
			let json = Data(
				#"{"ItemTypeId" : 1, "Resolutions" : 1407, "Size" : 4195, "Uri" : "a303085.jpg"}"#.utf8,
			)
			let image = try JSONDecoder().decode(ItemImage.self, from: json)

			#expect(
				image.url(for: .size1x1) ==
					URL(string: "https://secretdj.s3.amazonaws.com/albumcovers/480x480/a303085.jpg?4195"),
			)
		}

		/// `VenueFeed.json`'s "tini" person image: `Resolutions` 127 stops at
		/// 260x260 — requesting size1x1 (640x640) should fall all the way
		/// back to 260x260, skipping 480x480 and 400x400 in between.
		@Test func `size1x1 falls back multiple rungs to the highest available bucket`() throws {
			let json = Data(
				#"{"ItemTypeId" : 1073741824, "Resolutions" : 127, "Size" : 3936, "Uri" : "u-00032170-f39ddfcd.jpg"}"#
					.utf8,
			)
			let image = try JSONDecoder().decode(ItemImage.self, from: json)

			#expect(
				image.url(for: .size1x1) ==
					URL(string: "https://secretdj.s3.amazonaws.com/useravatars/260x260/u-00032170-f39ddfcd.jpg?3936"),
			)
		}

		@Test func `no bucket at or below the request is available returns nil`() throws {
			let json = Data(#"{"ItemTypeId": 2, "Resolutions": 0, "Size": 1, "Uri": "x.jpg"}"#.utf8)
			let image = try JSONDecoder().decode(ItemImage.self, from: json)

			#expect(image.url(for: .size1x1) == nil)
		}
	}

	struct `Item types with no known image bucket` {
		@Test func `an artist-typed image has no known bucket and resolves to nil`() throws {
			// `secretdjv3/ItemImage.swift`'s `imageBaseURL()` switch has no
			// `.artist` case — legacy artist rows never carried real artwork.
			let json = Data(#"{"ItemTypeId": 8, "Resolutions": 5503, "Size": 1, "Uri": "x.jpg"}"#.utf8)
			let image = try JSONDecoder().decode(ItemImage.self, from: json)

			#expect(image.url(for: .size1x1) == nil)
		}

		@Test func `an empty Uri resolves to nil regardless of available buckets`() throws {
			let json = Data(#"{"ItemTypeId": 2, "Resolutions": 5503, "Size": 1, "Uri": ""}"#.utf8)
			let image = try JSONDecoder().decode(ItemImage.self, from: json)

			#expect(image.url(for: .size1x1) == nil)
		}
	}
}
