import AuthenticationServices
import UIKit

/// The production ``AppleAuthorizing``: an `ASAuthorizationController`
/// driven imperatively, with its delegate callbacks bridged to `async`
/// (legacy `secretdjv3/LoginViewController.swift`, the "Apple Sign in"
/// extension).
@MainActor
final class ASAuthorizationControllerAppleAuthorizing: NSObject, AppleAuthorizing {
	private var continuation: CheckedContinuation<AppleAuthorizationResult, Error>?

	/// Always presents the interactive system sheet — unlike legacy, no
	/// cached-credential-state pre-check short-circuits it.
	func requestSignIn() async throws(AppleAuthorizationError) -> AppleAuthorizationResult {
		do {
			return try await withCheckedThrowingContinuation { continuation in
				let request = ASAuthorizationAppleIDProvider().createRequest()
				request.requestedScopes = [.fullName, .email]

				let controller = ASAuthorizationController(authorizationRequests: [request])
				controller.delegate = self
				controller.presentationContextProvider = self

				self.continuation = continuation
				controller.performRequests()
			}
		} catch let error as AppleAuthorizationError {
			throw error
		} catch {
			throw AppleAuthorizationError.failed
		}
	}
}

extension ASAuthorizationControllerAppleAuthorizing: ASAuthorizationControllerDelegate {
	func authorizationController(
		controller: ASAuthorizationController,
		didCompleteWithAuthorization authorization: ASAuthorization,
	) {
		guard let continuation else { return }
		self.continuation = nil

		guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
			continuation.resume(throwing: AppleAuthorizationError.failed)
			return
		}

		continuation.resume(returning: AppleAuthorizationResult(
			userId: credential.user,
			firstName: credential.fullName?.givenName,
			lastName: credential.fullName?.familyName,
			email: credential.email,
		))
	}

	func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
		guard let continuation else { return }
		self.continuation = nil

		let authorizationError = error as? ASAuthorizationError
		continuation.resume(throwing: authorizationError?.code == .canceled
			? AppleAuthorizationError.cancelled
			: AppleAuthorizationError.failed)
	}
}

extension ASAuthorizationControllerAppleAuthorizing: ASAuthorizationControllerPresentationContextProviding {
	func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
		let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }

		if let keyWindow = windowScenes.flatMap(\.windows).first(where: \.isKeyWindow) {
			return keyWindow
		}

		// No key window to anchor to (should not happen while presenting an
		// interactive sign-in sheet, which requires an active scene) — build
		// a scene-attached window rather than the deprecated `UIWindow()`.
		guard let scene = windowScenes.first else {
			preconditionFailure("No window scene available to anchor Sign in with Apple")
		}
		return UIWindow(windowScene: scene)
	}
}
