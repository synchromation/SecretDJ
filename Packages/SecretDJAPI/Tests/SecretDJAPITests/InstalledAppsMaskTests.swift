import Testing

@testable import SecretDJAPI

enum InstalledAppsMaskTests {
	struct `Wire bit values` {
		/// `secretdjv3/URLSchemeHandler.swift:21-24`.
		@Test func `facebook is bit 1`() {
			#expect(InstalledAppsMask.facebook.rawValue == 1)
		}

		@Test func `twitter is bit 2`() {
			#expect(InstalledAppsMask.twitter.rawValue == 2)
		}

		@Test func `uber is bit 4`() {
			#expect(InstalledAppsMask.uber.rawValue == 4)
		}

		@Test func `instagram is bit 8`() {
			#expect(InstalledAppsMask.instagram.rawValue == 8)
		}
	}

	struct Composition {
		@Test func `combines independently settable flags into one mask`() {
			let mask: InstalledAppsMask = [.twitter, .instagram]

			#expect(mask.rawValue == 10)
		}

		@Test func `an empty mask has a raw value of zero`() {
			let mask: InstalledAppsMask = []

			#expect(mask.rawValue == 0)
		}
	}
}
