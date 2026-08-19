/// Raised each time ``ProfileScreenModel/uploadAvatar(_:)`` succeeds; `nil`
/// until the first one. The view observes this to dismiss the avatar-change
/// sheet, refresh the feed (so the header picks up the newly uploaded
/// avatar's URL), and — when ``rewardMessage`` is present — show it as a
/// toast (D11: server copy renders as-delivered verbatim, never re-worded
/// client-side; mirrors ``SharedFeatures/LikeFailureEvent``'s id-based
/// shape).
struct ProfileAvatarUploadEvent: Equatable {
	let id: Int
	let rewardMessage: String?
}
