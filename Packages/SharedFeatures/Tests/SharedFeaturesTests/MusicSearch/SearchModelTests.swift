import Testing

@testable import SharedFeatures

import SecretDJDomain

/// Coverage for ``SearchModel`` (PLAN.md S6.3 scope item 2): track mode
/// round-trips a debounced query to the server with stale-response
/// suppression (LEGACY.md "Song search"); artist mode fetches the venue's
/// whole index once and filters it locally, deliberately never filtering
/// down to an empty list (LEGACY.md "Artist search").
enum SearchModelTests {
	@MainActor
	struct `Starting up` {
		@Test func `starts idle with no results`() {
			let model = SearchModel(searching: InMemoryMusicSearching(), clock: ManualSearchDebounceClock())

			#expect(model.query.isEmpty)
			#expect(model.mode == .artist)
			#expect(model.phase == .idle)
			#expect(model.results.isEmpty)
			#expect(model.indexLetters.isEmpty)
		}
	}

	@MainActor
	struct `Track search debouncing` {
		@Test func `typing schedules a debounced search rather than firing immediately`() async {
			let searching = InMemoryMusicSearching()
			let clock = ManualSearchDebounceClock()
			let model = SearchModel(searching: searching, clock: clock)
			await model.updateMode(.track)

			model.updateQuery("Queen")

			#expect(clock.pendingCount == 1)
			#expect(searching.searchCalls.isEmpty)
		}

		@Test func `advancing the clock performs the search`() async {
			let searching = InMemoryMusicSearching()
			searching.setOutcome(.success(makeSongSectionList(songId: "1")), forQuery: "Queen", mode: .track)
			let clock = ManualSearchDebounceClock()
			let model = SearchModel(searching: searching, clock: clock)
			await model.updateMode(.track)
			model.updateQuery("Queen")

			await clock.advance()

			#expect(searching.searchCalls == [InMemoryMusicSearching.SearchCall(query: "Queen", mode: .track)])
			#expect(model.phase == .loaded)
			#expect(model.results.flatMap(\.items).map(\.id) == ["song-1"])
		}

		@Test func `a further keystroke before the debounce fires cancels the earlier one`() async {
			let searching = InMemoryMusicSearching()
			searching.setOutcome(.success(makeSongSectionList(songId: "1")), forQuery: "Que", mode: .track)
			searching.setOutcome(.success(makeSongSectionList(songId: "2")), forQuery: "Queen", mode: .track)
			let clock = ManualSearchDebounceClock()
			let model = SearchModel(searching: searching, clock: clock)
			await model.updateMode(.track)

			model.updateQuery("Que")
			model.updateQuery("Queen")
			await clock.advance()

			#expect(searching.searchCalls == [InMemoryMusicSearching.SearchCall(query: "Queen", mode: .track)])
		}

		@Test func `an empty query blanks the results with no network call`() async {
			let searching = InMemoryMusicSearching()
			searching.setOutcome(.success(makeSongSectionList(songId: "1")), forQuery: "Queen", mode: .track)
			let clock = ManualSearchDebounceClock()
			let model = SearchModel(searching: searching, clock: clock)
			await model.updateMode(.track)
			model.updateQuery("Queen")
			await clock.advance()

			model.updateQuery("")

			#expect(model.results.isEmpty)
			#expect(model.phase == .idle)
			#expect(clock.pendingCount == 0)
		}

		@Test func `an empty response marks the phase empty`() async {
			let searching = InMemoryMusicSearching()
			searching.setOutcome(
				.success(SectionList(hash: FeedHash(rawValue: "h"), sections: [], actions: [])),
				forQuery: "Zzz",
				mode: .track,
			)
			let clock = ManualSearchDebounceClock()
			let model = SearchModel(searching: searching, clock: clock)
			await model.updateMode(.track)
			model.updateQuery("Zzz")

			await clock.advance()

			#expect(model.phase == .empty)
		}

		@Test func `a failed search marks the phase error`() async {
			let searching = InMemoryMusicSearching()
			searching.setOutcome(.failure(.connection), forQuery: "Queen", mode: .track)
			let clock = ManualSearchDebounceClock()
			let model = SearchModel(searching: searching, clock: clock)
			await model.updateMode(.track)
			model.updateQuery("Queen")

			await clock.advance()

			#expect(model.phase == .error)
		}

