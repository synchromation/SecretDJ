import DesignSystem
import SecretDJDomain
import SharedFeatures
import SwiftUI

/// The profile screen's header (S6.6) — legacy's `ProfileSectionHeaderView`,
/// trimmed to what this task builds: avatar, screen name, and the like
/// ("buzz") toggle on someone else's profile. Interaction stats
/// (`placesVisited`/`songRequests`/`peopleWhoLikeUser`/last check-in) aren't
/// wired here — they need `Custom.Interactions` decoding S1.3 deferred for
/// lack of a captured fixture (``SecretDJDomain/PersonInteractions``'s doc
/// comment), out of this task's scope.
///
/// Own vs. other mirrors legacy's `SupplementaryViewProvider
/// .profileSectionHeaderView`: your own profile shows a fixed "My Profile"
/// title (never your own screen name) and a tappable avatar for changing
/// your photo; someone else's shows their actual screen name and the like
/// toggle in place of the avatar's change affordance — never both, since
/// you can't like yourself.
struct ProfileHeaderView: View {
	let screenName: String
	let avatarURL: URL?
	let isOwnProfile: Bool
	let likeModel: OptimisticLikeModel?
	let isUploadingAvatar: Bool
	let onChangeAvatar: () -> Void

	@ScaledMetric(relativeTo: .largeTitle)
	private var avatarSize: CGFloat = 96

	var body: some View {
		VStack(spacing: Spacing.medium) {
			avatar

			(isOwnProfile ? Self.ownProfileTitle : Text(verbatim: screenName))
				.font(Theme.TextStyle.sectionHeader.font)
				.foregroundStyle(Theme.ColorRole.primaryText.color)
				.multilineTextAlignment(.center)

			if let likeModel {
				likeButton(likeModel)
			}
		}
		.frame(maxWidth: .infinity)
		.padding(Spacing.large)
		.background(Theme.ColorRole.cellSurface.color)
	}

	@ViewBuilder
	private var avatar: some View {
		if isOwnProfile {
			Button(action: onChangeAvatar) {
				ZStack(alignment: .bottomTrailing) {
					avatarImage
					changePhotoBadge
				}
			}
			.disabled(isUploadingAvatar)
			.accessibilityLabel(Text(
				"Change your profile picture",
				comment: "Accessible name of the profile screen's own avatar, tapped to change your profile picture.",
			))
		} else {
			avatarImage
		}
	}

	private var avatarImage: some View {
		RemoteArtworkView(url: avatarURL, placeholderIcon: .profile, size: avatarSize, shape: .circle)
	}

	private var changePhotoBadge: some View {
		Theme.Icon.changePhoto.image
			.font(.title2)
			.foregroundStyle(Theme.ColorRole.accent.color)
			.background(Theme.ColorRole.cellSurface.color, in: Circle())
			.accessibilityHidden(true)
	}

	private func likeButton(_ likeModel: OptimisticLikeModel) -> some View {
		LikeButton(
			isLiked: likeModel.likeInfo.likedByYou,
			summary: likeModel.likeInfo.info,
			isBusy: likeModel.isToggling,
			accessibilityLabel: Text(
				"Like this person",
				comment: "Accessible name of the profile screen's like/buzz toggle button.",
			),
			action: { Task { await likeModel.toggle() } },
		)
	}

	private static var ownProfileTitle: Text {
		Text(
			"My Profile",
			comment: "Title shown in place of your own screen name on your own profile screen (legacy's fixed \"My Profile\" header).",
		)
	}
}

// MARK: - Previews

#Preview("Own profile") {
	ProfileHeaderView(
		screenName: "TurboTim",
		avatarURL: nil,
		isOwnProfile: true,
		likeModel: nil,
		isUploadingAvatar: false,
		onChangeAvatar: {},
	)
}

#Preview("Own profile, uploading") {
	ProfileHeaderView(
		screenName: "TurboTim",
		avatarURL: nil,
		isOwnProfile: true,
		likeModel: nil,
		isUploadingAvatar: true,
		onChangeAvatar: {},
	)
}

#Preview("Someone else's profile, not liked") {
	ProfileHeaderView(
		screenName: "Someone Else",
		avatarURL: nil,
		isOwnProfile: false,
		likeModel: OptimisticLikeModel(
			itemId: "p2",
			venueId: nil,
			type: .person,
			likeInfo: LikeInfo(likedByYou: false, info: ""),
			likeToggling: InMemoryLikeToggling(),
		),
		isUploadingAvatar: false,
		onChangeAvatar: {},
	)
}

#Preview("Someone else's profile, liked") {
	ProfileHeaderView(
		screenName: "Someone Else",
		avatarURL: nil,
		isOwnProfile: false,
		likeModel: OptimisticLikeModel(
			itemId: "p2",
			venueId: nil,
			type: .person,
			likeInfo: LikeInfo(likedByYou: true, info: "3 people buzzed them"),
			likeToggling: InMemoryLikeToggling(),
		),
		isUploadingAvatar: false,
		onChangeAvatar: {},
	)
}

#Preview("Dark mode") {
	ProfileHeaderView(
		screenName: "Someone Else",
		avatarURL: nil,
		isOwnProfile: false,
		likeModel: OptimisticLikeModel(
			itemId: "p2",
			venueId: nil,
			type: .person,
			likeInfo: LikeInfo(likedByYou: true, info: "3 people buzzed them"),
			likeToggling: InMemoryLikeToggling(),
		),
		isUploadingAvatar: false,
		onChangeAvatar: {},
	)
	.preferredColorScheme(.dark)
}

#Preview("Accessibility text size") {
	ProfileHeaderView(
		screenName: "Someone Else With A Very Long Screen Name",
		avatarURL: nil,
		isOwnProfile: false,
		likeModel: OptimisticLikeModel(
			itemId: "p2",
			venueId: nil,
			type: .person,
			likeInfo: LikeInfo(likedByYou: true, info: "148 people have buzzed them over the last month"),
			likeToggling: InMemoryLikeToggling(),
		),
		isUploadingAvatar: false,
		onChangeAvatar: {},
	)
	.environment(\.dynamicTypeSize, .accessibility5)
}
