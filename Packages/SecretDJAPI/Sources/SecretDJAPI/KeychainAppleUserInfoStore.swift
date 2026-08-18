import Foundation
import Security

/// Stores ``AppleUserInfo`` as a generic password in the keychain (ported
/// from `secretdjv3/KeychainAppleUserInfo.swift`).
///
/// `account` must stay `"aUserInfo"` to match the legacy `APPLEUSERINFOKEY`
/// constant — that's the historical contract for this cache, and keeping it
/// lets any future authorization find pre-existing cached info if ever
/// sharing a keychain with the legacy app.
@MainActor
public struct KeychainAppleUserInfoStore: AppleUserInfoStoring {
	private let service: String
	private let account: String

	public init(service: String = "com.secretdj.applesignin", account: String = "aUserInfo") {
		self.service = service
		self.account = account
	}

	public func savedUserInfo() -> AppleUserInfo? {
		var query = KeychainCredentialQuery.match(service: service, account: account)
		query[kSecMatchLimit as String] = kSecMatchLimitOne
		query[kSecReturnData as String] = kCFBooleanTrue

		var result: AnyObject?
		let status = SecItemCopyMatching(query as CFDictionary, &result)
		guard status == errSecSuccess, let data = result as? Data else {
			return nil
		}
		return try? JSONDecoder().decode(AppleUserInfo.self, from: data)
	}

	public func save(_ userInfo: AppleUserInfo?) {
		let matchQuery = KeychainCredentialQuery.match(service: service, account: account)

		guard let userInfo else {
			SecItemDelete(matchQuery as CFDictionary)
			return
		}

		guard let data = try? JSONEncoder().encode(userInfo) else {
			return
		}

		let updateStatus = SecItemUpdate(
			matchQuery as CFDictionary,
			KeychainCredentialQuery.updateAttributes(data: data) as CFDictionary,
		)
		if updateStatus == errSecItemNotFound {
			let insertItem = KeychainCredentialQuery.insertItem(service: service, account: account, data: data)
			SecItemAdd(insertItem as CFDictionary, nil)
		}
	}
}
