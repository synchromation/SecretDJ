import Testing

@testable import SharedFeatures

import SecretDJDomain

/// ``TuneInScreenModel``'s server-granted skip/never-play moderation calls
/// (LEGACY.md "Which buttons show is server-decided" — the
/// `machinecontrol` writes, split from `TuneInScreenModelTests` to keep
/// that file under the project's file-length limit). Legacy shows no
/// confirmation before either call
/// (`secretdjv3/TuneInViewController.swift`'s `skipSong()`/`blacklistSong()`
/// dispatch immediately on tap), so neither does this model.
enum TuneInScreenModelModerationTests {
	@MainActor
	struct `Skipping a song` {
		@Test func `calls the seam with the song and venue id`() async {
			let controlling = InMemoryMachineControlling()
			let model = makeModel(song: makeSong(songId: "42"), venueId: "v7", machineControlling: controlling)

			await model.skip()

			#expect(controlling.invocations == [
				InMemoryMachineControlling.Invocation(action: .skip, songId: "42", venueId: "v7"),
			])
		}

		@Test func `raises a toast with the server's message`() async {
			let controlling = InMemoryMachineControlling(result: .success(MachineControlResult(message: "Skipped")))
			let model = makeModel(song: makeSong(), machineControlling: controlling)

			await model.skip()

			#expect(model.toastEvent?.message == "Skipped")
		}

		@Test func `raises no toast when the server sends no message`() async {
			let controlling = InMemoryMachineControlling(result: .success(MachineControlResult(message: nil)))
			let model = makeModel(song: makeSong(), machineControlling: controlling)

			await model.skip()

			#expect(model.toastEvent == nil)
		}

		@Test func `a failure raises no toast — this package owns no fallback copy of its own`() async {
			let controlling = InMemoryMachineControlling(result: .failure(.connection))
			let model = makeModel(song: makeSong(), machineControlling: controlling)

			await model.skip()

			#expect(model.toastEvent == nil)
		}

		@Test func `a second skip while one is in flight makes no extra call`() async {
			let controlling = InMemoryMachineControlling()
			controlling.hang()
			let model = makeModel(song: makeSong(), machineControlling: controlling)

			async let first: Void = model.skip()
			async let second: Void = model.skip()
			await Task.yield()
			controlling.resume(with: .success(MachineControlResult(message: nil)))
			_ = await (first, second)

			#expect(controlling.invocations.count == 1)
		}

		@Test func `isModerating is true while a call is in flight`() async {
			let controlling = InMemoryMachineControlling()
			controlling.hang()
			let model = makeModel(song: makeSong(), machineControlling: controlling)

			async let skip: Void = model.skip()
			await Task.yield()

			#expect(model.isModerating)
			controlling.resume(with: .success(MachineControlResult(message: nil)))
			await skip
			#expect(!model.isModerating)
		}
	}

	@MainActor
	struct `Never-playing a song` {
		@Test func `calls the seam with the neverPlay action`() async {
			let controlling = InMemoryMachineControlling()
			let model = makeModel(song: makeSong(songId: "42"), venueId: "v7", machineControlling: controlling)

			await model.neverPlay()

			#expect(controlling.invocations == [
				InMemoryMachineControlling.Invocation(action: .neverPlay, songId: "42", venueId: "v7"),
			])
		}

		@Test func `raises a toast with the server's message`() async {
			let controlling = InMemoryMachineControlling(
				result: .success(MachineControlResult(message: "This song won't play again")),
			)
			let model = makeModel(song: makeSong(), machineControlling: controlling)

			await model.neverPlay()

			#expect(model.toastEvent?.message == "This song won't play again")
		}

		@Test func `a second never-play while one is in flight makes no extra call`() async {
			let controlling = InMemoryMachineControlling()
			controlling.hang()
			let model = makeModel(song: makeSong(), machineControlling: controlling)

			async let first: Void = model.neverPlay()
			async let second: Void = model.neverPlay()
			await Task.yield()
			controlling.resume(with: .success(MachineControlResult(message: nil)))
			_ = await (first, second)

			#expect(controlling.invocations.count == 1)
		}

		@Test func `a skip in flight also guards against an overlapping never-play call, sharing one moderation guard`(
		) async {
			let controlling = InMemoryMachineControlling()
			controlling.hang()
			let model = makeModel(song: makeSong(), machineControlling: controlling)

			async let skip: Void = model.skip()
			await Task.yield()
			#expect(model.isModerating)

			await model.neverPlay()
			controlling.resume(with: .success(MachineControlResult(message: nil)))
			await skip

			#expect(controlling.invocations.count == 1)
		}
	}
}
