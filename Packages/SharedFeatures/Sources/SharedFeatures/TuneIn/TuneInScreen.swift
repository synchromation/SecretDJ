import DesignSystem
import Observability
import SecretDJDomain
import SwiftUI

/// The song/TuneIn screen (LEGACY.md "Song screen and the request flow
/// (TuneIn)", PLAN.md S6.3b): artwork/title/artist, embedded buzz
/// (``OptimisticLikeModel`` via ``TuneInScreenModel/likeModel``), the
/// request button, and the server-granted skip/never-play moderation
/// buttons. Song previews (S6.4) and "listen elsewhere" (dropped — D12)
/// aren't this screen's concern.
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
		onOutOfCredits: ((Bool) -> Void)? = nil,
		observability: ObservabilityPipeline = .disabled,
	) {
		self.copy = copy
		self.toastQueue = toastQueue
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
		)
	}
}

/// Preview-only ``SecretDJDomain/Song`` fixtures.
enum PreviewSong {
	static var requestable: Song {
		Song(
			songId: "1",
			title: "Yellow",
			artist: "Coldplay",
			previewURL: nil,
			likeInfo: LikeInfo(likedByYou: false, info: ""),
			text: "",
			sortIndex: 0,
			action: nil,
			actions: [Action(
				kind: .jukeboxRequestSong,
				itemId: 1,
				itemTypeId: nil,
				value: nil,
				url: nil,
				button: .unsupported(0),
			)],
		)
	}

	static var moderatable: Song {
		Song(
			songId: "2",
			title: "Clocks",
			artist: "Coldplay",
			previewURL: nil,
			likeInfo: LikeInfo(likedByYou: false, info: ""),
			text: "",
			sortIndex: 0,
			action: nil,
			actions: [
				Action(
					kind: .jukeboxSkipSong,
					itemId: 2,
					itemTypeId: nil,
					value: nil,
					url: nil,
					button: .unsupported(0),
				),
				Action(
					kind: .jukeboxBlacklistSong,
					itemId: 2,
					itemTypeId: nil,
					value: nil,
					url: nil,
					button: .unsupported(0),
				),
			],
		)
	}

	static var liked: Song {
		Song(
			songId: "3",
			title: "Fix You",
			artist: "Coldplay",
			previewURL: nil,
			likeInfo: LikeInfo(likedByYou: true, info: "24 people buzzed this"),
			text: "",
			sortIndex: 0,
			action: nil,
			actions: [Action(
				kind: .jukeboxRequestSong,
				itemId: 3,
				itemTypeId: nil,
				value: nil,
				url: nil,
				button: .unsupported(0),
			)],
		)
	}
}
