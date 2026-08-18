/// The identity Apple supplies on a user's *first* Sign in with Apple
/// authorization for this app (LEGACY.md "Login, sign-up, onboarding" →
/// "Sign in with Apple (`applesignin`): first-auth name/email are cached in
/// the keychain ... because Apple only supplies them once").
///
/// `Codable` so ``KeychainAppleUserInfoStore`` can persist it as-is.
public struct AppleUserInfo: Sendable, Hashable, Codable {
	public let appleUserId: String
	public let firstName: String
	public let lastName: String
	public let email: String

	public init(appleUserId: String, firstName: String, lastName: String, email: String) {
		self.appleUserId = appleUserId
		self.firstName = firstName
		self.lastName = lastName
		self.email = email
	}
}
