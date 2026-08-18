import Foundation
import Security
import Testing

@testable import SecretDJAPI

enum KeychainCredentialStoreTests {
	/// `KeychainCredentialQuery`'s dictionaries are plain data — testable
	/// without touching a real keychain, unlike `SecItemAdd`/`SecItemCopyMatching`
	/// themselves, which a sandboxed test run may not have entitlements for.
	struct `Query construction` {
		@Test func `the match query names the generic-password class, service, and account`() {
			let query = KeychainCredentialQuery.match(service: "svc", account: "acct")

			#expect(query[kSecClass as String] as? String == kSecClassGenericPassword as String)
			#expect(query[kSecAttrService as String] as? String == "svc")
			#expect(query[kSecAttrAccount as String] as? String == "acct")
		}

		@Test func `the insert item carries the match query plus the encoded data`() {
			let data = Data("credential".utf8)

			let item = KeychainCredentialQuery.insertItem(service: "svc", account: "acct", data: data)

			#expect(item[kSecClass as String] as? String == kSecClassGenericPassword as String)
			#expect(item[kSecAttrService as String] as? String == "svc")
			#expect(item[kSecAttrAccount as String] as? String == "acct")
			#expect(item[kSecValueData as String] as? Data == data)
		}

		@Test func `the insert item sets an after-first-unlock, this-device-only accessibility policy`() {
			let item = KeychainCredentialQuery.insertItem(service: "svc", account: "acct", data: Data())

			let accessibility = item[kSecAttrAccessible as String] as? String
			#expect(accessibility == kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
		}

		@Test func `the update attributes carry only the encoded data`() {
			let data = Data("credential".utf8)

			let attributes = KeychainCredentialQuery.updateAttributes(data: data)

			#expect(attributes.count == 1)
			#expect(attributes[kSecValueData as String] as? Data == data)
		}
	}
}
