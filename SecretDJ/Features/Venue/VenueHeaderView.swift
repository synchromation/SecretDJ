import DesignSystem
import SecretDJDomain
import SwiftUI

/// The venue screen's header (S6.2) — legacy's `VenueSectionHeaderView`,
/// trimmed to what this task builds: the venue's name/address, the like
/// ("buzz") toggle, and the entry point into its now-playing feed. Check-in,
/// directions, and the jukebox button are legacy header affordances too, but
/// land with their own S6 tasks (S6.8, S6.10, S6.3) rather than here.
struct VenueHeaderView: View {
	let venueName: String
	let venueAddress: String?
	let likeModel: OptimisticLikeModel
	let onNowPlaying: () -> Void

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
				likeButton
				nowPlayingButton
			}
		} else {
			HStack {
				likeButton
				Spacer(minLength: Spacing.medium)
				nowPlayingButton
			}
		}
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

	private var nowPlayingButton: some View {
		Button(
			"Now Playing",
			systemImage: Theme.Icon.nowPlaying.systemName,
			action: onNowPlaying,
		)
	}
}

// MARK: - Previews

#Preview("Not liked") {
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
		onNowPlaying: {},
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
		onNowPlaying: {},
	)
}

#Preview("Liked") {
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
		onNowPlaying: {},
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
		onNowPlaying: {},
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
		onNowPlaying: {},
	)
	.environment(\.dynamicTypeSize, .accessibility5)
}
