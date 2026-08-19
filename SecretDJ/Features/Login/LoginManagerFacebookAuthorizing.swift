import FacebookCore
import FacebookLogin
import SecretDJDomain

/// The production ``FacebookAuthorizing``: `LoginManager` for the login UI,
/// then a Graph `me` request for the profile fields `facebooksignin` needs
/// (LEGACY.md "Facebook Login": permissions `public_profile, email`; Graph
/// `me` fields `gender, first_name, last_name, email`,
/// `secretdjv3/FacebookManager.swift`).
@MainActor
final class LoginManagerFacebookAuthorizing: FacebookAuthorizing {
	private let loginManager = LoginManager()

	func requestSignIn() async throws(FacebookAuthorizationError) -> FacebookAuthorizationResult {
		let credential: (userId: String, accessToken: String)
		do {
			credential = try await login()
		} catch let error as FacebookAuthorizationError {
			throw error
		} catch {
			throw FacebookAuthorizationError.failed
		}

		do {
			return try await profile(facebookUserId: credential.userId, accessToken: credential.accessToken)
		} catch {
			throw FacebookAuthorizationError.failed
		}
	}

	/// Presents the Facebook login flow with `nil` for the presenting view
	/// controller — the SDK determines the topmost one itself, matching
	/// `ASAuthorizationControllerAppleAuthorizing`'s equivalent lookup
	/// without duplicating it here. Returns only the two `String` fields the
	/// rest of this adapter needs, not the SDK's `AccessToken` object
	/// itself, which isn't `Sendable` and can't safely cross the
	/// continuation back onto the calling task.
	private func login() async throws -> (userId: String, accessToken: String) {
		try await withCheckedThrowingContinuation { continuation in
			loginManager.logIn(permissions: ["public_profile", "email"], from: nil) { result, error in
				if error != nil {
					continuation.resume(throwing: FacebookAuthorizationError.failed)
					return
				}

				guard let result, !result.isCancelled else {
					continuation.resume(throwing: FacebookAuthorizationError.cancelled)
					return
				}

				guard let token = result.token else {
					continuation.resume(throwing: FacebookAuthorizationError.failed)
					return
				}

				continuation.resume(returning: (userId: token.userID, accessToken: token.tokenString))
			}
		}
	}

	/// Fetches the Graph `me` fields for whichever account `LoginManager`
	/// just signed in — implicitly `AccessToken.current`, the token the SDK
	/// itself just set, so this needs no `AccessToken` reference of its own.
	private func profile(facebookUserId: String, accessToken: String) async throws -> FacebookAuthorizationResult {
		try await withCheckedThrowingContinuation { continuation in
			let request = GraphRequest(graphPath: "me", parameters: ["fields": "gender,first_name,last_name,email"])
			request.start { _, result, error in
				if let error {
					continuation.resume(throwing: error)
					return
				}

				let fields = result as? [String: Any]
				continuation.resume(returning: FacebookAuthorizationResult(
					facebookUserId: facebookUserId,
					accessToken: accessToken,
					gender: (fields?["gender"] as? String).flatMap(Gender.init(facebookGraphValue:)),
					firstName: fields?["first_name"] as? String,
					lastName: fields?["last_name"] as? String,
					email: fields?["email"] as? String,
				))
			}
		}
	}
}

extension Gender {
	/// Maps the Graph API's `gender` field ("male"/"female"; omitted when
	/// the person hasn't set one or Facebook restricts it) to the app's
	/// domain type — no `.unisex` mapping exists on the wire, so anything
	/// else comes through as `nil` rather than a guessed default.
	fileprivate init?(facebookGraphValue: String) {
		switch facebookGraphValue {
		case "male":
			self = .male

		case "female":
			self = .female

		default:
			return nil
		}
	}
}
