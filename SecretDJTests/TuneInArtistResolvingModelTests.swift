import SecretDJDomain
import SharedFeatures
import Testing

@testable import SecretDJ

/// ``TuneInArtistResolvingModel`` — the single-song-artist lookup TuneIn
/// needs when it's reached by name rather than song id
/// (`secretdjv3/TuneInViewController.swift`'s `updateForArtist()`).
@MainActor
enum TuneInArtistResolvingModelTests {
	struct `Starting up` {
		@Test func `starts loading`() {
			let model = makeModel()

			#expect(model.phase == .loading)
		}
	}

	struct Resolving {
		@Test func `a section list with a song resolves to that song`() async {
			let searching = InMemoryMusicSearching()
			searching.songsForArtistResult = .success(SectionList(
				hash: FeedHash(rawValue: "h1"),
				sections: [makeSection(items: [.song(makeSong(songId: "1"))])],
				actions: [],
			))
			let model = makeModel(artistName: "Adele", musicSearching: searching)

			await model.resolve()

			#expect(model.phase == .resolved(makeSong(songId: "1")))
		}

		@Test func `calls the seam with the artist name`() async {
			let searching = InMemoryMusicSearching()
			let model = makeModel(artistName: "Coldplay", musicSearching: searching)

			await model.resolve()

			#expect(searching.songsForArtistCalls == ["Coldplay"])
		}

		@Test func `finds a song in a later section, not just the first`() async {
			let searching = InMemoryMusicSearching()
			searching.songsForArtistResult = .success(SectionList(
				hash: FeedHash(rawValue: "h1"),
				sections: [
					makeSection(items: []),
					makeSection(items: [.song(makeSong(songId: "2"))]),
				],
				actions: [],
			))
			let model = makeModel(musicSearching: searching)

			await model.resolve()

			#expect(model.phase == .resolved(makeSong(songId: "2")))
		}

		@Test func `a section list with no song resolves to empty`() async {
			let searching = InMemoryMusicSearching()
			searching.songsForArtistResult = .success(SectionList(
				hash: FeedHash(rawValue: "h1"),
				sections: [],
				actions: [],
			))
			let model = makeModel(musicSearching: searching)

			await model.resolve()

			#expect(model.phase == .empty)
		}

		@Test func `a failed lookup resolves to failed`() async {
			let searching = InMemoryMusicSearching()
			searching.songsForArtistResult = .failure(.connection)
			let model = makeModel(musicSearching: searching)

			await model.resolve()

			#expect(model.phase == .failed)
		}
	}
}

// MARK: - Fixtures

@MainActor
private func makeModel(
	artistName: String = "Adele",
	musicSearching: any MusicSearching = InMemoryMusicSearching(),
) -> TuneInArtistResolvingModel {
	TuneInArtistResolvingModel(artistName: artistName, musicSearching: musicSearching)
}

private func makeSection(items: [Item]) -> Section {
	Section(itemType: .song, template: .song, title: "", index: 0, store: nil, hash: nil, items: items)
}

private func makeSong(songId: String) -> Song {
	Song(
		songId: songId,
		title: "Yellow",
		artist: "Coldplay",
		previewURL: nil,
		likeInfo: LikeInfo(likedByYou: false, info: ""),
		text: "",
		sortIndex: 0,
		action: nil,
		actions: [],
	)
}
