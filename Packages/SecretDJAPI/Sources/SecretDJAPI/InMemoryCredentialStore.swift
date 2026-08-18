/// Holds the credential in memory only — used by tests and previews.
@MainActor
public final class InMemoryCredentialStore: CredentialStoring {
	public private(set) var credential: APICredential?
	/// Every value passed to ``save(_:)``, in call order — lets tests assert
	/// that no write happened, not just what the latest write was.
	public private(set) var saveInvocations: [APICredential?] = []

	public init(credential: APICredential? = nil) {
		self.credential = credential
	}

	public func savedCredential() -> APICredential? {
		credential
	}

	public func save(_ credential: APICredential?) {
		self.credential = credential
		saveInvocations.append(credential)
	}
}
