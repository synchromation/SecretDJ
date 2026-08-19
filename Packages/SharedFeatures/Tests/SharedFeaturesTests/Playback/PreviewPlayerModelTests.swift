import Foundation
import Testing

@testable import SharedFeatures

/// ``PreviewPlayerModel`` — the single shared 30-second song-preview player
/// (LEGACY.md "Audio and playback"; PLAN.md S6.4): download-then-decode over
/// the injected ``PreviewDownloading``/``AudioPlayerFactory`` seams, one
/// active preview app-wide, a 30-second hard cap via the injected
/// ``PreviewCapClock`` (never a real timer here), cancel-during-download,
/// and the ``PreviewPlayerModel/isPlaying`` signal S7.3 will consume for
/// attract-timer suppression.
enum PreviewPlayerModelTests {
	@MainActor
	struct `Starting up` {
		@Test func `starts idle`() {
			let model = makePreviewPlayerModel()

			#expect(!model.isPlaying)
			#expect(model.activeSongId == nil)
			#expect(model.failureEvent == nil)
		}
	}

	@MainActor
	struct `Starting a preview` {
		@Test func `flips to active immediately, before the download resolves`() throws {
			let model = makePreviewPlayerModel()

			try model.play(songId: "1", url: #require(URL(string: "https://example.com/a.pbz")))

			// LEGACY.md business rule 1: "UI toggles instantly while download
			// happens in the background" — active means downloading OR
			// playing, matching legacy's own definition
			// (`previewContainerTapped`'s comment).
			#expect(model.isPlaying)
			#expect(model.activeSongId == "1")
		}

		@Test func `requests the given URL through the downloading seam`() async throws {
			let downloading = InMemoryPreviewDownloading()
			let model = makePreviewPlayerModel(downloading: downloading)
			let url = try #require(URL(string: "https://example.com/a.pbz"))

			model.play(songId: "1", url: url)
			await settle()

			#expect(await downloading.requestedURLs == [url])
		}

		@Test func `begins playback once the download resolves`() async throws {
			let downloading = InMemoryPreviewDownloading()
			let factory = InMemoryAudioPlayerFactory()
			let model = makePreviewPlayerModel(downloading: downloading, playerFactory: factory)
			let data = Data([1, 2, 3])

			try model.play(songId: "1", url: #require(URL(string: "https://example.com/a.pbz")))
			await settle()
			await downloading.complete(with: data)
			await settle()

			#expect(factory.decodedData == [data])
			#expect(factory.lastPlayer?.playCount == 1)
			#expect(model.isPlaying)
			#expect(model.activeSongId == "1")
		}
	}

	@MainActor
	struct `Single active preview app-wide` {
		@Test func `starting a new preview stops one that's still downloading, which never starts playback`(
		) async throws {
			let downloading = InMemoryPreviewDownloading()
			let factory = InMemoryAudioPlayerFactory()
			let model = makePreviewPlayerModel(downloading: downloading, playerFactory: factory)

			try model.play(songId: "1", url: #require(URL(string: "https://example.com/a.pbz")))
			await settle()
			try model.play(songId: "2", url: #require(URL(string: "https://example.com/b.pbz")))
			await settle()

			#expect(model.activeSongId == "2")

			// Song 1's stale response arrives after it was superseded.
			await downloading.complete(with: Data([1]))
			await settle()

			#expect(factory.decodedData.isEmpty)
			#expect(model.activeSongId == "2")

			// Song 2's own response arrives and does start playback.
			await downloading.complete(with: Data([2]))
			await settle()

			#expect(factory.decodedData == [Data([2])])
		}

		@Test func `starting a new preview stops one that's already playing`() async throws {
			let downloading = InMemoryPreviewDownloading()
			let factory = InMemoryAudioPlayerFactory()
			let model = makePreviewPlayerModel(downloading: downloading, playerFactory: factory)

			try model.play(songId: "1", url: #require(URL(string: "https://example.com/a.pbz")))
			await settle()
			await downloading.complete(with: Data([1]))
			await settle()
			let firstPlayer = factory.lastPlayer
			#expect(firstPlayer?.playCount == 1)

			try model.play(songId: "2", url: #require(URL(string: "https://example.com/b.pbz")))

			#expect(firstPlayer?.stopCount == 1)
			#expect(model.activeSongId == "2")
		}
	}

	@MainActor
	struct Stopping {
		@Test func `a stop during download cancels cleanly — playback never starts`() async throws {
			let downloading = InMemoryPreviewDownloading()
			let factory = InMemoryAudioPlayerFactory()
			let model = makePreviewPlayerModel(downloading: downloading, playerFactory: factory)

			try model.play(songId: "1", url: #require(URL(string: "https://example.com/a.pbz")))
			await settle()
			model.stop()

			#expect(!model.isPlaying)
			#expect(model.activeSongId == nil)

			await downloading.complete(with: Data([1]))
			await settle()

			#expect(factory.decodedData.isEmpty)
			#expect(!model.isPlaying)
		}

		@Test func `stopping active playback stops the player and returns to idle`() async throws {
			let downloading = InMemoryPreviewDownloading()
			let factory = InMemoryAudioPlayerFactory()
			let model = makePreviewPlayerModel(downloading: downloading, playerFactory: factory)

			try model.play(songId: "1", url: #require(URL(string: "https://example.com/a.pbz")))
			await settle()
			await downloading.complete(with: Data([1]))
			await settle()

			model.stop()

			#expect(factory.lastPlayer?.stopCount == 1)
			#expect(!model.isPlaying)
			#expect(model.activeSongId == nil)
		}

		@Test func `stopping while idle is a harmless no-op`() {
			let model = makePreviewPlayerModel()

			model.stop()

			#expect(!model.isPlaying)
			#expect(model.activeSongId == nil)
		}
	}

	@MainActor
	struct `The 30-second hard cap` {
		@Test func `stops playback once the injected clock fires`() async throws {
			let downloading = InMemoryPreviewDownloading()
			let factory = InMemoryAudioPlayerFactory()
			let clock = ManualPreviewCapClock()
			let model = makePreviewPlayerModel(downloading: downloading, playerFactory: factory, clock: clock)

			try model.play(songId: "1", url: #require(URL(string: "https://example.com/a.pbz")))
			await settle()
			await downloading.complete(with: Data([1]))
			await settle()

			#expect(model.isPlaying)
			#expect(clock.pendingCount == 1)

			clock.fire()

			#expect(!model.isPlaying)
			#expect(factory.lastPlayer?.stopCount == 1)
		}

		@Test func `is not armed during the download phase — only once playback actually begins`() throws {
			let clock = ManualPreviewCapClock()
			let model = makePreviewPlayerModel(clock: clock)

			try model.play(songId: "1", url: #require(URL(string: "https://example.com/a.pbz")))

			#expect(clock.pendingCount == 0)
		}

		@Test func `stopping before the cap fires disarms it`() async throws {
			let downloading = InMemoryPreviewDownloading()
			let clock = ManualPreviewCapClock()
			let model = makePreviewPlayerModel(downloading: downloading, clock: clock)

			try model.play(songId: "1", url: #require(URL(string: "https://example.com/a.pbz")))
			await settle()
			await downloading.complete(with: Data([1]))
			await settle()
			#expect(clock.pendingCount == 1)

			model.stop()

			#expect(clock.pendingCount == 0)
		}
	}

	@MainActor
	struct `Finishing naturally` {
		@Test func `the player's own finished callback returns the model to idle`() async throws {
			let downloading = InMemoryPreviewDownloading()
			let factory = InMemoryAudioPlayerFactory()
			let model = makePreviewPlayerModel(downloading: downloading, playerFactory: factory)

			try model.play(songId: "1", url: #require(URL(string: "https://example.com/a.pbz")))
			await settle()
			await downloading.complete(with: Data([1]))
			await settle()

			factory.lastPlayer?.finish()

			#expect(!model.isPlaying)
			#expect(model.activeSongId == nil)
		}
	}

	@MainActor
	struct `Download and decode failures surface a toast event` {
		@Test func `a download failure raises the failure event and returns to idle`() async throws {
			let downloading = InMemoryPreviewDownloading()
			let model = makePreviewPlayerModel(downloading: downloading)

			try model.play(songId: "1", url: #require(URL(string: "https://example.com/a.pbz")))
			await settle()
			await downloading.fail(with: StubPreviewError())
			await settle()

			#expect(model.failureEvent?.id == 1)
			#expect(!model.isPlaying)
			#expect(model.activeSongId == nil)
		}

		@Test func `a decode failure raises the failure event and returns to idle`() async throws {
			let downloading = InMemoryPreviewDownloading()
			let factory = InMemoryAudioPlayerFactory()
			factory.failure = StubPreviewError()
			let model = makePreviewPlayerModel(downloading: downloading, playerFactory: factory)

			try model.play(songId: "1", url: #require(URL(string: "https://example.com/a.pbz")))
			await settle()
			await downloading.complete(with: Data([1]))
			await settle()

			#expect(model.failureEvent?.id == 1)
			#expect(!model.isPlaying)
		}

		@Test func `two failures in a row are still distinct ids, for onChange to react to each`() async throws {
			let downloading = InMemoryPreviewDownloading()
			let model = makePreviewPlayerModel(downloading: downloading)

			try model.play(songId: "1", url: #require(URL(string: "https://example.com/a.pbz")))
			await settle()
			await downloading.fail(with: StubPreviewError())
			await settle()

			try model.play(songId: "2", url: #require(URL(string: "https://example.com/b.pbz")))
			await settle()
			await downloading.fail(with: StubPreviewError())
			await settle()

			#expect(model.failureEvent?.id == 2)
		}
	}
}

// MARK: - Fixtures

private struct StubPreviewError: Error, Equatable {}

@MainActor
private func makePreviewPlayerModel(
	downloading: any PreviewDownloading = InMemoryPreviewDownloading(),
	playerFactory: any AudioPlayerFactory = InMemoryAudioPlayerFactory(),
	clock: any PreviewCapClock = ManualPreviewCapClock(),
) -> PreviewPlayerModel {
	PreviewPlayerModel(downloading: downloading, playerFactory: playerFactory, clock: clock)
}

/// Hands control back to the `MainActor`'s queue repeatedly, so
/// ``PreviewPlayerModel``'s internally spawned download `Task` — which hops
/// through ``InMemoryPreviewDownloading``'s actor and back — gets enough
/// scheduling turns to actually run up to (or past) its next suspension
/// point before a test asserts on the result. A single `Task.yield()` isn't
/// reliably enough turns once an actor hop is involved.
@MainActor
private func settle() async {
	for _ in 0 ..< 10 {
		await Task.yield()
	}
}
