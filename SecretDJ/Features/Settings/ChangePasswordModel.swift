import DesignSystem
import Foundation
import Observability
import Observation
import SecretDJAPI

/// Drives the change-password form (S6.11, ported from the refactor
/// branch's SwiftUI pilot — `secretdjv3/SwiftUI/Settings/ChangePasswordScreen.swift`):
/// the current password is checked locally against
/// ``SecretDJAPI/APICredential/passwordHash`` (never sent to the server —
/// the pilot's own `ProfileDetailsValidator.validate(oldPassword:storedPassword:)`
/// check against `UserManager.password`), the new password is validated by
/// the same ``ProfileDetailsValidator/validate(password:)`` rule S4.2's
/// sign-up form uses (≥5 characters) and sent as its SHA-1 hash, never
/// plaintext (S1.2's wire-compatibility requirement). Every outcome —
/// success or failure — is toasted, matching ``ChangeDetailsModel``'s own
/// "server outcome copy toasted" behavior (PLAN.md S6.11); a successful save
/// additionally updates ``SecretDJAPI/SessionStore``'s cached password hash,
/// mirroring the pilot's own `userManager.password = hashedPassword`.
///
/// `credential` is captured at init, like ``AccountModel``'s/
/// ``OnboardingModel``'s — this model is only ever constructed while signed
/// in (by `SettingsScreen`), so it never needs to handle "not signed in
/// mid-flow".
@Observable
@MainActor
final class ChangePasswordModel {
	private(set) var currentPassword = ""
	private(set) var newPassword = ""
	private(set) var isSaving = false
	/// Whether ``save()`` has been called at least once — the view uses this
	/// to hold back the inline new-password error until the user has tried
	/// to submit (matches ``SignUpModel/hasAttemptedSubmit``'s own
	/// reasoning).
	private(set) var hasAttemptedSubmit = false
	/// Set when ``save()``'s local check finds ``currentPassword`` doesn't
	/// match the stored hash — cleared as soon as the field changes again.
	private(set) var currentPasswordIsIncorrect = false
	/// Set once a save succeeds — the view dismisses back to the Settings
	/// hub.
	private(set) var didSucceed = false

	private let personId: String
	private var credential: APICredential
	private let settingsService: any SettingsServicing
	private let sessionStore: SessionStore
	private let toastQueue: ToastQueue
	private let observability: ObservabilityPipeline

	init(
		personId: String,
		credential: APICredential,
		settingsService: any SettingsServicing,
		sessionStore: SessionStore,
		toastQueue: ToastQueue,
		observability: ObservabilityPipeline = .disabled,
	) {
		self.personId = personId
		self.credential = credential
		self.settingsService = settingsService
		self.sessionStore = sessionStore
		self.toastQueue = toastQueue
		self.observability = observability
	}

	var newPasswordError: ProfileFieldValidationError? {
		ProfileDetailsValidator.validate(password: newPassword)
	}

	var canSave: Bool {
		!isSaving && !currentPassword.isEmpty && newPasswordError == nil
	}

	func updateCurrentPassword(_ newValue: String) {
		currentPassword = newValue
		currentPasswordIsIncorrect = false
	}

	func updateNewPassword(_ newValue: String) {
		newPassword = newValue
	}

	/// Checks ``currentPassword`` locally, then validates and saves
	/// ``newPassword`` via `setuserdetails`. A no-op while either field is
	/// invalid or a save is already in flight.
	func save() async {
		hasAttemptedSubmit = true
		guard canSave else {
			return
		}

		guard PasswordHashing.sha1Hex(currentPassword) == credential.passwordHash else {
			currentPasswordIsIncorrect = true
			return
		}

		observability.interaction("changePassword")
		isSaving = true
		defer { isSaving = false }

		let newPasswordHash = PasswordHashing.sha1Hex(newPassword)
		do {
			let outcome = try await settingsService.changePassword(
				userId: personId,
				newPasswordHash: newPasswordHash,
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
				credential = APICredential(token: credential.token, passwordHash: newPasswordHash)
				sessionStore.updatePasswordHash(newPasswordHash)
				observability.track(SettingsEvent.passwordChanged)
				toastQueue.enqueue(ToastItem(message: nonEmpty(outcome.message) ?? Self.saveSuccessMessage))
				didSucceed = true
			} else {
				observability.track(SettingsEvent.passwordChangeFailed)
				toastQueue.enqueue(ToastItem(message: outcome.message ?? Self.saveFailureMessage))
			}
		} catch {
			observability.report(error, category: "Settings")
			observability.track(SettingsEvent.passwordChangeFailed)
			toastQueue.enqueue(ToastItem(message: Self.saveFailureMessage))
		}
	}

	private func nonEmpty(_ message: String?) -> String? {
		guard let message, !message.isEmpty else {
			return nil
		}
		return message
	}

	private static var saveSuccessMessage: String {
		String(
			localized: "Your password has been updated.",
			comment: "Fallback toast shown after Settings' change-password form saves successfully, when the server sent no confirmation copy of its own.",
		)
	}

	private static var saveFailureMessage: String {
		String(
			localized: "Sorry, we couldn't update your password.\n\nPlease check that you have a good connection to your cellular data or WiFi network.",
			comment: "Fallback toast shown when Settings' change-password form fails to save, when the server sent no error copy of its own.",
		)
	}
}
