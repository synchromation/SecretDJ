/// The result of a `resetpassword` call: whether the server reset the
/// password, and the message to show either way — the server's own copy in
/// both cases (`secretdjv3/PasswordAPIAccess.swift`'s `handleResponse`
/// treats `ReturnCode == 0` as success and any other value plus `Message`
/// as the user-facing failure text; ``SecretDJAPI/APIClient`` never throws
/// on this endpoint's own failure code, only on a failed envelope).
struct PasswordResetOutcome: Equatable {
	let succeeded: Bool
	let message: String?
}
