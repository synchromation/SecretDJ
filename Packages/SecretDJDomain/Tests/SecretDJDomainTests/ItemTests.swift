import Testing

@testable import SecretDJDomain

struct ItemTests {
	static let song = Song(
		songId: "1",
		title: "Title",
		artist: "Artist",
		previewURL: nil,
		likeInfo: LikeInfo(likedByYou: false, info: ""),
		text: "",
		sortIndex: 0,
		action: nil,
		actions: [],
	)

	@Test func `two items wrapping equal payloads of the same case are equal`() {
		#expect(Item.song(Self.song) == Item.song(Self.song))
	}

	@Test func `items wrapping different cases are not equal`() {
		let venue = Venue(
			venueId: "1",
			name: "",
			address: "",
			telephone: "",
			lat: 0,
			lng: 0,
			zoneName: "",
			promotionURL: nil,
			likeInfo: LikeInfo(likedByYou: false, info: ""),
			properties: [],
			checkedIn: false,
			hasMachineControl: false,
			text: "",
			sortIndex: 0,
			action: nil,
			actions: [],
		)

		#expect(Item.song(Self.song) != Item.venue(venue))
	}

	@Test func `unsupported items carry the offending template for logging`() {
		#expect(Item.unsupported(.container) == Item.unsupported(.container))
		#expect(Item.unsupported(.container) != Item.unsupported(.matrixControlLarge))
	}
}
