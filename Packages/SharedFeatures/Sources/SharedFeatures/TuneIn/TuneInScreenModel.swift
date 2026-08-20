import Observability
import Observation
import SecretDJDomain

/// Drives the song/TuneIn screen (LEGACY.md "Song screen and the request
/// flow (TuneIn)" — `secretdjv3/TuneInViewController.swift`): the request
/// button and its out-of-credits funnel, the server-granted skip/never-play
/// moderation buttons, and an embedded ``OptimisticLikeModel`` for the
/// song's buzz. `song` arrives already resolved (its own Domain payload,
/// from the tap that opened this screen — ``FeedUI/FeedActionOutcome/showSong(_:)``'s
/// doc comment), so this model never re-fetches song details itself; no
/// `songdetails`-by-id endpoint exists to do that with anyway.
@MainActor
@Observable
public final class TuneInScreenModel {
	public let song: Song
	public let venueId: String
	/// The song's buzz — the same reusable toggle S6.2 built for the venue
	/// screen (``OptimisticLikeModel``'s doc comment), constructed here with
	/// this song's own identity/likeInfo.
	public let likeModel: OptimisticLikeModel

	/// Whether a request call is currently in flight — guards
	/// ``requestSong()`` against a second tap racing the first, and lets the
	/// view disable the button.
	public private(set) var isRequesting = false
	/// `true` once a request has actually succeeded (`ReturnCode == 0`) —
	/// kept disabled afterward, mirroring
	/// `secretdjv3/TuneInViewController.swift`'s `jukeboxButtonTapped`,
	/// which never re-enables the button on success (only on failure or
	/// out-of-credits, since either of those leaves the song unrequested).
	public private(set) var hasRequestedSuccessfully = false
	/// Whether a moderation (skip/never-play) call is currently in flight —
	/// guards ``skip()``/``neverPlay()`` against a second tap racing the
	/// first, and lets the view disable both buttons.
	public private(set) var isModerating = false
	/// Set whenever a request or moderation call resolves with server copy
	/// to show; `nil` until the first one. The caller turns this into a
	/// toast (``TuneInToastEvent``'s doc comment).
	public private(set) var toastEvent: TuneInToastEvent?
	/// Set when a request comes back out of credits; `nil` until the first
	/// one. The caller decides what to do with it (``TuneInFunnelEvent``'s
	/// doc comment).
	public private(set) var funnelEvent: TuneInFunnelEvent?

	private let songRequesting: any SongRequesting
	private let machineControlling: any MachineControlling
	private let observability: ObservabilityPipeline

	public init(
		song: Song,
		venueId: String,
		songRequesting: any SongRequesting,
		machineControlling: any MachineControlling,
		likeToggling: any LikeToggling,
		observability: ObservabilityPipeline = .disabled,
	) {
		self.song = song
		self.venueId = venueId
		self.songRequesting = songRequesting
		self.machineControlling = machineControlling
		self.observability = observability
		likeModel = OptimisticLikeModel(
			itemId: song.songId,
			venueId: venueId,
			type: .song,
			likeInfo: song.likeInfo,
			likeToggling: likeToggling,
			observability: observability,
		)
	}

	/// Which server-granted actions this song carries
	/// (`secretdjv3/TuneInViewController.swift`'s `checkActions()`, LEGACY.md
	/// business rule 7 — the server's `actions` array dictates request vs
	/// skip vs blacklist affordances, not client logic).
	private var grantedActions: Set<ActionKind> {
		Set(song.actions.map(\.kind))
	}

	/// Whether the request button shows. Hidden whenever either moderation
	/// button is granted — server-granted staff controls replace the
	/// request button rather than supplementing it, mirroring
	/// `updateSongControlButtons()`'s branching (every branch that shows a
	/// moderation button also hides the jukebox button).
	public var showsRequestButton: Bool {
		grantedActions.contains(.jukeboxRequestSong) && !showsSkipButton && !showsNeverPlayButton
	}

	public var showsSkipButton: Bool {
		grantedActions.contains(.jukeboxSkipSong)
	}

	public var showsNeverPlayButton: Bool {
		grantedActions.contains(.jukeboxBlacklistSong)
	}

	/// Requests ``song`` on ``venueId``'s jukebox. A no-op while
	/// ``isRequesting`` or once ``hasRequestedSuccessfully``. Classifies the
	/// server's outcome per LEGACY.md business rule 5: success shows the
	/// server's own toast copy and disables the button for good; out of
	/// credits raises ``funnelEvent`` for the caller to route into the
	/// pic-for-credits/top-up funnel; any other failure shows the server's
	/// own error copy. A transport-level failure is reported to
	/// observability but shows no toast — this package owns no fallback
	/// copy of its own to show instead (mirrors ``MoodTileModel``'s doc
	/// comment).
	public func requestSong() async {
		guard !isRequesting, !hasRequestedSuccessfully else { return }

		isRequesting = true
		defer { isRequesting = false }

		observability.interaction("requestSong")

		do {
			let result = try await songRequesting.requestSong(songId: song.songId, venueId: venueId)
			switch result {
			case .success(let message, _, let richToast):
				hasRequestedSuccessfully = true
				observability.track(TuneInEvent.songRequested)
				raiseToast(message, richToast: richToast)

			case .outOfCredits(let hasProfilePicture):
				observability.track(TuneInEvent.songRequestOutOfCredits)
				funnelEvent = TuneInFunnelEvent(id: (funnelEvent?.id ?? 0) + 1, hasProfilePicture: hasProfilePicture)

			case .failure(let message):
				observability.track(TuneInEvent.songRequestFailed)
				raiseToast(message)
			}
		} catch {
			observability.report(error, category: "TuneIn")
			observability.track(TuneInEvent.songRequestFailed)
		}
	}

	/// Submits the server-granted skip action against ``song``. A no-op
	/// while ``isModerating``.
	public func skip() async {
		await moderate(.skip, successEvent: .songSkipped, failureEvent: .songSkipFailed)
	}

	/// Submits the server-granted never-play (blacklist) action against
	/// ``song``. A no-op while ``isModerating``.
	public func neverPlay() async {
		await moderate(.neverPlay, successEvent: .songNeverPlayed, failureEvent: .songNeverPlayFailed)
	}

	private func moderate(
		_ action: TuneInModerationAction,
		successEvent: TuneInEvent,
		failureEvent: TuneInEvent,
	) async {
		guard !isModerating else { return }

		isModerating = true
		defer { isModerating = false }

		observability.interaction(action == .skip ? "skipSong" : "neverPlaySong")

		do {
			let result = try await machineControlling.moderate(action, songId: song.songId, venueId: venueId)
			observability.track(successEvent)
			if let message = result.message {
				raiseToast(message)
			}
		} catch {
			observability.report(error, category: "TuneIn")
			observability.track(failureEvent)
		}
	}

	private func raiseToast(_ message: String?, richToast: RichToastData? = nil) {
		guard let message, !message.isEmpty else { return }
		toastEvent = TuneInToastEvent(id: (toastEvent?.id ?? 0) + 1, message: message, richToast: richToast)
	}
}
