import Foundation
import Observability
import Observation
import SecretDJAPI
import SecretDJDomain

/// Drives the sign-up details form: first/last name, gender, email, screen
/// name, and password, validated against ``ProfileDetailsValidator`` before
/// `createuser` is called. Success signs the shared ``SessionStore`` in.
///
/// The legacy flow collects gender on its own screen before this one
/// (`secretdjv3/LoginFlowController.swift`'s native route: home → gender →
/// photo → details); this rewrite folds gender into this form instead,
/// since the dedicated gender/photo onboarding screens are S4.5 — `gender`
/// still travels to `createuser` exactly as the server requires.
@Observable
final class SignUpModel {
	private(set) var firstName = ""
	private(set) var lastName = ""
	private(set) var gender: Gender = .unisex
	private(set) var email = ""
	private(set) var screenName = ""
	private(set) var password = ""
	private(set) var isSubmitting = false
	private(set) var errorMessage: String?
	/// Whether ``submit()`` has been called at least once — views use this
	/// to hold back inline field errors until the user has tried to submit.
	private(set) var hasAttemptedSubmit = false
	/// Set once account creation succeeds — the view reacts by pushing
	/// S4.5's onboarding flow, using this to build the right
	/// ``OnboardingRoute``.
	private(set) var onboardingRoute: OnboardingRoute?

	private let authService: any AuthenticationServicing
	private let sessionStore: SessionStore
	private let observability: ObservabilityPipeline

	init(
		authService: any AuthenticationServicing,
		sessionStore: SessionStore,
		observability: ObservabilityPipeline = .disabled,
	) {
		self.authService = authService
		self.sessionStore = sessionStore
		self.observability = observability
	}

	var firstNameError: ProfileFieldValidationError? {
		ProfileDetailsValidator.validate(firstName: firstName)
	}

	var lastNameError: ProfileFieldValidationError? {
		ProfileDetailsValidator.validate(lastName: lastName)
	}

	var emailError: ProfileFieldValidationError? {
		ProfileDetailsValidator.validate(email: email)
	}

	var screenNameError: ProfileFieldValidationError? {
		ProfileDetailsValidator.validate(screenName: screenName)
	}

	var passwordError: ProfileFieldValidationError? {
		ProfileDetailsValidator.validate(password: password)
	}

	var canSubmit: Bool {
		firstNameError == nil
			&& lastNameError == nil
			&& emailError == nil
			&& screenNameError == nil
			&& passwordError == nil
			&& !isSubmitting
	}

	func updateFirstName(_ newValue: String) {
		firstName = newValue
	}

	func updateLastName(_ newValue: String) {
		lastName = newValue
	}

	func updateGender(_ newValue: Gender) {
		gender = newValue
	}

	func updateEmail(_ newValue: String) {
		email = newValue
	}

	func updateScreenName(_ newValue: String) {
		screenName = newValue
	}

	func updatePassword(_ newValue: String) {
		password = newValue
	}

	func submit() async {
		hasAttemptedSubmit = true
		guard canSubmit else {
			return
		}

		observability.interaction("signUp")
		isSubmitting = true
		errorMessage = nil

		let passwordHash = PasswordHashing.sha1Hex(password)
		do {
			let session = try await authService.createUser(
				firstName: firstName,
				lastName: lastName,
				gender: gender,
				email: email,
				screenName: screenName,
				passwordHash: passwordHash,
			)
			if sessionStore.signIn(from: session, passwordHash: passwordHash) {
				observability.track(LoginEvent.accountCreated)
				onboardingRoute = .native
			} else {
				handle(.connection)
			}
		} catch {
			handle(error)
		}

		isSubmitting = false
	}

	private func handle(_ error: AuthenticationError) {
		observability.report(error, category: "Login")

		switch error {
		case .server(let message):
			errorMessage = message ?? Self.connectionErrorMessage

		case .connection:
			errorMessage = Self.connectionErrorMessage
		}
	}

	private static var connectionErrorMessage: String {
		String(
			localized: "Sorry, we couldn't create your account.\n\nPlease check that you have a good connection to your cellular data or WiFi network.",
			comment: "Error shown when sign-up fails before reaching the server (offline, timeout).",
		)
	}
}
