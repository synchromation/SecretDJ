/// Identifies a promotion's well-known negative id as a specific social
/// platform link, used to reorder a venue's social-links section
/// (LEGACY.md business rule 10; legacy's `PromotionSocialVPR`).
public enum SocialPlatform: Int, Sendable, Hashable, Codable {
	case facebook = -1
	case twitter = -2
	case website = -3
	case instagram = -4
}

/// A promotional item (advert, matrix promotion tile) — the
/// `promotion`/`advert`/`matrixPromotionMedium` templates.
public struct Promotion: Sendable, Hashable, Decodable {
	public let promotionId: Int
	/// The promotion's destination, or `nil` when it has none. A `nil` URL
	/// means engaging with this promotion pings the server's `promote`
	/// endpoint for tracking instead of navigating anywhere — dispatch lives
	/// in FeedUI (S3.3), not here.
	public let url: String?
	/// Whether to open ``url`` in the system browser rather than in-app.
	public let externalBrowser: Bool
	public let height: Int
	public let text: String
	public let sortIndex: Int
	public let action: Action?
	public let actions: [Action]
	/// Promo image metadata (`Image`), or `nil` when absent or malformed on
	/// the wire.
	public let image: ItemImage?

	/// The social platform this promotion represents, when ``promotionId``
	/// is one of the server's well-known negative ids.
	public var socialPlatform: SocialPlatform? {
		SocialPlatform(rawValue: promotionId)
	}

	public init(
		promotionId: Int,
		url: String?,
		externalBrowser: Bool,
		height: Int,
		text: String,
		sortIndex: Int,
		action: Action?,
		actions: [Action],
		image: ItemImage? = nil,
	) {
		self.promotionId = promotionId
		self.url = url
		self.externalBrowser = externalBrowser
		self.height = height
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
		case promotionId = "Id"
		case url = "Url"
		case externalBrowser = "ExternalBrowser"
		case height = "Height"
		case action = "Action"
		case actions = "Actions"
	}

	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
		sortIndex = try container.decodeIfPresent(Int.self, forKey: .sortIndex) ?? 0

		let data = try container.nestedContainer(keyedBy: DataKeys.self, forKey: .data)
		promotionId = try data.decodeIfPresent(Int.self, forKey: .promotionId) ?? 0
		url = try data.decodeIfPresent(String.self, forKey: .url)?.nonEmptyOrNil
		externalBrowser = try data.decodeIfPresent(Bool.self, forKey: .externalBrowser) ?? false
		height = try data.decodeIfPresent(Int.self, forKey: .height) ?? 0
		action = try data.decodeIfPresent(Action.self, forKey: .action)
		actions = try data.decodeIfPresent([Action].self, forKey: .actions) ?? []
		// Malformed Image data (present but the wrong shape) never fails the
		// whole item — it just means no artwork for this row.
		image = try? container.decodeIfPresent(ItemImage.self, forKey: .image)
	}
}
