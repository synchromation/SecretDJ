import Foundation
import Observability
import Observation
import SecretDJAPI

/// Drives the kiosk's venue sign-in: a screen name and password, hashed
/// client-side (D7) exactly like the consumer's own native sign-in
/// (``LoginModel``, `SecretDJ/Features/Login/`) — but with no sign-up,
/// social, or forgotten-password routes (LEGACY.md: kiosk credentials are
/// venue accounts, provisioned out of band and entered once by staff) and
/// no minimum password length, since legacy's kiosk login screen never
/// enforced one (`secretdjv3/KioskLoginViewController.swift`'s `signIn()`
/// only checks both fields are non-empty — unlike the consumer's five-
/// character gate).
@Observable
final class KioskSignInModel {
	private(set) var screenName = ""
	private(set) var password = ""
	private(set) var isSigningIn = false
	private(set) var errorMessage: String?

	private let signInService: any KioskSignInServicing
	private let sessionStore: SessionStore
	private let observability: ObservabilityPipeline

	init(
		signInService: any KioskSignInServicing,
		sessionStore: SessionStore,
		observability: ObservabilityPipeline = .disabled,
	) {
		self.signInService = signInService
		self.sessionStore = sessionStore
		self.observability = observability
	}

	var canSignIn: Bool {
		!screenName.isEmpty && !password.isEmpty && !isSigningIn
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
			let session = try await signInService.signIn(screenName: screenName, passwordHash: passwordHash)
			if !sessionStore.signIn(from: session, passwordHash: passwordHash) {
				handle(.connection)
			}
		} catch {
			handle(error)
		}

		isSigningIn = false
	}

	private func handle(_ error: KioskSignInError) {
		observability.report(error, category: "KioskLogin")

		switch error {
		case .server(let message):
			errorMessage = message ?? Self.connectionErrorMessage

		case .connection:
			errorMessage = Self.connectionErrorMessage

		case .notAVenueAccount:
			errorMessage = Self.notAVenueAccountMessage
		}
	}

	private static var connectionErrorMessage: String {
		String(
			localized: "Sorry, we couldn't sign you in.\n\nPlease check that you have a good connection to your cellular data or WiFi network.",
			comment: "Error shown when kiosk venue sign-in fails before reaching the server (offline, timeout).",
		)
	}

	private static var notAVenueAccountMessage: String {
		String(
			localized: "Sorry, this account isn't set up for a venue.\n\nPlease check your venue sign-in details and try again.",
			comment: "Error shown when the kiosk's credentials authenticate but aren't pinned to a venue (legacy: wrong type of signin).",
		)
	}
}
