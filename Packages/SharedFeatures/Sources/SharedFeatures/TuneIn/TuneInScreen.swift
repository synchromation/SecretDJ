import DesignSystem
import Observability
import SecretDJDomain
import SwiftUI

/// The song/TuneIn screen (LEGACY.md "Song screen and the request flow
/// (TuneIn)", PLAN.md S6.3b/S6.4): artwork/title/artist, the play/stop
/// preview button wired to the shared ``PreviewPlayerModel``, embedded buzz
/// (``OptimisticLikeModel`` via ``TuneInScreenModel/likeModel``), the
/// request button, and the server-granted skip/never-play moderation
/// buttons. "Listen elsewhere" (dropped — D12) isn't this screen's concern.
///
/// Artwork is always rendered through ``DesignSystem/RemoteArtworkView`` at
/// its largest bucket — legacy's full-bleed-vs-blurred-centered distinction
/// (`secretdjv3/TuneInViewController.swift`'s `updateHeaderImage()`) is a
/// deliberate scope trim, matching the mood-duration-picker deferral
/// PLAN.md's S6.3 checkbox already documents: no other S6 screen carries
/// that blur effect forward either.
public struct TuneInScreen: View {
	public let copy: TuneInScreenCopy
	public let toastQueue: ToastQueue
	/// Fires when a request comes back out of credits, carrying whether the
	/// signed-in user already has a profile picture
	/// (``TuneInFunnelEvent/hasProfilePicture``). Both branches of LEGACY.md
	/// business rule 5 need consumer-only UI this package doesn't own — the
	/// pic-for-credits dialog reuses S4.5's onboarding avatar-picker
	/// components, and the top-up screen is `AppDestination.topUps` — so
	/// this screen only surfaces the signal rather than presenting either
	/// itself, mirroring ``MusicSelectionScreen/onOutcome``'s own contract
	/// for outcomes it doesn't self-handle.
	public let onOutOfCredits: ((Bool) -> Void)?
	/// The app-wide shared preview player (S6.4) — constructed **once** at
	/// the composition root and threaded down to every ``TuneInScreen``,
	/// never created here (``PreviewPlayerModel``'s own doc comment on why
	/// it's a shared instance, not per-screen).
	public let previewPlayer: PreviewPlayerModel

	@State private var model: TuneInScreenModel
	@Environment(\.dynamicTypeSize) private var dynamicTypeSize

	public init(
		song: Song,
		venueId: String,
		songRequesting: any SongRequesting,
		machineControlling: any MachineControlling,
		likeToggling: any LikeToggling,
		copy: TuneInScreenCopy,
		toastQueue: ToastQueue,
		previewPlayer: PreviewPlayerModel,
		onOutOfCredits: ((Bool) -> Void)? = nil,
		observability: ObservabilityPipeline = .disabled,
	) {
		self.copy = copy
		self.toastQueue = toastQueue
		self.previewPlayer = previewPlayer
		self.onOutOfCredits = onOutOfCredits
		_model = State(initialValue: TuneInScreenModel(
			song: song,
			venueId: venueId,
			songRequesting: songRequesting,
			machineControlling: machineControlling,
			likeToggling: likeToggling,
			observability: observability,
		))
	}

	public var body: some View {
		ScrollView {
			VStack(spacing: Spacing.large) {
				artwork
				details
				preview
				buzz
				actions
			}
			.padding(Spacing.large)
			.frame(maxWidth: .infinity)
		}
		.background(Theme.ColorRole.background.color)
		.navigationTitle(copy.navigationTitle)
		.onChange(of: model.toastEvent, showToast)
		.onChange(of: model.likeModel.failureEvent, showLikeFailureToast)
		.onChange(of: model.funnelEvent, forwardFunnelEvent)
		.onChange(of: previewPlayer.failureEvent, showPreviewFailureToast)
		.onDisappear(perform: stopOwnPreviewIfActive)
		.tracksScreen("TuneIn")
	}

	private var artwork: some View {
		RemoteArtworkView(
			url: model.song.image?.url(for: .size1x1),
			placeholderIcon: .song,
			width: nil,
			height: 280,
		)
	}

	private var details: some View {
		VStack(spacing: Spacing.extraSmall) {
			Text(verbatim: model.song.title)
				.font(Theme.TextStyle.screenTitle.font)
				.foregroundStyle(Theme.ColorRole.primaryText.color)
				.multilineTextAlignment(.center)

			Text(verbatim: model.song.artist)
				.font(Theme.TextStyle.body.font)
				.foregroundStyle(Theme.ColorRole.secondaryText.color)
				.multilineTextAlignment(.center)
		}
	}

