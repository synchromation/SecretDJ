/// A browsable music collection within a venue (a genre, album, playlist,
/// ...) — not the physical player. The `jukeboxList`/`matrixJukeboxLarge`/
/// `hiddenJukeboxList` templates.
public struct Jukebox: Sendable, Hashable, Decodable {
	public let itemType: ItemType
	public let jukeboxId: Int
	public let textColour: String
	public let subtitle: String
	public let text: String
	public let sortIndex: Int
	public let action: Action?
	public let actions: [Action]
	/// Cover art metadata (`Image`), or `nil` when absent or malformed on
	/// the wire.
	public let image: ItemImage?

	public init(
		itemType: ItemType,
		jukeboxId: Int,
		textColour: String,
		subtitle: String,
		text: String,
		sortIndex: Int,
		action: Action?,
		actions: [Action],
		image: ItemImage? = nil,
	) {
		self.itemType = itemType
		self.jukeboxId = jukeboxId
		self.textColour = textColour
		self.subtitle = subtitle
		self.text = text
		self.sortIndex = sortIndex
		self.action = action
		self.actions = actions
		self.image = image
	}

	private enum CodingKeys: String, CodingKey {
		case text = "Text"
		case sortIndex = "Index"
		case data = "Data"
		case image = "Image"
	}

	private enum DataKeys: String, CodingKey {
		case itemType = "ItemTypeId"
		case jukeboxId = "Id"
		case textColour = "TextColour"
		case subtitle = "Description"
		case action = "Action"
		case actions = "Actions"
	}

	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
		sortIndex = try container.decodeIfPresent(Int.self, forKey: .sortIndex) ?? 0

		let data = try container.nestedContainer(keyedBy: DataKeys.self, forKey: .data)
		itemType = try ItemType(rawValue: data.decodeIfPresent(Int64.self, forKey: .itemType) ?? 0)
		jukeboxId = try data.decodeIfPresent(Int.self, forKey: .jukeboxId) ?? 0
		textColour = try data.decodeIfPresent(String.self, forKey: .textColour) ?? "#D3D3D3"
		subtitle = try data.decodeIfPresent(String.self, forKey: .subtitle) ?? ""
		action = try data.decodeIfPresent(Action.self, forKey: .action)
		actions = try data.decodeIfPresent([Action].self, forKey: .actions) ?? []
		// Malformed Image data (present but the wrong shape) never fails the
		// whole item — it just means no artwork for this row.
		image = try? container.decodeIfPresent(ItemImage.self, forKey: .image)
	}
}
