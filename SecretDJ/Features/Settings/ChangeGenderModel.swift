import DesignSystem
import Foundation
import Observability
import Observation
import SecretDJAPI
import SecretDJDomain

/// Drives the change-gender screen (S6.11), reusing
/// ``OnboardingServicing/setGender(userId:gender:credential:)`` directly
/// rather than adding a second seam over the same `setuserdetails` call
/// (ios-architecture: one seam per real endpoint) — the Onboarding feature
/// already models this exact permutation for the Apple sign-in route's
/// gender step (``OnboardingModel/submitGender()``).
///
/// Unlike the Onboarding gender step's select-then-`Continue` flow, this
/// screen submits the instant a gender is tapped and toasts the outcome —
/// ported from the legacy UIKit Settings gender flow, the SwiftUI pilot's
/// own reference for this specific screen never converted
/// (`secretdjv3/SettingsFlowController.swift`'s `didSelectGender(_:)` →
/// `update(gender:)`, toasting `Gender_Changed_Success`/
/// `kGenderConnectionProblemText` and popping on success). No gender is
/// pre-selected, matching the legacy screen's own three stateless buttons
/// (`secretdjv3/LoginGenderViewController.swift`).
///
/// `credential` is captured at init, like ``AccountModel``'s/
/// ``OnboardingModel``'s — this model is only ever constructed while signed
/// in (by `SettingsScreen`), so it never needs to handle "not signed in
/// mid-flow".
@Observable
@MainActor
final class ChangeGenderModel {
	/// The gender last tapped — `nil` until the first tap, then kept
	/// (including through a failed save, so the failed choice stays visibly
	/// highlighted for a retry).
	private(set) var selectedGender: Gender?
	private(set) var isSaving = false
	/// Set once a save succeeds — the view dismisses back to the Settings
	/// hub.
	private(set) var didSucceed = false

	private let personId: String
	private var credential: APICredential
	private let onboardingService: any OnboardingServicing
	private let sessionStore: SessionStore
	private let toastQueue: ToastQueue
	private let observability: ObservabilityPipeline

	init(
		personId: String,
		credential: APICredential,
		onboardingService: any OnboardingServicing,
		sessionStore: SessionStore,
		toastQueue: ToastQueue,
		observability: ObservabilityPipeline = .disabled,
	) {
		self.personId = personId
		self.credential = credential
		self.onboardingService = onboardingService
		self.sessionStore = sessionStore
		self.toastQueue = toastQueue
		self.observability = observability
	}

	/// Submits `gender` immediately via `setuserdetails`. A no-op while a
	/// save is already in flight.
	func selectGender(_ gender: Gender) async {
		guard !isSaving else {
			return
		}

		selectedGender = gender
		observability.interaction("changeGender")
		isSaving = true
		defer { isSaving = false }

		do {
			let outcome = try await onboardingService.setGender(
				userId: personId,
				gender: gender,
				credential: credential,
			)
			// The server may rotate the token on a response that still fails at
			// the ReturnCode level, so this applies regardless of `succeeded` —
			// mirrors `OnboardingModel/submitGender()`'s own reasoning.
			if let rotatedToken = outcome.rotatedToken {
				credential = APICredential(token: rotatedToken, passwordHash: credential.passwordHash)
				sessionStore.rotateToken(rotatedToken)
			}

			if outcome.succeeded {
				observability.track(SettingsEvent.genderChanged)
				toastQueue.enqueue(ToastItem(message: Self.saveSuccessMessage))
				didSucceed = true
			} else {
				observability.track(SettingsEvent.genderChangeFailed)
				toastQueue.enqueue(ToastItem(message: outcome.message ?? Self.saveFailureMessage))
			}
		} catch {
			observability.report(error, category: "Settings")
			observability.track(SettingsEvent.genderChangeFailed)
			toastQueue.enqueue(ToastItem(message: Self.saveFailureMessage))
		}
	}

	private static var saveSuccessMessage: String {
		String(
			localized: "Your gender's been updated.",
			comment: "Toast shown after Settings' change-gender screen saves successfully.",
		)
	}

	private static var saveFailureMessage: String {
		String(
			localized: "Sorry, we couldn't update your gender.\n\nPlease check that you have a good connection to your cellular data or WiFi network.",
			comment: "Fallback toast shown when Settings' change-gender screen fails to save, when the server sent no error copy of its own.",
		)
	}
}
