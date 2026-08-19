import DesignSystem
import Foundation
import Observability
import Observation
import SecretDJAPI
import SecretDJDomain

/// Drives the change-details form (S6.11, ported from the refactor branch's
/// SwiftUI pilot — `secretdjv3/SwiftUI/Settings/ChangeDetailsScreen.swift`):
/// first/last name, screen name, and email are fetched via `userdetails` on
/// appear, validated by the same ``ProfileDetailsValidator`` rules S4.2's
/// sign-up form uses, and saved via `setuserdetails`. Unlike the pilot's
/// silent pop on success, every outcome — success or failure, server message
/// or a local fallback — is toasted (PLAN.md S6.11's "server outcome copy
/// toasted"), and a successful save additionally syncs
/// ``SecretDJAPI/SessionStore``'s cached screen name, mirroring the pilot's
/// own `userManager.currentUser?.screenName = screenName`.
///
/// `credential` is captured at init, like ``AccountModel``'s/
/// ``OnboardingModel``'s — this model is only ever constructed while signed
/// in (by `SettingsScreen`), so it never needs to handle "not signed in
/// mid-flow".
@Observable
@MainActor
final class ChangeDetailsModel {
	private(set) var firstName = ""
	private(set) var lastName = ""
	private(set) var screenName = ""
	private(set) var email = ""
	private(set) var isLoading = false
	private(set) var isSaving = false
	/// Whether ``save()`` has been called at least once — the view uses this
	/// to hold back inline field errors until the user has tried to submit
	/// (matches ``SignUpModel/hasAttemptedSubmit``'s own reasoning).
	private(set) var hasAttemptedSubmit = false
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

	var firstNameError: ProfileFieldValidationError? {
		ProfileDetailsValidator.validate(firstName: firstName)
	}

	var lastNameError: ProfileFieldValidationError? {
		ProfileDetailsValidator.validate(lastName: lastName)
	}

	var screenNameError: ProfileFieldValidationError? {
		ProfileDetailsValidator.validate(screenName: screenName)
	}

	var emailError: ProfileFieldValidationError? {
		ProfileDetailsValidator.validate(email: email)
	}

	var canSave: Bool {
		!isSaving
			&& firstNameError == nil
			&& lastNameError == nil
			&& screenNameError == nil
			&& emailError == nil
	}

	func updateFirstName(_ newValue: String) {
		firstName = newValue
	}

	func updateLastName(_ newValue: String) {
		lastName = newValue
	}

	func updateScreenName(_ newValue: String) {
		screenName = newValue
	}

	func updateEmail(_ newValue: String) {
		email = newValue
	}

	/// Fetches the signed-in user's current details and prefills every
	/// field.
	///
	/// // S1.3: ``SecretDJDomain/Person/firstName``/``SecretDJDomain/Person/lastName``/
	/// ``SecretDJDomain/Person/email`` always decode `nil` today (a known,
	/// separately tracked gap — see ``SettingsServicing/fetchDetails(userId:credential:)``'s
	/// doc comment), so those three fields prefill empty until it closes;
	/// ``screenName`` is unaffected and prefills correctly.
	func load() async {
		isLoading = true
		defer { isLoading = false }

		do {
			let person = try await settingsService.fetchDetails(userId: personId, credential: credential)
			firstName = person.firstName ?? ""
			lastName = person.lastName ?? ""
			screenName = person.screenName
			email = person.email ?? ""
		} catch {
			observability.report(error, category: "Settings")
			toastQueue.enqueue(ToastItem(message: Self.loadFailureMessage))
		}
	}

	/// Validates and saves every field via `setuserdetails`. A no-op while
	/// any field is invalid or a save is already in flight.
	func save() async {
		hasAttemptedSubmit = true
		guard canSave else {
			return
		}

		observability.interaction("changeDetails")
		isSaving = true
		defer { isSaving = false }

		do {
			let outcome = try await settingsService.changeDetails(
				userId: personId,
				firstName: firstName,
				lastName: lastName,
				screenName: screenName,
				email: email,
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
				sessionStore.updateScreenName(screenName)
				observability.track(SettingsEvent.detailsChanged)
				toastQueue.enqueue(ToastItem(message: nonEmpty(outcome.message) ?? Self.saveSuccessMessage))
				didSucceed = true
			} else {
				observability.track(SettingsEvent.detailsChangeFailed)
				toastQueue.enqueue(ToastItem(message: outcome.message ?? Self.saveFailureMessage))
			}
		} catch {
			observability.report(error, category: "Settings")
			observability.track(SettingsEvent.detailsChangeFailed)
			toastQueue.enqueue(ToastItem(message: Self.saveFailureMessage))
		}
	}

	private func nonEmpty(_ message: String?) -> String? {
		guard let message, !message.isEmpty else {
			return nil
		}
		return message
	}

	private static var loadFailureMessage: String {
		String(
			localized: "Sorry, we couldn't load your details.\n\nPlease check that you have a good connection to your cellular data or WiFi network.",
			comment: "Toast shown when Settings' change-details screen fails to load the signed-in user's current details.",
		)
	}

	private static var saveSuccessMessage: String {
		String(
			localized: "Your details have been updated.",
			comment: "Fallback toast shown after Settings' change-details form saves successfully, when the server sent no confirmation copy of its own.",
		)
	}

	private static var saveFailureMessage: String {
		String(
			localized: "Sorry, we couldn't save your details.\n\nPlease check that you have a good connection to your cellular data or WiFi network.",
			comment: "Fallback toast shown when Settings' change-details form fails to save, when the server sent no error copy of its own.",
		)
	}
}
