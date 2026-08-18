/// Persists the name/email Apple supplies on a user's first Sign in with
/// Apple authorization (``AppleUserInfo``), in the keychain.
///
/// Abstracting storage behind this protocol keeps callers free of keychain
/// details and lets tests substitute an in-memory store.
@MainActor
public protocol AppleUserInfoStoring {
	/// The last user info saved, or `nil` when nothing has been saved (or
	/// it was cleared).
	func savedUserInfo() -> AppleUserInfo?

	/// Replaces the saved user info; pass `nil` to wipe it.
	func save(_ userInfo: AppleUserInfo?)
}
