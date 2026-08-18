/// Persists the secret material (``APICredential``) request signing needs,
/// in the keychain.
///
/// Abstracting storage behind this protocol keeps ``SessionStore`` free of
/// keychain details and lets tests substitute an in-memory store.
@MainActor
public protocol CredentialStoring {
	/// The last credential saved, or `nil` when nothing has been saved (or
	/// it was cleared).
	func savedCredential() -> APICredential?

	/// Replaces the saved credential; pass `nil` to wipe it (sign-out).
	func save(_ credential: APICredential?)
}
