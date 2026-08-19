import Foundation
import Observability
import Observation
import SecretDJAPI

/// Drives the "yes" branch of LEGACY.md business rule 5's out-of-credits
/// funnel: uploading a profile picture in exchange for free credits
/// (`secretdjv3/TuneInViewController.swift`'s `UploadProfilePictureDelegate`
/// extension — "display any response msg to the user which may contain a
/// reward"). Reuses ``OnboardingServicing/uploadAvatar(userId:imageData:credential:)``
/// directly rather than the full ``OnboardingModel`` — this flow has no
/// route/step concept of its own, it's a single one-shot upload reached from
/// the TuneIn screen, not the sign-up sequence.
@MainActor
@Observable
final class AddProfilePictureForCreditsModel {
	private(set) var isSubmitting = false
	private(set) var errorMessage: String?
	/// The server's reward copy from a successful upload, for the view to
	/// toast — mirrors ``OnboardingModel/rewardMessage``'s doc comment.
	private(set) var rewardMessage: String?
	/// Set once an upload has succeeded, so the view knows to dismiss.
	private(set) var didSucceed = false

	private let personId: String
	private var credential: APICredential
	private let onboardingService: any OnboardingServicing
	private let sessionStore: SessionStore
	private let observability: ObservabilityPipeline

	init(
		personId: String,
		credential: APICredential,
		onboardingService: any OnboardingServicing,
		sessionStore: SessionStore,
		observability: ObservabilityPipeline = .disabled,
	) {
		self.personId = personId
		self.credential = credential
		self.onboardingService = onboardingService
		self.sessionStore = sessionStore
		self.observability = observability
	}

	func uploadPhoto(_ imageData: Data) async {
		observability.interaction("uploadProfilePictureForCredits")
		isSubmitting = true
		errorMessage = nil

		do {
			let outcome = try await onboardingService.uploadAvatar(
				userId: personId,
				imageData: imageData,
				credential: credential,
			)
			rotateTokenIfNeeded(outcome.rotatedToken)
			rewardMessage = outcome.rewardMessage
			observability.track(TuneInFunnelUploadEvent.succeeded)
			didSucceed = true
		} catch {
			observability.track(TuneInFunnelUploadEvent.failed)
			handle(error)
		}

		isSubmitting = false
	}

	private func rotateTokenIfNeeded(_ token: String?) {
		guard let token else { return }

		credential = APICredential(token: token, passwordHash: credential.passwordHash)
		sessionStore.rotateToken(token)
	}

	private func handle(_ error: OnboardingError) {
		observability.report(error, category: "TuneIn")

		switch error {
		case .server(let message):
			errorMessage = message ?? Self.fallbackErrorMessage

		case .connection:
			errorMessage = Self.fallbackErrorMessage
		}
	}

	private static var fallbackErrorMessage: String {
		String(
			localized: "Sorry, we couldn't save that.\n\nPlease check that you have a good connection to your cellular data or WiFi network.",
			comment: "Error shown when uploading a profile picture for free credits fails, including before reaching the server.",
		)
	}
}
