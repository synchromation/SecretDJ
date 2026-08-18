import SecretDJDomain

/// A large, fully-deterministic feed fixture for ``FeedView``'s stress
/// preview (PLAN.md S3.5) — sixty sections mixing every ``FeedSectionKind``,
/// each carrying more items than any real feed page today, to profile
/// against lazy-sections' scroll-performance rules. Preview/test support
/// only, never part of this package's public API.
///
/// Every section and item is derived from fixed loop indices — no `UUID()`,
/// `Date()`, or `Int.random` — so two builds are element-for-element equal
/// (lazy-sections' "every displayed value is computed once, when the model
/// is built" rule, applied to the fixture itself rather than a live
/// `FeedDisplayModel`). Cell text renders through `Text` initialized from a
/// plain `String` variable (never a source-literal `Text(_:)` call), so
/// none of this fixture text is a `LocalizedStringKey` lookup or pollutes
/// the live String Catalog (localization skill's server-text rule).
enum FeedStressFixture {
	/// Twenty sections per kind, interleaved list/carousel/grid so the feed
	/// exercises kind-switching alongside raw item count.
	private static let sectionsPerKind = 20
	/// Item counts per kind (PLAN.md S3.5: "lists of 30, carousels of 20,
	/// grids of 40").
	private static let listItemCount = 30
	private static let carouselItemCount = 20
	private static let gridItemCount = 40

	/// Built once, on first access, and reused for every stress preview.
	static let sections: [FeedDisplayModel.VisibleSection] = makeSections()

	/// Rebuilds the fixture from scratch. Exposed (rather than folded into
	/// ``sections``) so a test can call it twice and compare the results —
	/// the only way to demonstrate there is no hidden randomness.
	static func makeSections() -> [FeedDisplayModel.VisibleSection] {
		(0 ..< sectionsPerKind).flatMap { round in
			[
				makeSection(kind: .list, round: round, itemCount: listItemCount),
				makeSection(kind: .carousel, round: round, itemCount: carouselItemCount),
				makeSection(kind: .grid, round: round, itemCount: gridItemCount),
			]
		}
	}

	private static func makeSection(
		kind: FeedSectionKind,
		round: Int,
		itemCount: Int,
	) -> FeedDisplayModel.VisibleSection {
		FeedDisplayModel.VisibleSection(
			id: "stress-\(kind)-\(round)",
			kind: kind,
			title: "Stress \(kind) \(round)",
			items: (0 ..< itemCount).map { makeItem(kind: kind, round: round, itemIndex: $0) },
		)
	}

	/// Every item is a `.song` payload — cell selection only needs
	/// `FeedCellProps.media`, which every section kind's layout already
	/// renders, so the fixture stresses section/item count rather than
	/// re-covering cell-type variety the mixed-feed preview already
	/// exercises. No artwork URL: a stress pass measures layout, not image
	/// loading.
	private static func makeItem(kind: FeedSectionKind, round: Int, itemIndex: Int) -> FeedDisplayItem {
		let uniqueSuffix = "\(kind)-\(round)-\(itemIndex)"
		let title = "Stress Song \(round)-\(itemIndex)"
		let artist = "Stress Artist \(round)-\(itemIndex)"
		let song = Song(
			songId: "stress-\(uniqueSuffix)",
			title: title,
			artist: artist,
			previewURL: nil,
			likeInfo: LikeInfo(likedByYou: itemIndex.isMultiple(of: 2), info: "12 people buzzed this"),
			text: "\(title)\n\(artist)",
			sortIndex: itemIndex,
			action: nil,
			actions: [],
		)
		return FeedDisplayItem(
			id: "stress-item-\(uniqueSuffix)",
			item: .song(song),
			text: "\(title)\n\(artist)",
			template: template(for: kind),
		)
	}

	/// The template a fixture item carries for its section's kind — any
	/// template `FeedSectionKind.init(template:)` maps to that kind works;
	/// these are simply the plain-song ones (PLAN.md S3.1's mapping table).
	private static func template(for kind: FeedSectionKind) -> Template {
		switch kind {
		case .list: .song
		case .carousel: .horizontalSong
		case .grid: .matrixSongSmall
		case .hidden: .song // Unreachable: this fixture never builds a hidden-kind section.
		}
	}
}
