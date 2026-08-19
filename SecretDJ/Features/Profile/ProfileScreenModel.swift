import Foundation
import Observability
import Observation
import SecretDJAPI
import SecretDJDomain
import SharedFeatures

/// Drives the profile screen (S6.6, LEGACY.md "Tab 3 — Profile" —
/// `secretdjv3/ProfileFeedViewController.swift`), serving both the
/// signed-in user's own profile (the Profile tab root) and someone else's
/// (reached via ``AppDestination/person(personId:)``) over the same
/// `persondetails` feed. Three things this screen needs beyond
/// ``FeedUI/FeedScreenModel`` itself:
///
/// - **Own-vs-other derivation**: legacy's
///   `person.personId == userManager.currentUser?.personId` check
///   (`secretdjv3/SupplementaryViewProvider.swift`'s
///   `profileSectionHeaderView`), reduced here to ``personId`` (the profile
///   being viewed, known at construction) against the live session's own
///   id — read fresh from ``SecretDJAPI/SessionStore`` rather than captured
///   once, matching every other long-lived S6 screen dependency
///   (`APIClientFeedLoading.sessionFeed`'s doc comment).
/// - **The person's own ``OptimisticLikeModel``**: legacy hides the like
///   button's whole containing view on your own profile (you can't like
///   yourself), so this model never constructs one there — only for
///   someone else's, from the freshest `hiddenProfile` payload the feed
///   loads (initial load, pull-to-refresh), mirroring S6.2's venue-screen
///   reconciliation.
/// - **The avatar-change flow**: own profile only, reusing Onboarding's
///   upload seam (``OnboardingServicing``) exactly like
///   ``AddProfilePictureForCreditsModel`` does for the same `newavatar`
///   call — this screen has no route/step concept of its own, it's a
///   single one-shot upload reached by tapping your own avatar.
@MainActor
@Observable
final class ProfileScreenModel {
	/// The profile being viewed — the session's own id for the tab root, or
	/// whichever id ``AppDestination/person(personId:)`` carries.
	let personId: String

	/// `nil` on ``isOwnProfile`` (you can't like yourself) and before the
	/// first load on someone else's; constructed the first time
	/// ``personDetailsChanged(_:)`` sees a payload, then reconciled (never
	/// replaced) on every later one.
	private(set) var likeModel: OptimisticLikeModel?
	/// Whether an avatar upload is currently in flight — guards
	/// ``uploadAvatar(_:)`` against a second call racing the first, and lets
	/// the view disable the picker.
	private(set) var isUploadingAvatar = false
	/// The server's own error copy from a failed avatar upload, or a
	/// fallback when none was sent; `nil` once a later attempt starts or
	/// succeeds. The view shows this inline in the avatar-change sheet
	/// (mirrors ``AddProfilePictureForCreditsModel/errorMessage``'s doc
	/// comment).
	private(set) var avatarUploadFailureMessage: String?
	/// Set each time an avatar upload succeeds; `nil` until the first one.
	private(set) var avatarUploadEvent: ProfileAvatarUploadEvent?

	private let sessionStore: SessionStore
	private let likeToggling: any LikeToggling
	private let onboardingService: any OnboardingServicing
	private let observability: ObservabilityPipeline

	init(
		personId: String,
		sessionStore: SessionStore,
		likeToggling: any LikeToggling,
		onboardingService: any OnboardingServicing,
		observability: ObservabilityPipeline = .disabled,
	) {
		self.personId = personId
		self.sessionStore = sessionStore
		self.likeToggling = likeToggling
		self.onboardingService = onboardingService
		self.observability = observability
	}

	/// Whether this screen is showing the signed-in user's own profile.
	/// `false` when no one is signed in — a defensive default, since this
	/// screen only ever exists while signed in (ios-architecture: it never
	/// needs to handle a state that can't occur).
	var isOwnProfile: Bool {
		personId == sessionStore.user?.personId
	}

	/// Reconciles ``likeModel`` with the freshest `hiddenProfile` payload —
	/// call whenever ``FeedUI/FeedScreenModel/personDetails`` changes
	/// (initial load, pull-to-refresh). A no-op on ``isOwnProfile`` or with
	/// no payload yet.
	func personDetailsChanged(_ person: Person?) {
		guard !isOwnProfile, let person else {
			return
		}

		if let likeModel {
			likeModel.reconcile(with: person.likeInfo)
		} else {
			likeModel = OptimisticLikeModel(
				itemId: person.personId,
				venueId: nil,
				type: .person,
				likeInfo: person.likeInfo,
				likeToggling: likeToggling,
				observability: observability,
			)
		}
	}

	/// Uploads a newly picked/captured avatar via the same `newavatar` call
	/// Onboarding's photo step uses. A no-op on someone else's profile, or
	/// while ``isUploadingAvatar``. Raises ``avatarUploadEvent`` on success
	/// (the view dismisses the picker, refreshes the feed, and toasts the
	/// server's reward copy when present) or sets
	/// ``avatarUploadFailureMessage`` on failure (shown inline instead, so
	/// the user can retry without losing their place).
	func uploadAvatar(_ imageData: Data) async {
		guard isOwnProfile, !isUploadingAvatar, let credential = sessionStore.credential else {
			return
		}

		isUploadingAvatar = true
		avatarUploadFailureMessage = nil
		defer { isUploadingAvatar = false }

		observability.interaction("changeAvatar")

		do {
			let outcome = try await onboardingService.uploadAvatar(
				userId: personId,
				imageData: imageData,
				credential: credential,
			)
			if let rotatedToken = outcome.rotatedToken {
				sessionStore.rotateToken(rotatedToken)
			}
			observability.track(ProfileEvent.avatarChanged)
			avatarUploadEvent = ProfileAvatarUploadEvent(
				id: (avatarUploadEvent?.id ?? 0) + 1,
				rewardMessage: outcome.rewardMessage,
			)
		} catch {
			observability.report(error, category: "Profile")
			observability.track(ProfileEvent.avatarChangeFailed)
			avatarUploadFailureMessage = message(for: error) ?? Self.fallbackAvatarUploadErrorMessage
		}
	}

	private func message(for error: OnboardingError) -> String? {
		if case .server(let message) = error {
			return message
		}
		return nil
	}

	/// Shared verbatim with ``OnboardingModel``/``AddProfilePictureForCreditsModel``'s
	/// own fallback — the same String Catalog key, not a second one.
	private static var fallbackAvatarUploadErrorMessage: String {
		String(
			localized: "Sorry, we couldn't save that.\n\nPlease check that you have a good connection to your cellular data or WiFi network.",
			comment: "Error shown when uploading a profile picture fails, including before reaching the server.",
		)
	}
}
