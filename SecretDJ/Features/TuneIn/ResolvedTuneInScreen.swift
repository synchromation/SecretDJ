import DesignSystem
import FeedUI
import Observability
import SecretDJAPI
import SecretDJDomain
import SharedFeatures
import SwiftUI

/// The real TuneIn screen once a ``SecretDJDomain/Song`` is in hand — the
/// consumer's own wiring over ``SharedFeatures/TuneInScreen``'s seams, plus
/// LEGACY.md business rule 5's out-of-credits funnel, which is entirely
/// this screen's own concern (``SharedFeatures/TuneInScreen/onOutOfCredits``'s
/// doc comment: SharedFeatures owns no consumer-only UI). No profile
/// picture → confirms, then presents ``AddProfilePictureForCreditsScreen``
/// reusing S4.5's avatar components; already has one, or declines → routes
/// to the top-up screen with `noCredits` context (S6.7 renders it as
/// `ComingSoon` until then).
struct ResolvedTuneInScreen: View {
	let song: Song
	let venueId: String
	let apiClient: APIClient
	let sessionStore: SessionStore
	let toastQueue: ToastQueue
	let previewPlayerModel: PreviewPlayerModel
	let router: TabRouter
	let observability: ObservabilityPipeline

	@State private var showsAddPhotoPrompt = false
	@State private var showsAddPhotoSheet = false

	var body: some View {
		TuneInScreen(
			song: song,
			venueId: venueId,
			songRequesting: APIClientSongRequesting(client: apiClient, sessionStore: sessionStore),
			machineControlling: APIClientMachineControlling(client: apiClient, sessionStore: sessionStore),
			likeToggling: APIClientLikeToggling(client: apiClient, sessionStore: sessionStore),
			copy: Self.copy,
			toastQueue: toastQueue,
			previewPlayer: previewPlayerModel,
			onOutOfCredits: handleOutOfCredits,
			showsRichToasts: true,
			observability: observability,
		)
		.alert(Self.addPhotoPromptTitle, isPresented: $showsAddPhotoPrompt) {
			Button(action: showAddPhotoSheet) { Self.addPhotoPromptConfirm }
			Button(role: .cancel, action: routeToTopUps) { Self.addPhotoPromptDecline }
		} message: {
			Self.addPhotoPromptMessage
		}
		.sheet(isPresented: $showsAddPhotoSheet) {
			addPhotoSheet
		}
	}

	private var addPhotoSheet: some View {
		AddProfilePictureForCreditsScreen(
			model: AddProfilePictureForCreditsModel(
				personId: sessionStore.user?.personId ?? "",
				credential: sessionStore.credential ?? APICredential(token: "", passwordHash: ""),
				onboardingService: APIClientOnboardingService(client: apiClient),
				sessionStore: sessionStore,
				observability: observability,
			),
			onSuccess: handleAddPhotoSuccess,
		)
	}

	/// LEGACY.md business rule 5: no profile picture confirms the upsell
	/// first (`secretdjv3/ProfilePicForCreditsViewController.swift`'s
	/// Yes/No dialog); already having one skips straight to the top-up
	/// screen, same as declining.
	private func handleOutOfCredits(hasProfilePicture: Bool) {
		if hasProfilePicture {
			routeToTopUps()
		} else {
			showsAddPhotoPrompt = true
		}
	}

	/// Dismisses the sheet and toasts the server's reward text — "the
	/// re-offer" (SCOPE item 2) is simply landing back on this same TuneIn
	/// screen, whose request button is untouched by an out-of-credits
	/// outcome (``TuneInScreenModel/requestSong()``'s doc comment).
	private func handleAddPhotoSuccess(rewardMessage: String?) {
		showsAddPhotoSheet = false
		if let rewardMessage, !rewardMessage.isEmpty {
			toastQueue.enqueue(ToastItem(message: rewardMessage))
		}
	}

	private func routeToTopUps() {
		router.push(.topUps(context: .noCredits))
	}

	private func showAddPhotoSheet() {
		showsAddPhotoSheet = true
	}

