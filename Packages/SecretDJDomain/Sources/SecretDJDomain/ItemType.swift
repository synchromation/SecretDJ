/// The server's item-type bitmask — used to pick an item's image bucket, to
/// classify a ``Section``'s contents, and as the `type` parameter on
/// like/unlike calls (LEGACY.md "Domain model and persistence"; the rewrite
/// deliberately keeps one type here rather than legacy's duplicate
/// `ItemType`/`LikeType` enums for the same bits).
public struct ItemType: OptionSet, Sendable, Hashable {
	public let rawValue: Int64

	public init(rawValue: Int64) {
		self.rawValue = rawValue
	}

	public static let album = ItemType(rawValue: 1)
	public static let song = ItemType(rawValue: 2)
	public static let artist = ItemType(rawValue: 8)
	public static let genre = ItemType(rawValue: 65536)
	public static let control = ItemType(rawValue: 262_144)
	public static let promotion = ItemType(rawValue: 1_048_576)
	public static let action = ItemType(rawValue: 16_777_216)
	public static let topUp = ItemType(rawValue: 33_554_432)
	public static let musicSelection = ItemType(rawValue: 67_108_864)
	public static let jukebox = ItemType(rawValue: 134_217_728)
	public static let news = ItemType(rawValue: 268_435_456)
	public static let venue = ItemType(rawValue: 536_870_912)
	public static let person = ItemType(rawValue: 1_073_741_824)
	public static let event = ItemType(rawValue: 2_147_483_648)
}

extension ItemType: Codable {
	public init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		try self.init(rawValue: container.decode(Int64.self))
	}

	public func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(rawValue)
	}
}