		@Test func `a stale response arriving after the query changed again is discarded`() async {
			let searching = InMemoryMusicSearching()
			searching.setOutcome(.success(makeSongSectionList(songId: "1")), forQuery: "Que", mode: .track)
			let clock = ManualSearchDebounceClock()
			let model = SearchModel(searching: searching, clock: clock)
			await model.updateMode(.track)
			model.updateQuery("Que")
			await clock.advance()

			// "Queen" is now searched, but its response is held back until
			// after a further keystroke ("Queenz") has already changed the
			// model's current query.
			searching.hangSearch()
			model.updateQuery("Queen")
			async let advanceForQueen: Void = clock.advance()
			await Task.yield()

			model.updateQuery("Queenz")
			searching.resumeSearch(with: .success(makeSongSectionList(songId: "2")))
			await advanceForQueen

			#expect(model.results.flatMap(\.items).map(\.id) == ["song-1"])
		}
	}

	@MainActor
	struct `Artist search` {
		@Test func `switching to artist mode fetches the venue's artist index`() async {
			let searching = InMemoryMusicSearching()
			searching.artistsAvailableResult = .success([makeArtist(name: "Adele")])
			let model = SearchModel(searching: searching, clock: ManualSearchDebounceClock())

			await model.updateMode(.artist)

			#expect(searching.artistsAvailableCallCount == 1)
		}

		@Test func `with no query every artist shows, grouped by first letter`() async {
			let searching = InMemoryMusicSearching()
			searching.artistsAvailableResult = .success([
				makeArtist(name: "Adele"),
				makeArtist(name: "Beyoncé"),
			])
			let model = SearchModel(searching: searching, clock: ManualSearchDebounceClock())

			await model.updateMode(.artist)

			#expect(model.indexLetters == ["A", "B"])
			#expect(model.results.count == 2)
		}

		@Test func `filtering is diacritic- and case-insensitive`() async {
			let searching = InMemoryMusicSearching()
			searching.artistsAvailableResult = .success([makeArtist(name: "Ólafur Arnalds")])
			let model = SearchModel(searching: searching, clock: ManualSearchDebounceClock())
			await model.updateMode(.artist)

			model.updateQuery("olafur")

			#expect(model.results.flatMap(\.items).count == 1)
		}

		@Test func `a name grouped by its diacritic-folded letter still shows under that letter`() async {
			let searching = InMemoryMusicSearching()
			searching.artistsAvailableResult = .success([makeArtist(name: "Ólafur Arnalds")])
			let model = SearchModel(searching: searching, clock: ManualSearchDebounceClock())

			await model.updateMode(.artist)

			#expect(model.indexLetters == ["O"])
		}

		@Test func `a filter matching nothing keeps the previous non-empty results rather than showing none`() async {
			let searching = InMemoryMusicSearching()
			searching.artistsAvailableResult = .success([makeArtist(name: "Adele")])
			let model = SearchModel(searching: searching, clock: ManualSearchDebounceClock())
			await model.updateMode(.artist)

			model.updateQuery("zzzzz")

			#expect(model.results.flatMap(\.items).count == 1)
		}

		@Test func `clearing the query back to empty restores the full index`() async {
			let searching = InMemoryMusicSearching()
			searching.artistsAvailableResult = .success([makeArtist(name: "Adele"), makeArtist(name: "Beyoncé")])
			let model = SearchModel(searching: searching, clock: ManualSearchDebounceClock())
			await model.updateMode(.artist)
			model.updateQuery("Adele")

			model.updateQuery("")

			#expect(model.results.flatMap(\.items).count == 2)
		}

		@Test func `a failed index fetch marks the phase error`() async {
			let searching = InMemoryMusicSearching()
			searching.artistsAvailableResult = .failure(.connection)
			let model = SearchModel(searching: searching, clock: ManualSearchDebounceClock())

			await model.updateMode(.artist)

			#expect(model.phase == .error)
		}

		@Test func `re-entering artist mode does not re-fetch an already-loaded index`() async {
			let searching = InMemoryMusicSearching()
			searching.artistsAvailableResult = .success([makeArtist(name: "Adele")])
			let model = SearchModel(searching: searching, clock: ManualSearchDebounceClock())
			await model.updateMode(.artist)

			await model.updateMode(.track)
			await model.updateMode(.artist)

			#expect(searching.artistsAvailableCallCount == 1)
		}
	}
}

@MainActor
private func makeSongSectionList(songId: String) -> SectionList {
	SectionList(
		hash: FeedHash(rawValue: "h"),
		sections: [Section(
			itemType: .song,
			template: .song,
			title: "Songs",
			index: 0,
			store: nil,
			hash: nil,
			items: [.song(Song(
				songId: songId,
				title: "",
				artist: "",
				previewURL: nil,
				likeInfo: LikeInfo(likedByYou: false, info: ""),
				text: "",
				sortIndex: 0,
				action: nil,
				actions: [],
			))],
		)],
		actions: [],
	)
}

@MainActor
private func makeArtist(name: String, numSongs: Int = 1) -> Artist {
	Artist(name: name, artist: name, numSongs: numSongs, sortIndex: 0, action: nil, actions: [])
}
