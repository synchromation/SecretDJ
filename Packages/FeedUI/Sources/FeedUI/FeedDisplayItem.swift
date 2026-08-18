import SecretDJDomain

/// One cell's render-ready data within a ``FeedDisplayModel`` visible
/// section — lazy-sections' `FeedItem`, carrying the underlying Domain
/// ``Item`` so S3.2's cell library can pattern-match its concrete payload.
public struct FeedDisplayItem: Sendable, Hashable, Identifiable {
	/// Stable, server-derived identity (``Item/stableID``) — never the
	/// item's position in the section.
	public let id: String
	public let item: Item
	/// Pre-formatted for display (``Item/displayText``); never reformat
	/// inside a view body.
	public let text: String
	/// The originating section's template — a section is homogeneous, so
	/// every item in it shares one. Carried alongside ``item`` because some
	/// templates collapse onto the same payload type (``Template/award``
	/// and ``Template/checkIn`` both decode as ``SecretDJDomain/Venue``,
	/// LEGACY.md's "venue-shaped items with a badge image"), so cell
	/// selection (S3.2) needs the template to tell them apart.
	public let template: Template
	/// This item's cell-rendering data, derived once here rather than in a
	/// view body (lazy-sections' compute-once rule) — the section views
	/// switch on this, never on a per-render computed property.
	public let props: FeedCellProps

	public init(id: String, item: Item, text: String, template: Template) {
		self.id = id
		self.item = item
		self.text = text
		self.template = template
		props = FeedCellProps.make(item: item, text: text, template: template)
	}
}
