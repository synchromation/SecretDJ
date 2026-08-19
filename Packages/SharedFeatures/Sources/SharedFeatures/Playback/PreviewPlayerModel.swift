import Foundation
import Observability
import Observation

/// The single shared 30-second song-preview player (PLAN.md S6.4; LEGACY.md
/// "Audio and playback" — `TuneInViewController`/`KioskTuneInViewController`'s
/// near-duplicate `AudioPlayback` extensions, unified into one shared
/// component here per that section's own "Tech debt NOT to carry forward"
/// note: "an obvious candidate for one shared preview-player component").
///
/// Exactly one preview plays app-wide: ``play(songId:url:)`` stops whatever
/// was previously active first — downloading or already playing, for this
/// song or a different one — so construct **one** instance at the
/// composition root and thread it to every screen that can start a preview
/// (``TuneInScreen``'s own `previewPlayer` doc comment), never one per
/// screen.
///
/// Mirrors legacy's download-then-decode design exactly (the backend serves
/// previews as `.pbz` with a generic Content-Type `AVPlayer` refuses to
/// stream — LEGACY.md's "Evolution: StreamingKit → AVPlayer → download +
/// AVAudioPlayer"): the whole clip downloads via the injected
/// ``PreviewDownloading`` seam before ``AudioPlayerFactory`` ever decodes
/// it, and a ``stop()`` mid-download cancels cleanly with no playback ever
/// starting (business rule 1's "a stop during download cancels cleanly"). A
/// 30-second hard cap runs from the moment playback actually begins,
/// through the injected ``PreviewCapClock`` (never a real timer in tests).
@MainActor
@Observable
public final class PreviewPlayerModel {
	/// `true` from the moment ``play(songId:url:)`` is called until
	/// ``stop()`` — covering both the download phase and the actual-playback
	/// phase, not narrower. This matches legacy's own definition of "active"
	/// (`TuneInViewController.swift`'s `previewContainerTapped` comment:
	/// "'active' means *either* a player exists *or* a download is in
	/// flight") and its `"PlaybackStarted"`/`"PlaybackStopped"` notification
	/// pair, which the kiosk posts at exactly those same two moments
	/// (`KioskTuneInViewController.swift`'s `startAudioPlayer()`/
	/// `stopAudioPlayer()`) rather than only once audio is actually
	/// sounding.
	///
	/// **S7.3 (the kiosk's attract/idle system) observes this property** to
	/// suppress its attract and idle-reset timers for as long as this stays
	/// `true`, resuming them once it returns to `false`
	/// (`KioskTimer.swift`'s `isMusicPlaying`; LEGACY.md business rule 3).
	public var isPlaying: Bool {
		state != .idle
	}

	/// Which song's preview is currently downloading or playing, if any —
	/// lets a screen showing a specific song decide whether *its own* song
	/// is the active one (to render a stop affordance) versus some other
	/// song started elsewhere (to render a play affordance and leave the
	/// other preview alone).
	public var activeSongId: String? {
		switch state {
		case .idle: nil
		case .downloading(let songId),
		     .playing(let songId): songId
		}
	}

	/// Fires whenever a download or decode fails; a pure signal with no
	/// server text to carry (``PreviewPlayerFailureEvent``'s doc comment) —
	/// the caller shows its own fixed fallback copy.
	public private(set) var failureEvent: PreviewPlayerFailureEvent?

	private var state = PreviewPlaybackState.idle

	private let downloading: any PreviewDownloading
	private let playerFactory: any AudioPlayerFactory
	private let clock: any PreviewCapClock
	private let observability: ObservabilityPipeline

	private var downloadTask: Task<Void, Never>?
	private var capToken: PreviewCapClockToken?
	private var player: (any AudioPlaying)?
	/// Increments on every ``play(songId:url:)``/``stop()``, so a download
	/// that resolves after being superseded — a newer ``play()`` or a
	/// ``stop()`` — recognizes it's stale and discards itself, without
	/// relying on `Task` cancellation alone to win every race (mirrors
	/// `TuneInViewController.swift`'s own `previewDownloadTask != nil` guard
	/// in `beginPlayback`, generalized to also cover being superseded by a
	/// *different* song rather than only a plain stop).
	private var generation = 0

	public init(
		downloading: any PreviewDownloading,
		playerFactory: any AudioPlayerFactory,
		clock: any PreviewCapClock = SystemPreviewCapClock(),
		observability: ObservabilityPipeline = .disabled,
	) {
		self.downloading = downloading
		self.playerFactory = playerFactory
		self.clock = clock
		self.observability = observability
	}

	/// Starts (or restarts) preview playback for `songId` at `url`. Any
	/// preview already active — for this song or a different one — stops
	/// first (single active preview app-wide).
	public func play(songId: String, url: URL) {
		stop()
		generation += 1
		let myGeneration = generation
		state = .downloading(songId: songId)
		observability.interaction("playPreview")

		downloadTask = Task { [weak self] in
			guard let self else { return }
			do {
				let data = try await downloading.data(from: url)
				beginPlayback(songId: songId, data: data, generation: myGeneration)
			} catch is CancellationError {
				// stop() already reset state; nothing to do.
			} catch {
				fail(error, generation: myGeneration)
			}
		}
	}

	/// Stops whatever is active — cancels an in-flight download cleanly, or
	/// stops actual playback and disarms the 30-second cap — and returns to
	/// ``PreviewPlaybackState/idle``. A no-op when already idle.
	public func stop() {
		generation += 1
		downloadTask?.cancel()
		downloadTask = nil
		capToken?.cancel()
		capToken = nil
		player?.onFinished = nil
		player?.stop()
		player = nil
		state = .idle
	}

	private func beginPlayback(songId: String, data: Data, generation: Int) {
		// A stop() (or a newer play()) may have happened while we were
		// downloading — discard a stale answer rather than starting playback
		// nobody asked for anymore.
		guard generation == self.generation else { return }

		do {
			let newPlayer = try playerFactory.makePlayer(data: data)
			player = newPlayer
			newPlayer.onFinished = { [weak self] in self?.stop() }
			newPlayer.play()
			state = .playing(songId: songId)
			capToken = clock.schedule(after: Self.maxPreviewDuration) { [weak self] in self?.stop() }
		} catch {
			fail(error, generation: generation)
		}
	}

	private func fail(_ error: any Error, generation: Int) {
		guard generation == self.generation else { return }
		observability.report(error, category: "Playback")
		failureEvent = PreviewPlayerFailureEvent(id: (failureEvent?.id ?? 0) + 1)
		stop()
	}

	/// LEGACY.md's `maxAudioPreviewDuration` — the hard cap both legacy Tune
	/// In screens enforce.
	private static let maxPreviewDuration: Duration = .seconds(30)
}
