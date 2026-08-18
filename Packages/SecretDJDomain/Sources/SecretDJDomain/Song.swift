import Foundation

/// A jukebox song row — the `song`/`horizontalSong`/`matrixSong*` templates.
public struct Song: Sendable, Hashable, Decodable {
	public let songId: String
	public let title: String
	public let artist: String
	/// URL of the 30-second preview clip, or `nil` when this song has none.
	public let previewURL: String?
	public let likeInfo: LikeInfo
	public let text: String
	public let sortIndex: Int
	public let action: Action?
	public let actions: [Action]
	/// Cover art metadata (`Image`), or `nil` when absent or malformed on
	/// the wire.
	public let image: ItemImage?

	/// The pseudo-song id the server sends when nothing is playing.
	public static let intermissionSongId = "0"

	/// `true` when this is the server's intermission placeholder
	/// (``songId`` == ``intermissionSongId``): inert on the consumer (not
	/// tappable or requestable) and, on the kiosk, a two-line message vehicle
	/// instead of a real song (LEGACY.md "Audio and playback").
	public var isIntermission: Bool {
		songId == Self.intermissionSongId
	}

	/// The two lines the kiosk renders during intermission, splitting
	/// ``title`` on the server's blank-line separator. Meaningful only when
	/// ``isIntermission`` is `true`; the subtitle is empty when the title has
	/// no separator.
	public var intermissionMessageLines: (title: String, subtitle: String) {
		let lines = title.components(separatedBy: "\n\n")
		return (lines.first ?? "", lines.count > 1 ? lines[1] : "")
	}

	public init(
		songId: String,
		title: String,
		artist: String,
		previewURL: String?,
		likeInfo: LikeInfo,
		text: String,
		sortIndex: Int,
		action: Action?,
		actions: [Action],
		image: ItemImage? = nil,
	) {
		self.songId = songId
		self.title = title
		self.artist = artist
		self.previewURL = previewURL
		self.likeInfo = likeInfo
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
		case songId = "SongId"
		case title = "Title"
		case artist = "Artist"
		case previewURL = "Preview"
		case likeInfo = "LikeInfo"
		case action = "Action"
		case actions = "Actions"
	}

	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
		sortIndex = try container.decodeIfPresent(Int.self, forKey: .sortIndex) ?? 0

		let data = try container.nestedContainer(keyedBy: DataKeys.self, forKey: .data)
		// A missing SongId is a deliberate contract, not a data error: it
		// means intermission (see `intermissionSongId`).
		songId = try data.decodeIfPresent(String.self, forKey: .songId) ?? Self.intermissionSongId
		title = try data.decodeIfPresent(String.self, forKey: .title) ?? ""
		artist = try data.decodeIfPresent(String.self, forKey: .artist) ?? ""
		previewURL = try data.decodeIfPresent(String.self, forKey: .previewURL)?.nonEmptyOrNil
		likeInfo = try data.decodeIfPresent(LikeInfo.self, forKey: .likeInfo) ?? LikeInfo(
			likedByYou: false,
			info: "",
		)
		action = try data.decodeIfPresent(Action.self, forKey: .action)
		actions = try data.decodeIfPresent([Action].self, forKey: .actions) ?? []
		// Malformed Image data (present but the wrong shape) never fails the
		// whole item — it just means no artwork for this row.
		image = try? container.decodeIfPresent(ItemImage.self, forKey: .image)
	}
}
