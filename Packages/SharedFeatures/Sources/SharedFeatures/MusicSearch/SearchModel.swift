import FeedUI
import Foundation
import Observability
import Observation
import SecretDJDomain

/// Drives the artist/track search screen (LEGACY.md "Choosing music: digest
/// → jukebox pages → search" → "Search"; PLAN.md S6.3 scope item 2).
///
/// The two modes are deliberately different mechanisms, ported verbatim from
/// LEGACY.md's "Artist search"/"Song search":
/// - **Artist mode** downloads the venue's whole artist index once
///   (``MusicSearching/artistsAvailable()``), then filters and buckets it
///   locally into an A–Z-grouped ``results`` — no debounce, no per-keystroke
///   network call — and deliberately never filters down to an empty list:
///   a query matching nothing keeps whatever was showing rather than
///   blanking the screen.
/// - **Track mode** round-trips ``MusicSearching/search(query:mode:)`` per
///   keystroke through the injected ``SearchDebounceClock``, discarding a
///   response that arrives after the query has already moved on (stale-
///   response suppression).
@MainActor
@Observable
public final class SearchModel {
	public private(set) var query = ""
	public private(set) var mode: MusicSearchMode
	public private(set) var phase: SearchPhase = .idle
	/// The current results, ready for ``FeedUI/FeedView`` — one section per
	/// artist-index letter in artist mode, whatever sections the server sent
	/// in track mode.
	public private(set) var results: [FeedDisplayModel.VisibleSection] = []
	/// The letters ``results`` is currently grouped under, for
	/// `DesignSystem/SectionIndexStrip` to jump between — empty outside
	/// artist mode.
	public private(set) var indexLetters: [String] = []

	private let searching: any MusicSearching
	private let clock: any SearchDebounceClock
	private let debounceInterval: Duration
	private let observability: ObservabilityPipeline

	private var debounceToken: SearchDebounceClockToken?
	private var artistIndex: [Artist]?
	private var isLoadingArtistIndex = false

	public init(
		searching: any MusicSearching,
		mode: MusicSearchMode = .artist,
		clock: any SearchDebounceClock = SystemSearchDebounceClock(),
		debounceInterval: Duration = .milliseconds(300),
		observability: ObservabilityPipeline = .disabled,
	) {
		self.searching = searching
		self.mode = mode
		self.clock = clock
		self.debounceInterval = debounceInterval
		self.observability = observability
	}

	/// Updates the query text. Artist mode re-filters the cached index
	/// synchronously; track mode (re)schedules a debounced server search,
	/// cancelling whichever one was already pending.
	public func updateQuery(_ newValue: String) {
		query = newValue
		debounceToken?.cancel()
		debounceToken = nil

		switch mode {
		case .artist:
			applyArtistFilter()

		case .track:
			scheduleTrackSearch()
		}
	}

	/// Switches search mode, activating it: artist mode fetches the index
	/// the first time only (a later switch back reuses the cached index —
	/// see ``artistIndex``); track mode (re)runs the current query if one
	/// exists. Async because entering artist mode with no cached index yet
	/// awaits that one-time fetch — call from a `Task` at the tap site
	/// (mirrors ``FeedUI/FeedScreen``'s own retry action).
	public func updateMode(_ newMode: MusicSearchMode) async {
		mode = newMode
		debounceToken?.cancel()
		debounceToken = nil

		switch mode {
		case .artist:
			if artistIndex != nil {
				applyArtistFilter()
			} else {
				await loadArtistIndex()
			}

		case .track:
			if query.isEmpty {
				results = []
				phase = .idle
			} else {
				scheduleTrackSearch()
			}
		}
	}

	// MARK: - Track mode

	private func scheduleTrackSearch() {
		guard !query.isEmpty else {
			results = []
			phase = .idle
			return
		}

		phase = .searching
		debounceToken = clock.schedule(after: debounceInterval) { [weak self] in
			await self?.performTrackSearch()
		}
	}

	private func performTrackSearch() async {
		let requestedQuery = query
		observability.interaction("searchTrack")

		do {
			let sectionList = try await searching.search(query: requestedQuery, mode: .track)
			// A later keystroke (or a switch to artist mode) may have moved
			// on while this call was in flight — discard a stale answer
			// rather than overwriting whatever's current now.
			guard query == requestedQuery, mode == .track else { return }
			apply(trackResults: sectionList)
		} catch {
			guard query == requestedQuery, mode == .track else { return }
			observability.report(error, category: "MusicSearch")
			phase = .error
		}
	}

	private func apply(trackResults sectionList: SectionList) {
		let displayModel = FeedDisplayModel(sectionList: sectionList)
		results = displayModel.visibleSections
		indexLetters = []
		phase = displayModel.visibleSections.isEmpty ? .empty : .loaded
	}

	// MARK: - Artist mode

	private func loadArtistIndex() async {
		guard !isLoadingArtistIndex else { return }
		isLoadingArtistIndex = true
		defer { isLoadingArtistIndex = false }

		phase = .searching
		observability.interaction("loadArtistIndex")

		do {
			let artists = try await searching.artistsAvailable()
			artistIndex = artists
			guard mode == .artist else { return }
			applyArtistFilter()
		} catch {
			observability.report(error, category: "MusicSearch")
			guard mode == .artist else { return }
			phase = .error
		}
	}

	private func applyArtistFilter() {
		guard let artistIndex else { return }

		let filtered = Self.filter(artistIndex, matching: query)
		// Deliberately never filter down to an empty list once something
		// non-empty is already showing (LEGACY.md "Artist search").
		guard !filtered.isEmpty || query.isEmpty || results.isEmpty else { return }

		let grouped = Self.group(filtered)
		results = grouped.sections
		indexLetters = grouped.letters
		phase = filtered.isEmpty ? .empty : .loaded
	}

	private static func filter(_ artists: [Artist], matching query: String) -> [Artist] {
		guard !query.isEmpty else { return artists }

		let foldedQuery = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
		return artists.filter {
			$0.artist.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).contains(foldedQuery)
		}
	}

	/// Buckets `artists` by ``indexLetter(for:)`` into one server-shaped
	/// ``SecretDJDomain/Section`` per letter, then reuses
	/// ``FeedUI/FeedDisplayModel``'s own id derivation — the same machinery
	/// a real server-driven feed goes through, rather than hand-rolling a
	/// second render-ready id scheme for locally-built results.
	private static func group(_ artists: [Artist]) -> (sections: [FeedDisplayModel.VisibleSection], letters: [String]) {
		var buckets: [String: [Artist]] = [:]
		for artist in artists {
			buckets[indexLetter(for: artist), default: []].append(artist)
		}

		let letters = buckets.keys.sorted()
		let sections = letters.enumerated().map { index, letter in
			Section(
				itemType: .artist,
				template: .artist,
				title: letter,
				index: index,
				store: nil,
				hash: nil,
				items: (buckets[letter] ?? []).sorted {
					$0.artist.localizedCaseInsensitiveCompare($1.artist) == .orderedAscending
				}.map(Item.artist),
			)
		}

		let displayModel = FeedDisplayModel(sectionList: SectionList(
			hash: FeedHash(rawValue: "artist-index"),
			sections: sections,
			actions: [],
		))
		return (displayModel.visibleSections, letters)
	}

	/// The A–Z bucket an artist groups under — diacritic- and
	/// case-folded first letter, or `"#"` for a name that doesn't start
	/// with a letter at all.
	private static func indexLetter(for artist: Artist) -> String {
		let folded = artist.artist.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
		guard let first = folded.first, first.isLetter else { return "#" }
		return String(first).uppercased()
	}
}
