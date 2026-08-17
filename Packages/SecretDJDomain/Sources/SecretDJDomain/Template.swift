/// The server-chosen cell template that selects which concrete payload an
/// ``Item`` carries and, for hidden templates, that a section is a data
/// channel rather than a rendered list (LEGACY.md "Domain model and
/// persistence").
public enum Template: Sendable, Hashable {
	case venue
	case hiddenVenueDetails
	case award
	case checkIn
	case horizontalAward
	case matrixAwardSmall
	case matrixAwardMedium
	case song
	case matrixSongSmall
	case matrixSongMedium
	case horizontalSong
	case feedItem
	case hiddenUserDetails
	case hiddenProfile
	case vip
	case person
	case horizontalVIP
	case horizontalPerson
	case matrixPersonSmall
	case matrixPersonMedium
	case promotion
	case advert
	case matrixPromotionMedium
	case jukeboxList
	case matrixJukeboxLarge
	case hiddenJukeboxList
	case topUp
	case artist
	case hiddenExtraContentSong
	case matrixControlLarge
	case container
	/// A template code this build doesn't recognize, carrying the raw value
	/// for logging/metrics only. FeedUI's Domain→SectionKind mapping drops
	/// sections in this case (lazy-sections' unknown-kind rule).
	case unsupported(Int)

	/// Every named case paired with its documented server code
	/// (`secretdjv3/AppConfiguration.swift`'s `Template` enum).
	private static let knownCodes: [(Template, Int)] = [
		(.venue, 100), (.hiddenVenueDetails, 101), (.award, 102), (.checkIn, 103), (.horizontalAward, 104),
		(.matrixAwardSmall, 105), (.matrixAwardMedium, 106), (.song, 200), (.matrixSongSmall, 201),
		(.matrixSongMedium, 202), (.horizontalSong, 203), (.feedItem, 300), (.hiddenUserDetails, 301),
		(.hiddenProfile, 302), (.vip, 303), (.person, 304), (.horizontalVIP, 305), (.horizontalPerson, 306),
		(.matrixPersonSmall, 307), (.matrixPersonMedium, 308), (.promotion, 400), (.advert, 401),
		(.matrixPromotionMedium, 402), (.jukeboxList, 600), (.matrixJukeboxLarge, 601), (.hiddenJukeboxList, 602),
		(.topUp, 700), (.artist, 800), (.hiddenExtraContentSong, 900), (.matrixControlLarge, 1000),
		(.container, 9999),
	]

	private static let byRawValue: [Int: Template] = Dictionary(
		uniqueKeysWithValues: knownCodes.map { ($0.1, $0.0) },
	)

	private static let byCase: [Template: Int] = Dictionary(uniqueKeysWithValues: knownCodes)

	/// Maps a server template code to its case, never failing: a code this
	/// build doesn't recognize becomes ``unsupported(_:)`` carrying that code.
	public init(rawValue: Int) {
		self = Self.byRawValue[rawValue] ?? .unsupported(rawValue)
	}

	/// The raw template code the server sent (or, for ``unsupported(_:)``,
	/// the code that was preserved unrecognized).
	public var rawValue: Int {
		if case .unsupported(let rawValue) = self {
			return rawValue
		}
		// Every non-`unsupported` case is seeded into `byCase` above, so this
		// table lookup always succeeds.
		return Self.byCase[self] ?? 0
	}
}

extension Template: Codable {
	public init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		try self.init(rawValue: container.decode(Int.self))
	}

	public func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(rawValue)
	}
}
