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
	/// Called with the tapped cell's item; `nil` renders every cell
	/// non-interactive. Routing the tap to a ``FeedActionOutcome`` (S3.3) is
	/// the caller's job — this view performs no navigation itself.
	public let onItemTap: ((FeedDisplayItem) -> Void)?
	/// Called each time the last section appears — the event-driven stand-in
	/// for the legacy "within 2000pt of the bottom" infinite-scroll trigger
	/// (LEGACY.md "Refresh rules"). `LazyVStack` materializes a section
	/// shortly before it reaches the viewport, so this fires with a similar
	/// lead time without the continuous scroll-offset tracking
	/// lazy-sections' scroll-performance rules rule out. The caller
	/// (``FeedScreenModel/loadNextPage()``) is already safe to call
	/// repeatedly, so this may fire more than once near the bottom.
	public let onApproachingEnd: (() -> Void)?
	/// A section id to jump to, event-driven (lazy-sections: "Programmatic
	/// scrolling is event-driven ... don't drive it from a
	/// `.scrollPosition(id:)` binding"). The caller sets this — e.g. from
	/// `DesignSystem/SectionIndexStrip`'s `onSelect`, the legacy refactor's
	/// `SectionIndexStrip` A–Z rail jumping "via `FeedView`'s new
	/// `scrollRequest` binding" (LEGACY.md "Refactor branch") — and is
	/// responsible for clearing it back to `nil` once consumed; `nil` never
	/// triggers a scroll.
	public var scrollRequest: Binding<String?>?
	/// Called only when the scroll direction actually changes (never per
	/// frame) — the extra-content ticker's show/hide signal (PLAN.md S6.9).
	/// `nil` for every feed screen without a ticker, which also skips the
	/// `onScrollGeometryChange` observation entirely (see `body`) — this
	/// stays a zero-cost opt-in for the ~dozen other ``FeedView`` call
	/// sites. See ``FeedScrollDirection``'s doc comment for the legacy
	/// mapping this reproduces.
	public let onScrollDirectionChange: ((FeedScrollDirection) -> Void)?

	@State private var lastEmittedScrollDirection: FeedScrollDirection?

	private static let topAnchorID = "top"

	public init(
		sections: [FeedDisplayModel.VisibleSection],
		generation: Int,
		onItemTap: ((FeedDisplayItem) -> Void)? = nil,
		onApproachingEnd: (() -> Void)? = nil,
		scrollRequest: Binding<String?>? = nil,
		onScrollDirectionChange: ((FeedScrollDirection) -> Void)? = nil,
	) {
		self.sections = sections
		self.generation = generation
		self.onItemTap = onItemTap
		self.onApproachingEnd = onApproachingEnd
		self.scrollRequest = scrollRequest
		self.onScrollDirectionChange = onScrollDirectionChange
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
								FeedSectionView(section: section, onItemTap: onItemTap)
									.padding(.bottom, Spacing.small)
							} header: {
								FeedSectionHeader(title: section.title)
							}
						}

						// A sentinel footer, not a section-granular `.onAppear`
						// guarded to `sections.last`: `appendPage` merges a new
						// page's items into the *existing* last section rather
						// than adding a new one for a homogeneous feed, so that
						// section's identity — and its `.onAppear` — would never
						// re-fire past page one. This sentinel's own identity
						// never changes, so each appended page pushes it further
						// down the list, genuinely leaving and re-entering the
						// viewport.
						if !sections.isEmpty {
							paginationSentinel
						}
					}
					.padding(.vertical, Spacing.medium)
				}
			}
			.onChange(of: generation) {
				proxy.scrollTo(Self.topAnchorID, anchor: .top) // not animated → instant
			}
			.onChange(of: scrollRequest?.wrappedValue) { _, newValue in
				guard let newValue else { return }
				proxy.scrollTo(newValue, anchor: .top)
				scrollRequest?.wrappedValue = nil
			}
			// Reads only `contentOffset.y` (a single CGFloat) — never a full
			// `ScrollGeometry`/`GeometryReader` — and the comparison below is
			// O(1), so this stays cheap even though SwiftUI re-evaluates it
			// on every geometry update while the user drags. The
			// state write (`lastEmittedScrollDirection`) and the outward
			// call to `onScrollDirectionChange` only happen on an actual
			// direction flip (``FeedScrollDirection/from(oldOffset:newOffset:threshold:)``),
			// a handful of times per gesture rather than every frame — the
			// coarse, event-driven signal lazy-sections requires. `nil`
			// short-circuits immediately for every ``FeedView`` that isn't
			// hosting a ticker.
			.onScrollGeometryChange(for: CGFloat.self, of: \.contentOffset.y) { oldValue, newValue in
				guard let onScrollDirectionChange else { return }
				guard let direction = FeedScrollDirection.from(oldOffset: oldValue, newOffset: newValue) else { return }
				guard direction != lastEmittedScrollDirection else { return }

				lastEmittedScrollDirection = direction
				onScrollDirectionChange(direction)
			}
		}
	}

	/// Zero-height, no visual footprint — its only job is a stable
	/// `ForEach`-free identity at the bottom of the `LazyVStack` for
	/// ``onApproachingEnd`` to hang an `.onAppear` off.
	private var paginationSentinel: some View {
		Color.clear
			.frame(height: 1)
			.onAppear { onApproachingEnd?() }
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

// PLAN.md S3.5's performance-proof pass: sixty sections mixing every kind,
// well beyond any real feed page's section/item count today, to profile
// against lazy-sections' scroll-performance rules on device-class
// hardware. ``FeedStressFixture`` builds the sections once, deterministically.
#Preview("Stress feed") {
	FeedView(sections: FeedStressFixture.sections, generation: 0)
}

#Preview("Stress feed — accessibility5") {
	FeedView(sections: FeedStressFixture.sections, generation: 0)
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