	/// Hidden entirely when the song carries no preview URL (LEGACY.md
	/// business rule 2), matching both legacy screens' own hidden/disabled
	/// affordance for a preview-less song.
	@ViewBuilder
	private var preview: some View {
		if let previewURL = model.song.previewURL, let url = URL(string: previewURL) {
			previewButton(url: url)
		}
	}

	private func previewButton(url: URL) -> some View {
		let isThisSongActive = previewPlayer.activeSongId == model.song.songId
		let action: () -> Void = { togglePreview(url: url) }

		return Button(action: action) {
			(isThisSongActive ? Theme.Icon.stopPreview : Theme.Icon.playPreview).image
				.frame(minWidth: Self.minimumTapTarget, minHeight: Self.minimumTapTarget)
				.contentShape(Rectangle())
		}
		.accessibilityLabel(copy.previewAccessibilityLabel)
		.accessibilityValue(isThisSongActive ? copy.previewPlayingValue : copy.previewStoppedValue)
	}

	/// The system minimum for a comfortable tap target (accessibility
	/// skill: "Hit targets at least 44×44 points") — mirrors
	/// ``DesignSystem/LikeButton``'s own constant, applied for the same
	/// reason (an icon-only control would otherwise shrink to the bare
	/// glyph's bounds).
	private static let minimumTapTarget: CGFloat = 44

	private var buzz: some View {
		LikeButton(
			isLiked: model.likeModel.likeInfo.likedByYou,
			summary: model.likeModel.likeInfo.info,
			isBusy: model.likeModel.isToggling,
			accessibilityLabel: copy.buzzAccessibilityLabel,
			action: { Task { await model.likeModel.toggle() } },
		)
	}

	@ViewBuilder
	private var actions: some View {
		if model.showsSkipButton || model.showsNeverPlayButton {
			moderationButtons
		} else if model.showsRequestButton {
			requestButton
		}
	}

	private var requestButton: some View {
		Button(action: requestSongTapped) {
			copy.requestButtonTitle
				.frame(maxWidth: .infinity)
		}
		.buttonStyle(.primary)
		.disabled(model.isRequesting || model.hasRequestedSuccessfully)
	}

	@ViewBuilder
	private var moderationButtons: some View {
		if dynamicTypeSize.isAccessibilitySize {
			VStack(spacing: Spacing.small) {
				moderationButtonContent
			}
		} else {
			HStack(spacing: Spacing.small) {
				moderationButtonContent
			}
		}
	}

	@ViewBuilder
	private var moderationButtonContent: some View {
		if model.showsSkipButton {
			Button(action: skipTapped) {
				copy.skipButtonTitle
					.frame(maxWidth: .infinity)
			}
			.buttonStyle(.primary)
			.disabled(model.isModerating)
		}

		if model.showsNeverPlayButton {
			Button(action: neverPlayTapped) {
				copy.neverPlayButtonTitle
					.frame(maxWidth: .infinity)
			}
			.buttonStyle(.secondary)
			.disabled(model.isModerating)
		}
	}

	private func requestSongTapped() {
		Task { await model.requestSong() }
	}

	private func skipTapped() {
		Task { await model.skip() }
	}

	private func neverPlayTapped() {
		Task { await model.neverPlay() }
	}

	/// Single active preview app-wide: this song's own tap either starts it
	/// (stopping whatever else was active) or, when this song is already
	/// the active one, stops it — the shared player's own contract
	/// (``PreviewPlayerModel/play(songId:url:)``'s doc comment).
	private func togglePreview(url: URL) {
		if previewPlayer.activeSongId == model.song.songId {
			previewPlayer.stop()
		} else {
			previewPlayer.play(songId: model.song.songId, url: url)
		}
	}

	/// Stops the shared player only when *this* screen's own song is the
	/// one currently active — LEGACY.md business rule 1's "stop on screen
	/// exit", scoped so popping back to an earlier TuneIn screen (e.g. from
	/// an artist's song list) never stops a still-relevant preview that
	/// screen itself started.
	private func stopOwnPreviewIfActive() {
		guard previewPlayer.activeSongId == model.song.songId else { return }
		previewPlayer.stop()
	}

	private func showPreviewFailureToast(_: PreviewPlayerFailureEvent?, _ event: PreviewPlayerFailureEvent?) {
		guard event != nil else { return }
		toastQueue.enqueue(ToastItem(message: copy.previewFailureMessage))
	}

