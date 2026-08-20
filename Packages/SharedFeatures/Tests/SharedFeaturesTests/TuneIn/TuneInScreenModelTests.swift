import Testing

@testable import SharedFeatures

import SecretDJDomain

/// ``TuneInScreenModel`` — the song/TuneIn screen's model (LEGACY.md "Song
/// screen and the request flow (TuneIn)"): request outcomes and the
/// out-of-credits funnel (business rule 5), server-granted moderation
/// visibility (business rule 7), and the embedded buzz toggle.
enum TuneInScreenModelTests {
	@MainActor
	struct `Starting up` {
		@Test func `carries the song and venue it was given`() {
			let model = makeModel(song: makeSong(songId: "1", actions: []), venueId: "v9")

			#expect(model.song.songId == "1")
			#expect(model.venueId == "v9")
		}

		@Test func `embeds a like model seeded from the song's own likeInfo`() {
			let song = makeSong(likeInfo: LikeInfo(likedByYou: true, info: "12 people buzzed this"))
			let model = makeModel(song: song)

			#expect(model.likeModel.likeInfo == LikeInfo(likedByYou: true, info: "12 people buzzed this"))
		}

		@Test func `starts idle`() {
			let model = makeModel(song: makeSong())

			#expect(!model.isRequesting)
			#expect(!model.hasRequestedSuccessfully)
			#expect(!model.isModerating)
			#expect(model.toastEvent == nil)
			#expect(model.funnelEvent == nil)
		}
	}

	@MainActor
	struct `Button visibility, server-decided (LEGACY.md business rule 7)` {
		@Test func `only jukeboxRequestSong grants the request button`() {
			let model = makeModel(song: makeSong(actions: [.jukeboxRequestSong]))

			#expect(model.showsRequestButton)
			#expect(!model.showsSkipButton)
			#expect(!model.showsNeverPlayButton)
		}

		@Test func `no granted actions shows nothing`() {
			let model = makeModel(song: makeSong(actions: []))

			#expect(!model.showsRequestButton)
			#expect(!model.showsSkipButton)
			#expect(!model.showsNeverPlayButton)
		}

		@Test func `jukeboxSkipSong grants the skip button and hides the request button, even when both are granted`() {
			let model = makeModel(song: makeSong(actions: [.jukeboxRequestSong, .jukeboxSkipSong]))

			#expect(model.showsSkipButton)
			#expect(!model.showsRequestButton)
		}

		@Test func `the never-play server action grants that button and hides the request button`() {
			let model = makeModel(song: makeSong(actions: [.jukeboxRequestSong, .jukeboxBlacklistSong]))

			#expect(model.showsNeverPlayButton)
			#expect(!model.showsRequestButton)
		}

		@Test func `both moderation actions grant both buttons together`() {
			let model = makeModel(song: makeSong(actions: [.jukeboxSkipSong, .jukeboxBlacklistSong]))

			#expect(model.showsSkipButton)
			#expect(model.showsNeverPlayButton)
			#expect(!model.showsRequestButton)
		}
	}

	@MainActor
	struct `Requesting a song, on success` {
		@Test func `raises a toast with the server's message`() async {
			let requesting = InMemorySongRequesting(result: .success(.success(message: "You're up next!", url: nil)))
			let model = makeModel(song: makeSong(), songRequesting: requesting)

			await model.requestSong()

			#expect(model.toastEvent?.message == "You're up next!")
		}

		@Test func `raises no toast when the server sends no message`() async {
			let requesting = InMemorySongRequesting(result: .success(.success(message: nil, url: nil)))
			let model = makeModel(song: makeSong(), songRequesting: requesting)

			await model.requestSong()

			#expect(model.toastEvent == nil)
		}

		@Test func `marks the request as succeeded, for good`() async {
			let requesting = InMemorySongRequesting(result: .success(.success(message: nil, url: nil)))
			let model = makeModel(song: makeSong(), songRequesting: requesting)

			await model.requestSong()

			#expect(model.hasRequestedSuccessfully)
		}

		@Test func `a second call after success makes no further request call`() async {
			let requesting = InMemorySongRequesting(result: .success(.success(message: nil, url: nil)))
			let model = makeModel(song: makeSong(), songRequesting: requesting)

			await model.requestSong()
			await model.requestSong()

			#expect(requesting.invocations.count == 1)
		}

		@Test func `calls the seam with the song and venue id`() async {
			let requesting = InMemorySongRequesting()
			let model = makeModel(song: makeSong(songId: "42"), venueId: "v7", songRequesting: requesting)

			await model.requestSong()

			#expect(requesting.invocations == [InMemorySongRequesting.Invocation(songId: "42", venueId: "v7")])
		}
	}

	@MainActor
	struct `Requesting a song, out of credits (LEGACY.md business rule 5)` {
		@Test func `raises a funnel event carrying whether the user has a profile picture`() async {
			let requesting = InMemorySongRequesting(result: .success(.outOfCredits(hasProfilePicture: false)))
			let model = makeModel(song: makeSong(), songRequesting: requesting)

			await model.requestSong()

			#expect(model.funnelEvent?.hasProfilePicture == false)
		}

		@Test func `carries true when the user already has a profile picture`() async {
			let requesting = InMemorySongRequesting(result: .success(.outOfCredits(hasProfilePicture: true)))
			let model = makeModel(song: makeSong(), songRequesting: requesting)

			await model.requestSong()

			#expect(model.funnelEvent?.hasProfilePicture == true)
		}

