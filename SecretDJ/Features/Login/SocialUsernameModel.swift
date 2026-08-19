import Foundation
import Observability
import Observation
import SecretDJAPI

/// Drives the post-signup username step shared by the Apple and Facebook
/// sign-up routes — the screen-name-only form that runs before onboarding's
/// remaining steps and isn't ``OnboardingModel``'s job (see
/// ``OnboardingRoute``'s doc comment). Constructed only once
/// ``AppleSignInModel``/``FacebookSignInModel`` has already created and
/// signed in the account, so, like ``OnboardingModel``, it never needs to
/// handle "not signed in mid-flow".
///
/// `credential` is captured at init, not re-read live from
/// ``SessionStore``, and kept in step with it locally via
/// ``SecretDJAPI/SessionStore/rotateToken(_:)`` whenever a call returns a
/// fresh token (see ``OnboardingModel``'s doc comment for why).
@Observable
final class SocialUsernameModel {
	private(set) var screenName = ""
	private(set) var isSubmitting = false
	private(set) var errorMessage: String?
	/// Whether ``submit()`` has been called at least once — the view holds
	/// back the inline field error until the user has tried to submit
	/// (mirrors ``SignUpModel``).
	private(set) var hasAttemptedSubmit = false
	/// Set once the screen name is saved — the view reacts to this to
	/// finish the step (mirrors ``SignUpModel/onboardingRoute``).
	private(set) var isComplete = false

	private let personId: String
	private var credential: APICredential
	private let usernameService: any SocialUsernameServicing
	private let sessionStore: SessionStore
	private let observability: ObservabilityPipeline

	init(
		personId: String,
		credential: APICredential,
		usernameService: any SocialUsernameServicing,
		sessionStore: SessionStore,
		observability: ObservabilityPipeline = .disabled,
	) {
		self.personId = personId
		self.credential = credential
		self.usernameService = usernameService
		self.sessionStore = sessionStore
		self.observability = observability
	}

	var screenNameError: ProfileFieldValidationError? {
		ProfileDetailsValidator.validate(screenName: screenName)
	}

	var canSubmit: Bool {
		screenNameError == nil && !isSubmitting
	}

	func updateScreenName(_ newValue: String) {
		screenName = newValue
	}

	func submit() async {
		hasAttemptedSubmit = true
		guard canSubmit else {
			return
		}

		observability.interaction("setSocialScreenName")
		isSubmitting = true
		errorMessage = nil

		do {
			let outcome = try await usernameService.setScreenName(
				userId: personId,
				screenName: screenName,
				credential: credential,
			)
			rotateTokenIfNeeded(outcome.rotatedToken)
			if outcome.succeeded {
				isComplete = true
			} else {
				errorMessage = outcome.message ?? Self.fallbackErrorMessage
			}
		} catch {
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

	private func handle(_ error: AuthenticationError) {
		observability.report(error, category: "Login")

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
			comment: "Error shown when saving the post-signup username step's screen name fails, including before reaching the server.",
		)
	}
}
