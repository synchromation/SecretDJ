import Foundation
import Security

/// The `SecItem*` query dictionaries ``KeychainCredentialStore`` sends to
/// Security.framework — factored out of the store so query construction can
/// be unit tested without touching a real keychain (a sandboxed test run
/// may have no keychain-access entitlement).
enum KeychainCredentialQuery {
	/// Identifies the single keychain item this store owns: a generic
	/// password keyed by `service` + `account`.
	static func match(service: String, account: String) -> [String: Any] {
		[
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: service,
			kSecAttrAccount as String: account,
		]
	}

	/// The attributes for adding a new item: the match query plus its value
	/// and an accessibility policy that survives a device restart once
	/// unlocked once, but never leaves the device.
	static func insertItem(service: String, account: String, data: Data) -> [String: Any] {
		var item = match(service: service, account: account)
		item[kSecValueData as String] = data
		item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
		return item
	}

	/// The attributes for updating an existing item's value in place.
	static func updateAttributes(data: Data) -> [String: Any] {
		[kSecValueData as String: data]
	}
}

/// Stores ``APICredential`` as a generic password in the keychain.
@MainActor
public struct KeychainCredentialStore: CredentialStoring {
	private let service: String
	private let account: String

	public init(service: String = "com.secretdj.session", account: String = "credential") {
		self.service = service
		self.account = account
	}

	public func savedCredential() -> APICredential? {
		var query = KeychainCredentialQuery.match(service: service, account: account)
		query[kSecMatchLimit as String] = kSecMatchLimitOne
		query[kSecReturnData as String] = kCFBooleanTrue

		var result: AnyObject?
		let status = SecItemCopyMatching(query as CFDictionary, &result)
		guard status == errSecSuccess, let data = result as? Data else {
			return nil
		}
		return try? JSONDecoder().decode(APICredential.self, from: data)
	}

	public func save(_ credential: APICredential?) {
		let matchQuery = KeychainCredentialQuery.match(service: service, account: account)

		guard let credential else {
			SecItemDelete(matchQuery as CFDictionary)
			return
		}

		guard let data = try? JSONEncoder().encode(credential) else {
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
