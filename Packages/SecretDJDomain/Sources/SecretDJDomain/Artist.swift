/// An artist row from search/browse — the `artist` template.
///
/// Unlike every other payload type, `Name`/`Artist`/`NumSongs` live at the
/// outer item level rather than nested under `Data` (`secretdjv3/Artist.swift`
/// reads `dictionary["NumSongs"]` etc. directly) — a genuine legacy
/// inconsistency this type preserves rather than "fixes" by guessing at a
/// uniform shape the wire format doesn't actually have.
public struct Artist: Sendable, Hashable, Decodable {
	public let name: String
	public let artist: String
	public let numSongs: Int
	public let sortIndex: Int
	public let action: Action?
	public let actions: [Action]
	/// Artwork metadata (`Image`), or `nil` when absent or malformed on the
	/// wire — legacy never actually resolved a real bucket for artist rows
	/// (`ItemImage.swift`'s `imageBaseURL()` has no `.artist` case), so this
	/// is carried mostly for completeness/forward-compatibility.
	public let image: ItemImage?

	/// Client-synthesized display text — the server's own item `Text` is not
	/// used for artist rows (`secretdjv3/Artist.swift`): just the artist
	/// name, with an ellipsis appended when they have more than one song.
	public var displayText: String {
		artist + (numSongs > 1 ? " ..." : "")
	}

	public init(
		name: String,
		artist: String,
		numSongs: Int,
		sortIndex: Int,
		action: Action?,
		actions: [Action],
		image: ItemImage? = nil,
	) {
		self.name = name
		self.artist = artist
		self.numSongs = numSongs
		self.sortIndex = sortIndex
		self.action = action
		self.actions = actions
		self.image = image
	}

	private enum CodingKeys: String, CodingKey {
		case name = "Name"
		case artist = "Artist"
		case numSongs = "NumSongs"
		case sortIndex = "Index"
		case data = "Data"
		case image = "Image"
	}

	private enum DataKeys: String, CodingKey {
		case action = "Action"
		case actions = "Actions"
	}

	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
		artist = try container.decodeIfPresent(String.self, forKey: .artist) ?? ""
		numSongs = try container.decodeIfPresent(Int.self, forKey: .numSongs) ?? 1
		sortIndex = try container.decodeIfPresent(Int.self, forKey: .sortIndex) ?? 0

		if container.contains(.data) {
			let data = try container.nestedContainer(keyedBy: DataKeys.self, forKey: .data)
			action = try data.decodeIfPresent(Action.self, forKey: .action)
			actions = try data.decodeIfPresent([Action].self, forKey: .actions) ?? []
		} else {
			action = nil
			actions = []
		}
		// Malformed Image data (present but the wrong shape) never fails the
		// whole item.
		image = try? container.decodeIfPresent(ItemImage.self, forKey: .image)
	}
}
