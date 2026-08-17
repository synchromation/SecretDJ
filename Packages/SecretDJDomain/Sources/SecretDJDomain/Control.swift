/// A colored mood/atmosphere tile — the `matrixControlLarge` template. The
/// item this tile represents (a genre, playlist, ...) and the minutes to
/// hold it for are carried on ``action`` (``ActionKind/jukeboxChangeAtmosphere``'s
/// `itemId`/`value`), not duplicated here.
public struct Control: Sendable, Hashable, Decodable {
	public let fgColour: String
	public let bgColour: String
	public let text: String
	public let sortIndex: Int
	public let action: Action?
	public let actions: [Action]

	public init(
		fgColour: String,
		bgColour: String,
		text: String,
		sortIndex: Int,
		action: Action?,
		actions: [Action],
	) {
		self.fgColour = fgColour
		self.bgColour = bgColour
		self.text = text
		self.sortIndex = sortIndex
		self.action = action
		self.actions = actions
	}

	private enum CodingKeys: String, CodingKey {
		case text = "Text"
		case sortIndex = "Index"
		case data = "Data"
	}

	private enum DataKeys: String, CodingKey {
		case fgColour = "FgCol"
		case bgColour = "BgCol"
		case action = "Action"
		case actions = "Actions"
	}

	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
		sortIndex = try container.decodeIfPresent(Int.self, forKey: .sortIndex) ?? 0

		let data = try container.nestedContainer(keyedBy: DataKeys.self, forKey: .data)
		fgColour = try data.decodeIfPresent(String.self, forKey: .fgColour) ?? "#FFFFFF"
		// The legacy default is the malformed literal "#00000" (five digits,
		// `Control.swift:24`) — deliberately not carried forward.
		bgColour = try data.decodeIfPresent(String.self, forKey: .bgColour) ?? "#000000"
		action = try data.decodeIfPresent(Action.self, forKey: .action)
		actions = try data.decodeIfPresent([Action].self, forKey: .actions) ?? []
	}
}
