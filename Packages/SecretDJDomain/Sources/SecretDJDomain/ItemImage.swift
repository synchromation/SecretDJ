import Foundation

/// The resolution buckets a decoded image asset may be available at
/// (`Resolutions` — a bitmask on the wire's `Image` object;
/// `secretdjv3/ItemImage.swift`'s `ImageResolution` OptionSet). Raw values
/// match the wire exactly, including the gaps (128, 512, 2048, ...) legacy
/// itself never assigned.
public struct ImageResolution: OptionSet, Sendable, Hashable {
	public let rawValue: Int

	public init(rawValue: Int) {
		self.rawValue = rawValue
	}

	public static let small = ImageResolution(rawValue: 1)
	public static let resolution120 = ImageResolution(rawValue: 2)
	public static let large = ImageResolution(rawValue: 4)
	public static let resolution160 = ImageResolution(rawValue: 8)
	public static let resolution195 = ImageResolution(rawValue: 16)
	public static let resolution250 = ImageResolution(rawValue: 32)
	public static let resolution260 = ImageResolution(rawValue: 64)
	public static let resolution400 = ImageResolution(rawValue: 256)
	public static let resolution480 = ImageResolution(rawValue: 1024)
	public static let resolution640 = ImageResolution(rawValue: 4096)
}

extension ImageResolution: Codable {
	public init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		try self.init(rawValue: container.decode(Int.self))
	}

	public func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(rawValue)
	}
}

/// A cell's requested artwork bucket (`secretdjv3/ItemImage.swift`'s
/// `ImageSizeClass`), largest to smallest. FeedUI picks one per cell layout;
/// ``ItemImage/url(for:)`` resolves it to a concrete URL.
public enum ImageSizeClass: Sendable, Hashable {
	case size1x1
	case size2x2
	case size3x3
	case size4x4
}

/// Decoded artwork/avatar metadata for an item — the wire's `Image` object,
/// a sibling of `Text`/`Index`/`Data` on the raw item dictionary, not nested
/// inside `Data` (LEGACY.md "Model vocabulary"; `secretdjv3/ItemImage.swift`).
/// Every payload type that carries one decodes it as an optional `image`
/// property; absent or malformed `Image` data decodes to `nil` rather than
/// failing the item (the tolerant-decode discipline).
public struct ItemImage: Sendable, Hashable, Decodable {
	let itemType: ItemType
	let uri: String
	let size: Int
	let resolutions: ImageResolution

	public init(itemType: ItemType, uri: String, size: Int, resolutions: ImageResolution) {
		self.itemType = itemType
		self.uri = uri
		self.size = size
		self.resolutions = resolutions
	}

	private enum CodingKeys: String, CodingKey {
		case itemType = "ItemTypeId"
		case uri = "Uri"
		case size = "Size"
		case resolutions = "Resolutions"
	}

	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		itemType = try ItemType(rawValue: container.decodeIfPresent(Int64.self, forKey: .itemType) ?? 0)
		uri = try container.decodeIfPresent(String.self, forKey: .uri) ?? ""
		size = try container.decodeIfPresent(Int.self, forKey: .size) ?? 0
		// Legacy defaults to 0x7F (every bucket up to 260x260) when the server
		// omits `Resolutions` (`ItemImage.swift:84`).
		resolutions = try ImageResolution(rawValue: container.decodeIfPresent(Int.self, forKey: .resolutions) ?? 0x7F)
	}

	/// This image's S3 bucket path, keyed by its own carried ``ItemType`` —
	/// not the owning item's type; a song's cover can be an `.album` bucket
	/// rather than `.song` (`PlayHistory.json`'s `a303085.jpg` entry). `nil`
	/// for item types the server never assigns a real bucket to, matching
	/// legacy's `"unknown"` fallback (`imageBaseURL()`) — e.g. artist rows
	/// never carried real artwork.
	private var baseURLString: String? {
		switch itemType {
		case .album: "https://secretdj.s3.amazonaws.com/albumcovers/"
		case .song: "https://secretdj.s3.amazonaws.com/songcovers/"
		case .news: "https://secretdj.s3.amazonaws.com/newsimages/"
		case .venue: "https://secretdj.s3.amazonaws.com/venues/"
		case .person: "https://secretdj.s3.amazonaws.com/useravatars/"
		case .event,
		     .promotion: "https://secretdj.s3.amazonaws.com/promotions/"
		case .jukebox: "https://secretdj.s3.amazonaws.com/jukeboxes/"
		case .genre: "https://secretdj.s3.amazonaws.com/genres/"
		case .topUp: "https://secretdj.s3.amazonaws.com/products/"
		case .action: "https://secretdj.s3.amazonaws.com/actions/"
		default: nil
		}
	}

	/// Legacy's fixed resolution ladder (`resolutionMapping` +
	/// `imageURL(for:)`'s fallback chain), ascending from the smallest bucket
	/// to the largest.
	private static let resolutionLadder: [(bucket: ImageResolution, path: String)] = [
		(.small, "small"),
		(.resolution120, "120x120"),
		(.large, "large"),
		(.resolution160, "160x160"),
		(.resolution195, "195x195"),
		(.resolution250, "250x250"),
		(.resolution260, "260x260"),
		(.resolution400, "400x400"),
		(.resolution480, "480x480"),
		(.resolution640, "640x640"),
	]

	/// Resolves the URL for a cell's requested ``ImageSizeClass``
	/// (`mappedImageURL(for:)`), using the resolution bucket legacy's
	/// standard-phone branch picked for it — legacy also branched on
	/// kiosk/iPhone generation, device classing this rewrite has nothing
	/// equivalent to, so it keeps that one mapping rather than reintroducing
	/// device checks. When the exact bucket isn't in ``resolutions``, walks
	/// the ladder toward smaller buckets the way `imageURL(for:)` did.
	/// `nil` when ``itemType`` has no known bucket, ``uri`` is empty, or
	/// nothing at or below the requested bucket is available.
	public func url(for sizeClass: ImageSizeClass) -> URL? {
		guard let baseURLString, !uri.isEmpty,
		      let requestedIndex = Self.resolutionLadder.firstIndex(where: { $0.bucket == resolution(for: sizeClass) }) else {
			return nil
		}

		for index in stride(from: requestedIndex, through: 0, by: -1) {
			let rung = Self.resolutionLadder[index]
			guard resolutions.contains(rung.bucket) else { continue }
			return URL(string: "\(baseURLString)\(rung.path)/\(uri)?\(size)")
		}
		return nil
	}

	private func resolution(for sizeClass: ImageSizeClass) -> ImageResolution {
		switch sizeClass {
		case .size1x1: .resolution640
		case .size2x2: .resolution260
		case .size3x3: .resolution195
		case .size4x4: .large
		}
	}
}