	private func showToast(_: TuneInToastEvent?, _ event: TuneInToastEvent?) {
		guard let event else { return }
		toastQueue.enqueue(ToastItem(message: event.message))
	}

	/// Shows a toast only when the buzz toggle's failure carried server
	/// copy — this package owns no fallback copy of its own to show
	/// instead (mirrors ``MoodTileModel``'s doc comment).
	private func showLikeFailureToast(_: LikeFailureEvent?, _ event: LikeFailureEvent?) {
		guard let event, let message = event.message else { return }
		toastQueue.enqueue(ToastItem(message: message))
	}

	private func forwardFunnelEvent(_: TuneInFunnelEvent?, _ event: TuneInFunnelEvent?) {
		guard let event else { return }
		onOutOfCredits?(event.hasProfilePicture)
	}
}

// MARK: - Previews

#Preview("Request granted") {
	NavigationStack {
		TuneInScreen(
			song: PreviewSong.requestable,
			venueId: "v1",
			songRequesting: InMemorySongRequesting(),
			machineControlling: InMemoryMachineControlling(),
			likeToggling: InMemoryLikeToggling(),
			copy: .preview,
			toastQueue: ToastQueue(),
			previewPlayer: PreviewPlayerModel(
				downloading: InMemoryPreviewDownloading(),
				playerFactory: InMemoryAudioPlayerFactory(),
			),
		)
	}
}

#Preview("With a song preview") {
	NavigationStack {
		TuneInScreen(
			song: PreviewSong.withPreview,
			venueId: "v1",
			songRequesting: InMemorySongRequesting(),
			machineControlling: InMemoryMachineControlling(),
			likeToggling: InMemoryLikeToggling(),
			copy: .preview,
			toastQueue: ToastQueue(),
			previewPlayer: PreviewPlayerModel(
				downloading: InMemoryPreviewDownloading(),
				playerFactory: InMemoryAudioPlayerFactory(),
			),
		)
	}
}

#Preview("Moderation granted") {
	NavigationStack {
		TuneInScreen(
			song: PreviewSong.moderatable,
			venueId: "v1",
			songRequesting: InMemorySongRequesting(),
			machineControlling: InMemoryMachineControlling(),
			likeToggling: InMemoryLikeToggling(),
			copy: .preview,
			toastQueue: ToastQueue(),
			previewPlayer: PreviewPlayerModel(
				downloading: InMemoryPreviewDownloading(),
				playerFactory: InMemoryAudioPlayerFactory(),
			),
		)
	}
}

#Preview("Liked, with buzz summary") {
	NavigationStack {
		TuneInScreen(
			song: PreviewSong.liked,
			venueId: "v1",
			songRequesting: InMemorySongRequesting(),
			machineControlling: InMemoryMachineControlling(),
			likeToggling: InMemoryLikeToggling(),
			copy: .preview,
			toastQueue: ToastQueue(),
			previewPlayer: PreviewPlayerModel(
				downloading: InMemoryPreviewDownloading(),
				playerFactory: InMemoryAudioPlayerFactory(),
			),
		)
	}
}

#Preview("Accessibility text size") {
	NavigationStack {
		TuneInScreen(
			song: PreviewSong.moderatable,
			venueId: "v1",
			songRequesting: InMemorySongRequesting(),
			machineControlling: InMemoryMachineControlling(),
			likeToggling: InMemoryLikeToggling(),
			copy: .preview,
			toastQueue: ToastQueue(),
			previewPlayer: PreviewPlayerModel(
				downloading: InMemoryPreviewDownloading(),
				playerFactory: InMemoryAudioPlayerFactory(),
			),
		)
	}
	.environment(\.dynamicTypeSize, .accessibility5)
}

extension TuneInScreenCopy {
	/// Preview-only placeholder copy — a real app supplies its own
	/// String-Catalog-backed ``TuneInScreenCopy`` (this package owns no copy
	/// of its own).
	fileprivate static var preview: TuneInScreenCopy {
		TuneInScreenCopy(
			navigationTitle: Text(verbatim: "Tune In"),
			requestButtonTitle: Text(verbatim: "Play on the Jukebox"),
			skipButtonTitle: Text(verbatim: "Skip"),
			neverPlayButtonTitle: Text(verbatim: "Never Play This"),
			buzzAccessibilityLabel: Text(verbatim: "Like this song"),
			previewAccessibilityLabel: Text(verbatim: "Song Preview"),
			previewPlayingValue: Text(verbatim: "Playing"),
			previewStoppedValue: Text(verbatim: "Not Playing"),
			previewFailureMessage: "Sorry, we couldn't play that preview.",
		)
	}
}