		@Test func `raises no toast`() async {
			let requesting = InMemorySongRequesting(result: .success(.outOfCredits(hasProfilePicture: false)))
			let model = makeModel(song: makeSong(), songRequesting: requesting)

			await model.requestSong()

			#expect(model.toastEvent == nil)
		}

		@Test func `does not mark the request as succeeded, so a later tap can try again`() async {
			let requesting = InMemorySongRequesting(result: .success(.outOfCredits(hasProfilePicture: false)))
			let model = makeModel(song: makeSong(), songRequesting: requesting)

			await model.requestSong()

			#expect(!model.hasRequestedSuccessfully)
		}

		@Test func `a second out-of-credits funnel event is a distinct id`() async {
			let requesting = InMemorySongRequesting(result: .success(.outOfCredits(hasProfilePicture: false)))
			let model = makeModel(song: makeSong(), songRequesting: requesting)

			await model.requestSong()
			let first = model.funnelEvent
			await model.requestSong()
			let second = model.funnelEvent

			#expect(first?.id != second?.id)
		}
	}

	@MainActor
	struct `Requesting a song, server failure` {
		@Test func `raises a toast with the server's error message`() async {
			let requesting = InMemorySongRequesting(result: .success(.failure(message: "Sorry, that jukebox is full")))
			let model = makeModel(song: makeSong(), songRequesting: requesting)

			await model.requestSong()

			#expect(model.toastEvent?.message == "Sorry, that jukebox is full")
		}

		@Test func `raises no toast when the server's failure carries no message`() async {
			let requesting = InMemorySongRequesting(result: .success(.failure(message: "")))
			let model = makeModel(song: makeSong(), songRequesting: requesting)

			await model.requestSong()

			#expect(model.toastEvent == nil)
		}

		@Test func `does not mark the request as succeeded`() async {
			let requesting = InMemorySongRequesting(result: .success(.failure(message: "Sorry")))
			let model = makeModel(song: makeSong(), songRequesting: requesting)

			await model.requestSong()

			#expect(!model.hasRequestedSuccessfully)
		}
	}

	@MainActor
	struct `Requesting a song, transport failure` {
		@Test func `raises no toast — this package owns no fallback copy of its own`() async {
			let requesting = InMemorySongRequesting(result: .failure(.connection))
			let model = makeModel(song: makeSong(), songRequesting: requesting)

			await model.requestSong()

			#expect(model.toastEvent == nil)
		}

		@Test func `does not mark the request as succeeded`() async {
			let requesting = InMemorySongRequesting(result: .failure(.connection))
			let model = makeModel(song: makeSong(), songRequesting: requesting)

			await model.requestSong()

			#expect(!model.hasRequestedSuccessfully)
		}
	}

	@MainActor
	struct `Requesting, double-tap races` {
		@Test func `a second request while one is in flight makes no extra call`() async {
			let requesting = InMemorySongRequesting()
			requesting.hang()
			let model = makeModel(song: makeSong(), songRequesting: requesting)

			async let first: Void = model.requestSong()
			async let second: Void = model.requestSong()
			await waitUntil { !requesting.invocations.isEmpty }
			requesting.resume(with: .success(.success(message: nil, url: nil)))
			_ = await (first, second)

			#expect(requesting.invocations.count == 1)
		}

		@Test func `isRequesting is true while a call is in flight`() async {
			let requesting = InMemorySongRequesting()
			requesting.hang()
			let model = makeModel(song: makeSong(), songRequesting: requesting)

			async let request: Void = model.requestSong()
			await waitUntil { !requesting.invocations.isEmpty }

			#expect(model.isRequesting)
			requesting.resume(with: .success(.success(message: nil, url: nil)))
			await request
			#expect(!model.isRequesting)
		}
	}
}

// MARK: - Fixtures

/// Polls until `condition` holds, yielding the MainActor between checks —
/// a deterministic replacement for a single bare `await Task.yield()`
/// before asserting on an in-flight `async let`'s side effects. A single
/// yield only *suggests* the scheduler give another ready job a turn; it
/// doesn't guarantee the specific `async let` child task actually ran
/// before the caller resumes, so an assertion placed right after it is
/// flaky under heavy system load (observed: passes in isolation, fails
/// intermittently inside the full `Scripts/verify.sh test` run, where many
/// other processes contend for the same cooperative thread pool). Capped
/// so a genuine regression still fails fast rather than hanging.
@MainActor
private func waitUntil(_ condition: () -> Bool) async {
	for _ in 0 ..< 10000 where !condition() {
		await Task.yield()
	}
}

// MARK: - Fixtures

@MainActor
func makeModel(
	song: Song,
	venueId: String = "v1",
	songRequesting: any SongRequesting = InMemorySongRequesting(),
	machineControlling: any MachineControlling = InMemoryMachineControlling(),
	likeToggling: any LikeToggling = InMemoryLikeToggling(),
) -> TuneInScreenModel {
	TuneInScreenModel(
		song: song,
		venueId: venueId,
		songRequesting: songRequesting,
		machineControlling: machineControlling,
		likeToggling: likeToggling,
	)
}

func makeSong(
	songId: String = "1",
	likeInfo: LikeInfo = LikeInfo(likedByYou: false, info: ""),
	actions: [ActionKind] = [.jukeboxRequestSong],
) -> Song {
	Song(
		songId: songId,
		title: "Yellow",
		artist: "Coldplay",
		previewURL: nil,
		likeInfo: likeInfo,
		text: "",
		sortIndex: 0,
		action: nil,
		actions: actions.map { kind in
			Action(kind: kind, itemId: Int(songId), itemTypeId: nil, value: nil, url: nil, button: .unsupported(0))
		},
	)
}
