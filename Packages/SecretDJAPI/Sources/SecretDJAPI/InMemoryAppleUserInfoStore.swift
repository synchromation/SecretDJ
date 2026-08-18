/// Holds the user info in memory only — used by tests and previews.
@MainActor
public final class InMemoryAppleUserInfoStore: AppleUserInfoStoring {
	public private(set) var userInfo: AppleUserInfo?
	/// Every value passed to ``save(_:)``, in call order — lets tests assert
	/// that no write happened, not just what the latest write was.
	public private(set) var saveInvocations: [AppleUserInfo?] = []

	public init(userInfo: AppleUserInfo? = nil) {
		self.userInfo = userInfo
	}

	public func savedUserInfo() -> AppleUserInfo? {
		userInfo
	}

	public func save(_ userInfo: AppleUserInfo?) {
		self.userInfo = userInfo
		saveInvocations.append(userInfo)
	}
}
