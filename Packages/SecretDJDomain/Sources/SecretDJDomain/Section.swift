/// The iTunes/Apple Music affiliate override a feed section can carry
/// (`Custom.Store` — LEGACY.md "Backend API and Spotify integration",
/// D12's Apple Music affiliate link).
public struct AffiliateStore: Sendable, Hashable, Codable {
	public let searchURL: String?
	public let pageURLPrefix: String?
	public let pageURLSuffix: String?

	public init(searchURL: String?, pageURLPrefix: String?, pageURLSuffix: String?) {
		self.searchURL = searchURL
		self.pageURLPrefix = pageURLPrefix
		self.pageURLSuffix = pageURLSuffix
	}

	private enum CodingKeys: String, CodingKey {
		case searchURL = "SearchUrl"
		case pageURLPrefix = "PageUrlPrefix"
		case pageURLSuffix = "PageUrlSuffix"
	}
}

/// A titled, templated group of items within a ``SectionList`` — visible
/// (a rendered list/carousel) or hidden (a pure data channel, per
/// ``Template``'s hidden cases; LEGACY.md "Domain model and persistence").
///
/// S1.3: not `Decodable` — see ``Item``'s note; the same architecture split
/// applies here. `Custom`'s other keys (`Interactions`, `Response`, `Batch`,
/// `Total`, ...) aren't modeled at all yet: LEGACY.md documents them by name
/// but not a confirmed nesting/shape to decode against without fixtures.
public struct Section: Sendable, Hashable {
	public let itemType: ItemType
	public let template: Template
	public let title: String
	public let index: Int
	public let store: AffiliateStore?
	/// This section's own pagination/change-detection token
	/// (`Custom.Hash`), distinct from the feed-wide ``SectionList/hash``.
	public let hash: FeedHash?
	public let items: [Item]

	public init(
		itemType: ItemType,
		template: Template,
		title: String,
		index: Int,
		store: AffiliateStore?,
		hash: FeedHash?,
		items: [Item],
	) {
		self.itemType = itemType
		self.template = template
		self.title = title
		self.index = index
		self.store = store
		self.hash = hash
		self.items = items
	}
}
