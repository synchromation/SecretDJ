import Foundation
import Observability
import Observation
import SecretDJAPI
import SecretDJDomain

/// Drives the post-signup onboarding sequence: the Apple route's gender
/// step, then every route's mandatory photo step (LEGACY.md "Login,
/// sign-up, onboarding" — see ``OnboardingRoute``'s doc comment for exactly
/// which steps apply to which route).
///
/// `credential` is captured at init, not re-read live from ``SessionStore``,
/// and kept in step with it locally via ``SecretDJAPI/SessionStore/rotateToken(_:)``
/// whenever a call returns a fresh token — this model is only ever
/// constructed while signed in (by `RootView`), so it never needs to handle
/// "not signed in mid-flow", a state that can't occur here
/// (ios-architecture).
@Observable
final class OnboardingModel {
	private(set) var route: OnboardingRoute
	private(set) var remainingSteps: [OnboardingStep]
	private(set) var gender: Gender = .unisex
	private(set) var isSubmitting = false
	private(set) var errorMessage: String?
	/// The server's reward copy from a successful avatar upload, for the
	/// view to surface as a toast — cleared by the view once shown isn't
	/// this model's job; it's a one-shot value the view reads via
	/// `onChange`.
	private(set) var rewardMessage: String?

	private let personId: String
	private var credential: APICredential
	private let onboardingService: any OnboardingServicing
	private let sessionStore: SessionStore
	private let observability: ObservabilityPipeline

	init(
		route: OnboardingRoute,
		personId: String,
		credential: APICredential,
		onboardingService: any OnboardingServicing,
		sessionStore: SessionStore,
		observability: ObservabilityPipeline = .disabled,
	) {
		self.route = route
		remainingSteps = route.steps
		self.personId = personId
		self.credential = credential
		self.onboardingService = onboardingService
		self.sessionStore = sessionStore
		self.observability = observability
	}

	/// Whether every step this route needs has been completed.
	var isComplete: Bool {
		remainingSteps.isEmpty
	}

	/// The step currently shown, or `nil` once ``isComplete``.
	var currentStep: OnboardingStep? {
		remainingSteps.first
	}

	func updateGender(_ newValue: Gender) {
		gender = newValue
	}

	/// Submits ``gender`` via `setuserdetails`. A no-op when
	/// ``currentStep`` isn't ``OnboardingStep/genderSelection`` — a light
	/// guard against out-of-order calls, not a state machine, since the
	/// view only ever shows the gender UI while it's current.
	func submitGender() async {
		guard currentStep == .genderSelection else {
			return
		}

		observability.interaction("selectGender")
		isSubmitting = true
		errorMessage = nil

		do {
			let outcome = try await onboardingService.setGender(
				userId: personId,
				gender: gender,
				credential: credential,
			)
			// The server may rotate the token on a response that still fails at
			// the ReturnCode level (envelope Success, non-zero ReturnCode), so
			// this applies regardless of `succeeded` — dropping it here would
			// leave the model signing subsequent calls with a stale token.
			rotateTokenIfNeeded(outcome.rotatedToken)
			if outcome.succeeded {
				remainingSteps.removeFirst()
			} else {
				errorMessage = outcome.message ?? Self.fallbackErrorMessage
			}
		} catch {
			handle(error)
		}

		isSubmitting = false
	}

	/// Uploads `imageData` via `newavatar`. A no-op when ``currentStep``
	/// isn't ``OnboardingStep/photo``.
	func uploadPhoto(_ imageData: Data) async {
		guard currentStep == .photo else {
			return
		}

		observability.interaction("uploadAvatar")
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
			observability.track(OnboardingEvent.avatarUploaded)
			remainingSteps.removeFirst()
		} catch {
			observability.track(OnboardingEvent.avatarUploadFailed)
			handle(error)
		}

		isSubmitting = false
	}

	private func rotateTokenIfNeeded(_ token: String?) {
		guard let token else {
			return
		}

		credential = APICredential(token: token, passwordHash: credential.passwordHash)
		sessionStore.rotateToken(token)
	}

	private func handle(_ error: OnboardingError) {
		observability.report(error, category: "Onboarding")

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
			comment: "Error shown when a step of onboarding (gender or avatar) fails, including before reaching the server.",
		)
	}
}