	private static var copy: TuneInScreenCopy {
		TuneInScreenCopy(
			navigationTitle: Text("Tune In", comment: "Navigation title of the song request (TuneIn) screen."),
			requestButtonTitle: Text(
				"Play on the Jukebox",
				comment: "Button that requests the current song be played on the venue's jukebox.",
			),
			skipButtonTitle: Text(
				"Skip",
				comment: "Button, shown only to entitled users, that skips the current song on the jukebox.",
			),
			neverPlayButtonTitle: Text(
				"Never Play This",
				comment: "Button, shown only to entitled users, that stops a song from ever playing on the jukebox again.",
			),
			buzzAccessibilityLabel: Text(
				"Like this song",
				comment: "Accessible name of the TuneIn screen's like/buzz toggle button.",
			),
			previewAccessibilityLabel: Text(
				"Song Preview",
				comment: "Accessible name of the TuneIn screen's play/stop 30-second preview button.",
			),
			previewPlayingValue: Text(
				"Playing",
				comment: "Accessibility value of the TuneIn screen's preview button while the preview is playing.",
			),
			previewStoppedValue: Text(
				"Not Playing",
				comment: "Accessibility value of the TuneIn screen's preview button while no preview is playing.",
			),
			previewFailureMessage: String(
				localized: "Sorry, we couldn't play that preview. Please try again.",
				comment: "Toast shown when a song preview fails to download or decode.",
			),
		)
	}

	/// Money-adjacent copy (credits) stays plain per the tone guide — no
	/// cheekiness here, unlike onboarding's own playful framing.
	private static var addPhotoPromptTitle: Text {
		Text(
			"Add a Profile Picture?",
			comment: "Title of the dialog offering free credits in exchange for a profile picture, shown when a song request runs out of credits.",
		)
	}

	private static var addPhotoPromptMessage: Text {
		Text(
			"Add a profile picture and we'll top up your credits as a thank you.",
			comment: "Body of the dialog offering free credits in exchange for a profile picture.",
		)
	}

	private static var addPhotoPromptConfirm: Text {
		Text(
			"Add a Profile Picture",
			comment: "Confirm button on the dialog offering free credits in exchange for a profile picture.",
		)
	}

	private static var addPhotoPromptDecline: Text {
		Text(
			"Not Now",
			comment: "Decline button on the dialog offering free credits in exchange for a profile picture.",
		)
	}
}

// MARK: - Previews

#Preview("Request granted") {
	NavigationStack {
		ResolvedTuneInScreen(
			song: PreviewSong.requestable,
			venueId: "v1",
			apiClient: PreviewAPIClient.broken(),
			sessionStore: PreviewSessionStore.signedIn(),
			toastQueue: ToastQueue(),
			previewPlayerModel: PreviewPlayerModel(
				downloading: InMemoryPreviewDownloading(),
				playerFactory: InMemoryAudioPlayerFactory(),
			),
			router: TabRouter(),
			observability: .disabled,
		)
	}
}

#Preview("Moderation granted") {
	NavigationStack {
		ResolvedTuneInScreen(
			song: PreviewSong.moderatable,
			venueId: "v1",
			apiClient: PreviewAPIClient.broken(),
			sessionStore: PreviewSessionStore.signedIn(),
			toastQueue: ToastQueue(),
			previewPlayerModel: PreviewPlayerModel(
				downloading: InMemoryPreviewDownloading(),
				playerFactory: InMemoryAudioPlayerFactory(),
			),
			router: TabRouter(),
			observability: .disabled,
		)
	}
}

#Preview("Accessibility text size") {
	NavigationStack {
		ResolvedTuneInScreen(
			song: PreviewSong.requestable,
			venueId: "v1",
			apiClient: PreviewAPIClient.broken(),
			sessionStore: PreviewSessionStore.signedIn(),
			toastQueue: ToastQueue(),
			previewPlayerModel: PreviewPlayerModel(
				downloading: InMemoryPreviewDownloading(),
				playerFactory: InMemoryAudioPlayerFactory(),
			),
			router: TabRouter(),
			observability: .disabled,
		)
	}
	.environment(\.dynamicTypeSize, .accessibility5)
}

/// Preview-only ``SecretDJDomain/Song`` fixtures — mirrors
/// `SharedFeatures`' own `PreviewSong` (package-internal, so this consumer
/// file needs its own copy rather than importing it).
private enum PreviewSong {
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
}
