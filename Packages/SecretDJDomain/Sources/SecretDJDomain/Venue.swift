/// Server-reported venue capabilities (`Properties` bitmask on
/// `Data` — LEGACY.md "Domain model and persistence").
public struct VenueProperties: OptionSet, Sendable, Hashable {
	public let rawValue: Int

	public init(rawValue: Int) {
		self.rawValue = rawValue
	}

	public static let reportsPlayHistory = VenueProperties(rawValue: 0x1)
	public static let hasJukebox = VenueProperties(rawValue: 0x2)
}

extension VenueProperties: Codable {
	public init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		try self.init(rawValue: container.decode(Int.self))
	}

	public func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(rawValue)
	}
}

/// A pub/venue — the `venue`/`checkIn`/award templates (award templates have
/// no dedicated type in this domain: LEGACY.md notes legacy renders them as
/// "venue-shaped items with a badge image", and this rewrite preserves that
/// — they decode as ``Venue`` too).
public struct Venue: Sendable, Hashable, Decodable {
	public let venueId: String
	public let name: String
	public let address: String
	public let telephone: String
	public let lat: Double
	public let lng: Double
	public let zoneName: String
	public let promotionURL: String?
	public let likeInfo: LikeInfo
	public let properties: VenueProperties
	/// Session state: whether the current user has checked in here.
	public let checkedIn: Bool
	/// Whether this venue grants machine-control affordances (change mood,
	/// skip, blacklist) to the current user.
	public let hasMachineControl: Bool
	public let text: String
	public let sortIndex: Int
	public let action: Action?
	public let actions: [Action]
	/// Badge/venue photo metadata (`Image`), or `nil` when absent or
	/// malformed on the wire.
	public let image: ItemImage?

	public init(
		venueId: String,
		name: String,
		address: String,
		telephone: String,
		lat: Double,
		lng: Double,
		zoneName: String,
		promotionURL: String?,
		likeInfo: LikeInfo,
		properties: VenueProperties,
		checkedIn: Bool,
		hasMachineControl: Bool,
		text: String,
		sortIndex: Int,
		action: Action?,
		actions: [Action],
		image: ItemImage? = nil,
	) {
		self.venueId = venueId
		self.name = name
		self.address = address
		self.telephone = telephone
		self.lat = lat
		self.lng = lng
		self.zoneName = zoneName
		self.promotionURL = promotionURL
		self.likeInfo = likeInfo
		self.properties = properties
		self.checkedIn = checkedIn
		self.hasMachineControl = hasMachineControl
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
		case venueId = "Venue"
		case name = "VenueName"
		case address = "VenueAddress"
		case telephone = "Telephone"
		case lat = "Lat"
		case lng = "Lng"
		case zoneName = "ZoneName"
		case promotionURL = "VenuePromotionUrl"
		case likeInfo = "LikeInfo"
		case properties = "Properties"
		case checkedIn = "CheckedIn"
		case machineControl = "MachineControl"
		case action = "Action"
		case actions = "Actions"
	}

	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
		sortIndex = try container.decodeIfPresent(Int.self, forKey: .sortIndex) ?? 0

		let data = try container.nestedContainer(keyedBy: DataKeys.self, forKey: .data)
		let venueId = try data.decodeIfPresent(String.self, forKey: .venueId) ?? ""
		guard !venueId.isEmpty else {
			throw DecodingError.dataCorruptedError(
				forKey: .venueId,
				in: data,
				debugDescription: "Venue requires a non-empty venue id",
			)
		}
		self.venueId = venueId
		name = try data.decodeIfPresent(String.self, forKey: .name) ?? ""
		address = try data.decodeIfPresent(String.self, forKey: .address) ?? ""
		telephone = try data.decodeIfPresent(String.self, forKey: .telephone) ?? ""
		lat = try data.decodeIfPresent(Double.self, forKey: .lat) ?? 0
		lng = try data.decodeIfPresent(Double.self, forKey: .lng) ?? 0
		zoneName = try data.decodeIfPresent(String.self, forKey: .zoneName) ?? ""
		promotionURL = try data.decodeIfPresent(String.self, forKey: .promotionURL)?.nonEmptyOrNil
		likeInfo = try data.decodeIfPresent(LikeInfo.self, forKey: .likeInfo) ?? LikeInfo(
			likedByYou: false,
			info: "",
		)
		properties = try VenueProperties(rawValue: data.decodeIfPresent(Int.self, forKey: .properties) ?? 0)
		checkedIn = try data.decodeIfPresent(Bool.self, forKey: .checkedIn) ?? false
		// The wire sends this as a JSON bool, int, or numeric string
		// depending on the payload — genuinely inconsistent.
		hasMachineControl = try data.decodeBoolOrIntOrStringIfPresent(forKey: .machineControl) ?? false
		action = try data.decodeIfPresent(Action.self, forKey: .action)
		actions = try data.decodeIfPresent([Action].self, forKey: .actions) ?? []
		// Malformed Image data (present but the wrong shape) never fails the
		// whole item — it just means no artwork for this row.
		image = try? container.decodeIfPresent(ItemImage.self, forKey: .image)
	}
}
