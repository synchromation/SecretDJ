import Foundation
import SecretDJAPI
import SecretDJDomain

/// The post-signup profile calls ``OnboardingModel`` needs, thinned from
/// ``SecretDJAPI/APIClient`` to this feature's exact surface
/// (ios-architecture: a protocol seam per real dependency) — kept separate
/// from ``AuthenticationServicing`` because these calls run against an
/// already signed-in session (`setuserdetails`/`newavatar`), not the
/// sign-in/sign-up handshake itself.
protocol OnboardingServicing: Sendable {
	/// `setuserdetails` with just `gender` — the Apple route's gender step.
	func setGender(
		userId: String,
		gender: Gender,
		credential: APICredential,
	) async throws(OnboardingError) -> OnboardingUpdateOutcome

	/// `newavatar` — `imageData` is already-downscaled, already-encoded
	/// JPEG bytes (``AvatarImageProcessing``).
	func uploadAvatar(
		userId: String,
		imageData: Data,
		credential: APICredential,
	) async throws(OnboardingError) -> AvatarUploadOutcome
}

/// Every way an ``OnboardingServicing`` call can fail — same shape as
/// ``AuthenticationError``, kept as its own type since the two protocols
/// are deliberately separate seams.
enum OnboardingError: Error, Equatable {
	case server(message: String?)
	case connection

	init(_ apiError: APIError) {
		if case .server(let message) = apiError {
			self = .server(message: message)
		} else {
			self = .connection
		}
	}
}

/// ``OnboardingServicing/setGender(userId:gender:credential:)``'s outcome.
struct OnboardingUpdateOutcome: Equatable {
	let succeeded: Bool
	let message: String?
	/// The server's freshly issued token, when the response carried one —
	/// feed to ``SecretDJAPI/SessionStore/rotateToken(_:)``.
	let rotatedToken: String?
}

/// ``OnboardingServicing/uploadAvatar(userId:imageData:credential:)``'s
/// outcome.
struct AvatarUploadOutcome: Equatable {
	/// The server's reward/confirmation copy, already localized (D11), when
	/// present.
	let rewardMessage: String?
	let rotatedToken: String?
}
