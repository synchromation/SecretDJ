import Foundation
import Observability
import Observation

/// Drives the forgotten-password flow: one input the user types their
/// screen name or email into, `resetpassword` decides which it was
/// server-side, so the client only needs to route the request — an `@`
/// means email (legacy split this into two fields and preferred email when
/// both were filled in; `secretdjv3/LoginForgottenPasswordViewController.swift`).
@Observable
final class ForgottenPasswordModel {
	private(set) var input = ""
	private(set) var isSubmitting = false
	/// The message to show after a submission: the server's own copy on
	/// both success and failure
	/// (`secretdjv3/PasswordAPIAccess.swift`'s `handleResponse`), or a local
	/// fallback when the server sent none.
	private(set) var resultMessage: String?
	private(set) var didSucceed = false

	private let authService: any AuthenticationServicing
	private let observability: ObservabilityPipeline

	init(authService: any AuthenticationServicing, observability: ObservabilityPipeline = .disabled) {
		self.authService = authService
		self.observability = observability
	}

	var canSubmit: Bool {
		!input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSubmitting
	}

	func updateInput(_ newValue: String) {
		input = newValue
	}

	func submit() async {
		guard canSubmit else {
			return
		}

		observability.interaction("resetPassword")
		isSubmitting = true
		resultMessage = nil

		do {
			let outcome =
				if input.contains("@") {
					try await authService.resetPassword(email: input)
				} else {
					try await authService.resetPassword(screenName: input)
				}
			didSucceed = outcome.succeeded
			resultMessage = outcome.message?.isEmpty == false ? outcome.message : Self
				.fallbackMessage(succeeded: outcome.succeeded)
			if !outcome.succeeded {
				observability.log(.warning, "resetpassword returned a non-zero ReturnCode", category: "Login")
			}
		} catch {
			didSucceed = false
			observability.report(error, category: "Login")
			resultMessage = Self.connectionErrorMessage
		}

		isSubmitting = false
	}

	private static func fallbackMessage(succeeded: Bool) -> String {
		guard succeeded else {
			return connectionErrorMessage
		}

		return String(
			localized: "We've sent you instructions on resetting your password.",
			comment: "Fallback confirmation shown after a password reset request succeeds with no message from the server.",
		)
	}

	private static var connectionErrorMessage: String {
		String(
			localized: "Sorry, we couldn't reset your password.\n\nPlease check that you have a good connection to your cellular data or WiFi network.",
			comment: "Error shown when a password reset request fails before reaching the server (offline, timeout).",
		)
	}
}
