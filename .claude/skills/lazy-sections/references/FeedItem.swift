import SwiftUI

/// One cell's immutable display data.
struct FeedItem: Identifiable, Hashable {
	/// Stable, server-derived identity. Never derive this from an array
	/// index — `ForEach` needs it unchanged across refreshes to diff and
	/// animate correctly.
	let id: UUID
	let title: String
	/// Pre-formatted for display (price, rating, and similar already
	/// rendered to text); never reformat inside a view body.
	let subtitle: String
	let symbol: String
	/// Pre-resolved; never derive a color inside a view body.
	let tint: Color
}
