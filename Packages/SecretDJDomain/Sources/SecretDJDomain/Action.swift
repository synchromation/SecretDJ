/// What tapping a server-driven item or bar button does — the `ActionType`
/// codes LEGACY.md catalogs (`secretdjv3/Action.swift`).
public enum ActionKind: Sendable, Hashable {
	case showTopup
	case launchUberApp
	case launchUberSignup
	case launchSearch
	case jukeboxGotoItem
	case jukeboxChangeAtmosphere
	case jukeboxSkipSong
	case jukeboxBlacklistSong
	case jukeboxRequestSong
	case gotoURL
	/// A code this build doesn't recognize, carrying the raw value for
	/// logging/metrics only.
	case unsupported(Int)

	private static let knownCodes: [(ActionKind, Int)] = [
		(.showTopup, 1), (.launchUberApp, 100), (.launchUberSignup, 101), (.launchSearch, 200),
		(.jukeboxGotoItem, 300), (.jukeboxChangeAtmosphere, 400), (.jukeboxSkipSong, 401),
		(.jukeboxBlacklistSong, 402), (.jukeboxRequestSong, 403), (.gotoURL, 500),
	]

	private static let byRawValue: [Int: ActionKind] = Dictionary(
		uniqueKeysWithValues: knownCodes.map { ($0.1, $0.0) },
	)

	private static let byCase: [ActionKind: Int] = Dictionary(uniqueKeysWithValues: knownCodes)

	/// Maps a server action code to its case, never failing: a code this
	/// build doesn't recognize becomes ``unsupported(_:)`` carrying that code.
	public init(rawValue: Int) {
		self = Self.byRawValue[rawValue] ?? .unsupported(rawValue)
	}

	/// The raw action code the server sent (or, for ``unsupported(_:)``, the
	/// code that was preserved unrecognized).
	public var rawValue: Int {
		if case .unsupported(let rawValue) = self {
			return rawValue
		}
		return Self.byCase[self] ?? 0
	}
}

extension ActionKind: Codable {
	public init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		try self.init(rawValue: container.decode(Int.self))
	}

	public func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(rawValue)
	}
}

/// Which nav-bar icon a server-driven action button renders as
/// (`secretdjv3/Action.swift`'s `ActionButton`).
public enum ActionButton: Sendable, Hashable {
	case insertCoin
	case hailTaxi
	case launchSearch
	/// A code this build doesn't recognize, carrying the raw value for
	/// logging/metrics only.
	case unsupported(Int)

	private static let knownCodes: [(ActionButton, Int)] = [
		(.insertCoin, 100), (.hailTaxi, 200), (.launchSearch, 300),
	]

	private static let byRawValue: [Int: ActionButton] = Dictionary(
		uniqueKeysWithValues: knownCodes.map { ($0.1, $0.0) },
	)

	private static let byCase: [ActionButton: Int] = Dictionary(uniqueKeysWithValues: knownCodes)

	/// Maps a server button code to its case, never failing: a code this
	/// build doesn't recognize (including the legacy "no button" sentinel,
	/// `0`) becomes ``unsupported(_:)`` carrying that code.
	public init(rawValue: Int) {
		self = Self.byRawValue[rawValue] ?? .unsupported(rawValue)
	}

	/// The raw button code the server sent (or, for ``unsupported(_:)``, the
	/// code that was preserved unrecognized).
	public var rawValue: Int {
		if case .unsupported(let rawValue) = self {
			return rawValue
		}
		return Self.byCase[self] ?? 0
	}
}

extension ActionButton: Codable {
	public init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		try self.init(rawValue: container.decode(Int.self))
	}

	public func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(rawValue)
	}
}

/// A single server-driven action attached to an item or bar button.
public struct Action: Sendable, Hashable, Decodable {
	public let kind: ActionKind
	/// The id of the item this action targets, when relevant to ``kind``.
	public let itemId: Int?
	/// The ``ItemType`` raw value of the item this action targets, when
	/// relevant to ``kind``.
	public let itemTypeId: Int?
	/// Free-form payload — e.g. minutes to hold a mood for
	/// ``ActionKind/jukeboxChangeAtmosphere``.
	public let value: String?
	public let url: String?
	/// Which toolbar icon renders this action, when it appears as a bar
	/// button rather than an item tap.
	public let button: ActionButton

	public init(
		kind: ActionKind,
		itemId: Int?,
		itemTypeId: Int?,
		value: String?,
		url: String?,
		button: ActionButton,
	) {
		self.kind = kind
		self.itemId = itemId
		self.itemTypeId = itemTypeId
		self.value = value
		self.url = url
		self.button = button
	}

	private enum CodingKeys: String, CodingKey {
		case kind = "Id"
		case itemId = "ItemId"
		case itemTypeId = "ItemTypeId"
		case value = "Value"
		case url = "Url"
		case button = "Button"
	}

	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		// The server always identifies an action by its `Id`; without one
		// there's nothing to act on, so this mirrors the legacy failable init.
		kind = try ActionKind(rawValue: container.decode(Int.self, forKey: .kind))
		itemId = try container.decodeIfPresent(Int.self, forKey: .itemId)
		itemTypeId = try container.decodeIfPresent(Int.self, forKey: .itemTypeId)
		value = try container.decodeIfPresent(String.self, forKey: .value)
		url = try container.decodeIfPresent(String.self, forKey: .url)
		button = try ActionButton(rawValue: container.decodeIfPresent(Int.self, forKey: .button) ?? 0)
	}
}
