/// A person's self-declared gender (`GenderId` — LEGACY.md "Domain model and
/// persistence").
public enum Gender: Int, Sendable, Hashable, Codable {
	case unisex = 0
	case female = 1
	case male = 2
}

/// Profile header stats — the `Interactions` object LEGACY.md documents
/// living on a profile section's `Custom` payload, not on the ``Person``
/// item itself (`secretdjv3/Person.swift`'s header-stat accessors).
///
/// S1.3: not yet wired to `Section`'s decode — that needs a captured
/// `hiddenProfile`/`hiddenUserDetails` fixture to confirm exactly how
/// `Custom.Interactions` nests relative to the rest of a profile response.
public struct PersonInteractions: Sendable, Hashable, Decodable {
	public let placesVisited: Int
	public let songRequests: Int
	public let peopleWhoLikeUser: Int
	public let lastVenueName: String?
	public let lastZoneName: String?

	public init(
		placesVisited: Int,
		songRequests: Int,
		peopleWhoLikeUser: Int,
		lastVenueName: String?,
		lastZoneName: String?,
	) {
		self.placesVisited = placesVisited
		self.songRequests = songRequests
		self.peopleWhoLikeUser = peopleWhoLikeUser
		self.lastVenueName = lastVenueName
		self.lastZoneName = lastZoneName
	}

	private enum CodingKeys: String, CodingKey {
		case placesVisited = "PlacesVisited"
		case songRequests = "SongRequests"
		case peopleWhoLikeUser = "NumPeopleWhoLikeUser"
		case lastCheckin = "LastCheckin"
	}

	private enum LastCheckinKeys: String, CodingKey {
		case venueName = "VenueName"
		case zoneName = "ZoneName"
	}

	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		placesVisited = try container.decodeIfPresent(Int.self, forKey: .placesVisited) ?? 0
		songRequests = try container.decodeIfPresent(Int.self, forKey: .songRequests) ?? 0
		peopleWhoLikeUser = try container.decodeIfPresent(Int.self, forKey: .peopleWhoLikeUser) ?? 0

		if container.contains(.lastCheckin) {
			let lastCheckin = try container.nestedContainer(keyedBy: LastCheckinKeys.self, forKey: .lastCheckin)
			lastVenueName = try lastCheckin.decodeIfPresent(String.self, forKey: .venueName)
			lastZoneName = try lastCheckin.decodeIfPresent(String.self, forKey: .zoneName)
		} else {
			lastVenueName = nil
			lastZoneName = nil
		}
	}
}

/// A person — the `person`/`vip`/profile templates.
public struct Person: Sendable, Hashable, Decodable {
	public let personId: String
	public let screenName: String
	public let gender: Gender
	public let likeInfo: LikeInfo
	/// S1.3: not decoded here — legacy sources these from the parent
	/// `hiddenUserDetails` section's `Custom` payload, not this item's own
	/// `Data`; wiring that through needs a captured fixture.
	public let email: String?
	/// S1.3: see ``email``.
	public let firstName: String?
	/// S1.3: see ``email``.
	public let lastName: String?
	public let text: String
	public let sortIndex: Int
	public let action: Action?
	public let actions: [Action]
	/// Avatar metadata (`Image`), or `nil` when absent or malformed on the
	/// wire.
	public let image: ItemImage?

	public init(
		personId: String,
		screenName: String,
		gender: Gender,
		likeInfo: LikeInfo,
		email: String?,
		firstName: String?,
		lastName: String?,
		text: String,
		sortIndex: Int,
		action: Action?,
		actions: [Action],
		image: ItemImage? = nil,
	) {
		self.personId = personId
		self.screenName = screenName
		self.gender = gender
		self.likeInfo = likeInfo
		self.email = email
		self.firstName = firstName
		self.lastName = lastName
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
		case personId = "User"
		case screenName = "ScreenName"
		case gender = "GenderId"
		case likeInfo = "LikeInfo"
		case action = "Action"
		case actions = "Actions"
	}

	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
		sortIndex = try container.decodeIfPresent(Int.self, forKey: .sortIndex) ?? 0

		let data = try container.nestedContainer(keyedBy: DataKeys.self, forKey: .data)
		let personId = try data.decodeIfPresent(String.self, forKey: .personId) ?? ""
		let screenName = try data.decodeIfPresent(String.self, forKey: .screenName) ?? ""
		guard !personId.isEmpty, !screenName.isEmpty else {
			throw DecodingError.dataCorruptedError(
				forKey: .personId,
				in: data,
				debugDescription: "Person requires a non-empty personId and screenName",
			)
		}
		self.personId = personId
		self.screenName = screenName
		gender = try Gender(rawValue: data.decodeIfPresent(Int.self, forKey: .gender) ?? 0) ?? .unisex
		likeInfo = try data.decodeIfPresent(LikeInfo.self, forKey: .likeInfo) ?? LikeInfo(
			likedByYou: false,
			info: "",
		)
		email = nil
		firstName = nil
		lastName = nil
		action = try data.decodeIfPresent(Action.self, forKey: .action)
		actions = try data.decodeIfPresent([Action].self, forKey: .actions) ?? []
		// Malformed Image data (present but the wrong shape) never fails the
		// whole item — it just means no avatar for this row.
		image = try? container.decodeIfPresent(ItemImage.self, forKey: .image)
	}
}
