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
}
