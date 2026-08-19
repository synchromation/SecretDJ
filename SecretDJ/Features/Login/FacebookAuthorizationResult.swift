import SecretDJDomain

/// One completed Facebook Login SDK authorization: the Facebook user id and
/// access token `facebooksignin` needs, plus the Graph `me` profile fields
/// the legacy client fetches on every sign-in attempt — never cached, unlike
/// ``AppleAuthorizationResult``'s first-authorization-only name/email
/// (LEGACY.md "Facebook Login": Graph `me` request for `gender, first_name,
/// last_name, email`).
struct FacebookAuthorizationResult: Equatable {
	let facebookUserId: String
	let accessToken: String
	let gender: Gender?
	let firstName: String?
	let lastName: String?
	let email: String?
}
