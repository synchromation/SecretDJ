/// The like/buzz state and server-worded summary embedded on a likeable
/// item (song, venue, or person) — the `LikeInfo` object LEGACY.md documents
/// nested inside each item's `Data`.
public struct LikeInfo: Sendable, Hashable, Decodable {
	public let likedByYou: Bool
	/// Server-rendered summary copy (e.g. "12 people buzzed this").
	public let info: String

	public init(likedByYou: Bool, info: String) {
		self.likedByYou = likedByYou
		self.info = info
	}

	private enum CodingKeys: String, CodingKey {
		case likedByYou = "LikedByYou"
		case info = "Info"
	}

	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		likedByYou = try container.decodeIfPresent(Bool.self, forKey: .likedByYou) ?? false
		info = try container.decodeIfPresent(String.self, forKey: .info) ?? ""
	}
}
