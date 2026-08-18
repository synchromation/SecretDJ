import Foundation
import Observability
import Observation
import SecretDJAPI

/// Drives native sign-in: a screen name and password, SHA-1 hashed
/// client-side for wire compatibility (D7) and handed to
/// ``AuthenticationServicing``. Success signs the shared ``SessionStore``
/// in; failure surfaces a message for the view to show.
@Observable
final class LoginModel {
	private(set) var screenName = ""
	private(set) var password = ""
	private(set) var isSigningIn = false
	private(set) var errorMessage: String?

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

	/// The legacy sign-in gate: a screen name plus a password of at least
	/// five characters (`secretdjv3/LoginViewController.swift`'s
	/// `shouldChangeCharactersIn` handler enables the button at exactly this
	/// threshold).
	var canSignIn: Bool {
		!screenName.isEmpty && password.count >= 5 && !isSigningIn
	}

	func updateScreenName(_ newValue: String) {
		screenName = newValue
	}

	func updatePassword(_ newValue: String) {
		password = newValue
	}

	func signIn() async {
		guard canSignIn else {
			return
		}

		observability.interaction("signIn")
		isSigningIn = true
		errorMessage = nil

		let passwordHash = PasswordHashing.sha1Hex(password)
		do {
			let session = try await authService.signIn(screenName: screenName, passwordHash: passwordHash)
			if !sessionStore.signIn(from: session, passwordHash: passwordHash) {
				handle(.connection)
			}
		} catch {
			handle(error)
		}

		isSigningIn = false
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
			localized: "Sorry, we couldn't sign you in.\n\nPlease check that you have a good connection to your cellular data or WiFi network.",
			comment: "Error shown when native sign-in fails before reaching the server (offline, timeout).",
		)
	}
}
