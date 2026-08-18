/// One completed Sign in with Apple authorization: the stable Apple user
/// id, plus name/email — present only on Apple's first authorization for
/// this account (LEGACY.md "Login, sign-up, onboarding": "first-auth
/// name/email are cached in the keychain... because Apple only supplies
/// them once").
struct AppleAuthorizationResult: Equatable {
	let userId: String
	let firstName: String?
	let lastName: String?
	let email: String?
}
