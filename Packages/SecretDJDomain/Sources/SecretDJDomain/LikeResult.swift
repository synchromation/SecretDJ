/// The outcome of a `like`/`unlike` call — `Response.{Text,Url,LikeInfo.LikedByYou}`.
public struct LikeResult: Sendable, Hashable, Decodable {
	/// Server-worded confirmation copy (e.g. "X people buzzed this").
	public let message: String
	public let url: String
	public let isLikedByYou: Bool

	public init(message: String, url: String, isLikedByYou: Bool) {
		self.message = message
		self.url = url
		self.isLikedByYou = isLikedByYou
	}

	private enum CodingKeys: String, CodingKey {
		case message = "Text"
		case url = "Url"
		case likeInfo = "LikeInfo"
	}

	private enum LikeInfoKeys: String, CodingKey {
		case isLikedByYou = "LikedByYou"
	}

	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		message = try container.decode(String.self, forKey: .message)
		url = try container.decode(String.self, forKey: .url)
		let likeInfo = try container.nestedContainer(keyedBy: LikeInfoKeys.self, forKey: .likeInfo)
		isLikedByYou = try likeInfo.decode(Bool.self, forKey: .isLikedByYou)
	}
}
