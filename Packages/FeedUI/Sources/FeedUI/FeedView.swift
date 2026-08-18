import DesignSystem
import SecretDJDomain
import SwiftUI

/// The outer host for a backend-driven feed screen. One vertical
/// `ScrollView` with a single outer `LazyVStack` provides the laziness for
/// the whole feed (lazy-sections' "one outer lazy container" rule); each
/// section's body materializes only as it approaches the viewport.
///
/// This is the render-only half of the pattern: hidden-section data,
/// dropped-section logging, action dispatch (S3.3), and refresh (S3.4) are
/// the screen's `@Observable` model's job, not this view's (lazy-sections'
/// "only the root feed view reads it, everything below receives plain
/// values" rule) — build a ``FeedDisplayModel`` from a fetched
/// ``SectionList`` and pass its `visibleSections` here.
public struct FeedView: View {
	public let sections: [FeedDisplayModel.VisibleSection]
	/// Incrementing this snaps the feed back to the top — e.g. after a
	/// refresh replaces `sections` (S3.4). Equal values never trigger a
	/// scroll.
	public let generation: Int

	private static let topAnchorID = "top"

	public init(sections: [FeedDisplayModel.VisibleSection], generation: Int) {
		self.sections = sections
		self.generation = generation
	}

	public var body: some View {
		ScrollViewReader { proxy in
			ScrollView(.vertical) {
				VStack(spacing: 0) {
					// Anchor lives outside the lazy container so it always exists.
					Color.clear.frame(height: 0).id(Self.topAnchorID)

					// pinnedViews: [.sectionHeaders] also works here; pinning
					// costs a little per frame, so it stays off by default.
					LazyVStack(spacing: Spacing.large) {
						ForEach(sections) { section in
							Section {
								FeedSectionView(section: section)
									.padding(.bottom, Spacing.small)
							} header: {
								FeedSectionHeader(title: section.title)
							}
						}
					}
					.padding(.vertical, Spacing.medium)
				}
			}
			.onChange(of: generation) {
				proxy.scrollTo(Self.topAnchorID, anchor: .top) // not animated → instant
			}
		}
	}
}

// MARK: - Previews

#Preview("Mixed feed") {
	FeedView(sections: previewMixedSections, generation: 0)
}

#Preview("Empty feed") {
	FeedView(sections: [], generation: 0)
}

#Preview("Accessibility text size") {
	FeedView(sections: previewMixedSections, generation: 0)
		.environment(\.dynamicTypeSize, .accessibility5)
}

/// Inline preview fixtures only. A real feed's sections and items come from
/// ``FeedDisplayModel``, built once from a fetched ``SectionList`` — every
/// cell and header renders this fixture text with `Text(verbatim:)` so none
/// of it pollutes the live String Catalog (localization skill).
private let previewMixedSections: [FeedDisplayModel.VisibleSection] = [
	FeedDisplayModel.VisibleSection(
		id: "list",
		kind: .list,
		title: "Now Playing",
		items: [
			previewSongItem(id: "1", text: "Bohemian Rhapsody\nQueen"),
			previewSongItem(id: "2", text: "Don't Stop Me Now\nQueen"),
			previewSongItem(id: "3", text: "Somebody to Love\nQueen"),
		],
	),
	FeedDisplayModel.VisibleSection(
		id: "carousel",
		kind: .carousel,
		title: "Trending Requests",
		items: [
			previewSongItem(id: "4", text: "Levitating\nDua Lipa"),
			previewSongItem(id: "5", text: "As It Was\nHarry Styles"),
			previewSongItem(id: "6", text: "Blinding Lights\nThe Weeknd"),
			previewSongItem(id: "7", text: "Flowers\nMiley Cyrus"),
		],
	),
	FeedDisplayModel.VisibleSection(
		id: "grid",
		kind: .grid,
		title: "More From The Jukebox",
		items: [
			previewSongItem(id: "8", text: "Uptown Funk\nMark Ronson"),
			previewSongItem(id: "9", text: "Shape of You\nEd Sheeran"),
			previewSongItem(id: "10", text: "Rolling in the Deep\nAdele"),
			previewSongItem(id: "11", text: "Dance Monkey\nTones and I"),
			previewSongItem(id: "12", text: "Watermelon Sugar\nHarry Styles"),
			previewSongItem(id: "13", text: "Circles\nPost Malone"),
		],
	),
]

private func previewSongItem(id: String, text: String) -> FeedDisplayItem {
	let song = Song(
		songId: id,
		title: "",
		artist: "",
		previewURL: nil,
		likeInfo: LikeInfo(likedByYou: false, info: ""),
		text: text,
		sortIndex: 0,
		action: nil,
		actions: [],
	)
	return FeedDisplayItem(id: "song-\(id)", item: .song(song), text: text, template: .song)
}
