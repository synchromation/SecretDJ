import DesignSystem
import SecretDJDomain
import SharedFeatures
import SwiftUI

/// The venue screen's header (S6.2, extended by S6.8/S6.10) — legacy's
/// `VenueSectionHeaderView`: the venue's name/address, check-in
/// (``CheckInModel``), the like ("buzz") toggle, directions, and the entry
/// point into its now-playing feed. The jukebox button is a legacy header
/// affordance too, but the music-choosing stack it opens landed with S6.3
/// as the feed body itself rather than a header button here.
struct VenueHeaderView: View {
	let venueName: String
	let venueAddress: String?
	let likeModel: OptimisticLikeModel
	let checkInModel: CheckInModel
	let onNowPlaying: () -> Void
	let onDirections: () -> Void

	@Environment(\.dynamicTypeSize) private var dynamicTypeSize

	var body: some View {
		VStack(alignment: .leading, spacing: Spacing.medium) {
			VStack(alignment: .leading, spacing: Spacing.extraSmall) {
				Text(verbatim: venueName)
					.font(Theme.TextStyle.sectionHeader.font)
					.foregroundStyle(Theme.ColorRole.primaryText.color)

				if let venueAddress, !venueAddress.isEmpty {
					Text(verbatim: venueAddress)
						.font(Theme.TextStyle.cellSubtitle.font)
						.foregroundStyle(Theme.ColorRole.secondaryText.color)
				}
			}

			controls
		}
		.padding(Spacing.medium)
		.background(Theme.ColorRole.cellSurface.color)
	}

	@ViewBuilder
	private var controls: some View {
		if dynamicTypeSize.isAccessibilitySize {
			VStack(alignment: .leading, spacing: Spacing.small) {
				checkInButton
				likeButton
				directionsButton
				nowPlayingButton
			}
		} else {
			HStack {
				checkInButton
				Spacer(minLength: Spacing.medium)
				likeButton
				Spacer(minLength: Spacing.medium)
				directionsButton
				Spacer(minLength: Spacing.medium)
				nowPlayingButton
			}
		}
	}

	/// LEGACY.md "Venue screen": "optimistic UI (button disables)" — legacy
	/// never re-enables this button once check-in succeeds, so
	/// ``CheckInModel/checkedIn`` alone (not just ``CheckInModel/isCheckingIn``)
	/// disables it here too. The visible title itself already announces the
	/// state change to VoiceOver; `.isSelected` reinforces it non-verbally
	/// (accessibility skill: "never rely on color alone").
	private var checkInButton: some View {
		Button(
			checkInModel.checkedIn
				? String(
					localized: "Checked In",
					comment: "Title of the venue screen's check-in button once checked in.",
				)
				: String(
					localized: "Check In",
					comment: "Title of the venue screen's check-in button before checking in.",
				),
			systemImage: Theme.Icon.checkIn.systemName,
			action: { Task { await checkInModel.checkIn() } },
		)
		.disabled(checkInModel.checkedIn || checkInModel.isCheckingIn)
		.accessibilityAddTraits(checkInModel.checkedIn ? [.isSelected] : [])
	}

	private var likeButton: some View {
		LikeButton(
			isLiked: likeModel.likeInfo.likedByYou,
			summary: likeModel.likeInfo.info,
			isBusy: likeModel.isToggling,
			accessibilityLabel: Text(
				"Like this venue",
				comment: "Accessible name of the venue screen's like/buzz toggle button.",
			),
			action: { Task { await likeModel.toggle() } },
		)
	}

	private var directionsButton: some View {
		Button(
			"Directions",
			systemImage: Theme.Icon.map.systemName,
			action: onDirections,
		)
	}

	private var nowPlayingButton: some View {
		Button(
			"Now Playing",
			systemImage: Theme.Icon.nowPlaying.systemName,
			action: onNowPlaying,
		)
	}
}

// MARK: - Previews

#Preview("Not liked, not checked in") {
	VenueHeaderView(
		venueName: "The Fox and Hounds",
		venueAddress: "123 High Street, Chiswick, London",
		likeModel: OptimisticLikeModel(
			itemId: "v1",
			venueId: "v1",
			type: .venue,
			likeInfo: LikeInfo(likedByYou: false, info: ""),
			likeToggling: InMemoryLikeToggling(),
		),
		checkInModel: CheckInModel(venueId: "v1", checkedIn: false, checkingIn: InMemoryCheckingIn()),
		onNowPlaying: {},
		onDirections: {},
	)
}

#Preview("No address") {
	VenueHeaderView(
		venueName: "The Fox and Hounds",
		venueAddress: nil,
		likeModel: OptimisticLikeModel(
			itemId: "v1",
			venueId: "v1",
			type: .venue,
			likeInfo: LikeInfo(likedByYou: false, info: ""),
			likeToggling: InMemoryLikeToggling(),
		),
		checkInModel: CheckInModel(venueId: "v1", checkedIn: false, checkingIn: InMemoryCheckingIn()),
		onNowPlaying: {},
		onDirections: {},
	)
}

#Preview("Liked, checked in") {
	VenueHeaderView(
		venueName: "The Fox and Hounds",
		venueAddress: "123 High Street, Chiswick, London",
		likeModel: OptimisticLikeModel(
			itemId: "v1",
			venueId: "v1",
			type: .venue,
			likeInfo: LikeInfo(likedByYou: true, info: "12 people buzzed this"),
			likeToggling: InMemoryLikeToggling(),
		),
		checkInModel: CheckInModel(venueId: "v1", checkedIn: true, checkingIn: InMemoryCheckingIn()),
		onNowPlaying: {},
		onDirections: {},
	)
}

#Preview("Dark mode") {
	VenueHeaderView(
		venueName: "The Fox and Hounds",
		venueAddress: "123 High Street, Chiswick, London",
		likeModel: OptimisticLikeModel(
			itemId: "v1",
			venueId: "v1",
			type: .venue,
			likeInfo: LikeInfo(likedByYou: true, info: "12 people buzzed this"),
			likeToggling: InMemoryLikeToggling(),
		),
		checkInModel: CheckInModel(venueId: "v1", checkedIn: false, checkingIn: InMemoryCheckingIn()),
		onNowPlaying: {},
		onDirections: {},
	)
	.preferredColorScheme(.dark)
}

#Preview("Accessibility text size") {
	VenueHeaderView(
		venueName: "The Fox and Hounds",
		venueAddress: "123 High Street, Chiswick, London",
		likeModel: OptimisticLikeModel(
			itemId: "v1",
			venueId: "v1",
			type: .venue,
			likeInfo: LikeInfo(likedByYou: true, info: "148 people have buzzed this venue over the last month"),
			likeToggling: InMemoryLikeToggling(),
		),
		checkInModel: CheckInModel(venueId: "v1", checkedIn: false, checkingIn: InMemoryCheckingIn()),
		onNowPlaying: {},
		onDirections: {},
	)
	.environment(\.dynamicTypeSize, .accessibility5)
}
