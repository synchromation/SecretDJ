import Foundation
import Testing

@testable import SecretDJKiosk

/// Confirms the kiosk app target, its hosted-test wiring, and the module
/// import all work end to end. Real behavior is covered feature by feature
/// (``KioskSignInModelTests``, ``StaffResetGestureModelTests``,
/// ``StaffResetModelTests``, ``SessionStoreKioskAuthenticatedSessionTests``,
/// ...) — this file no longer constructs ``SecretDJKioskApp`` itself, since
/// S7.1's real `init()` touches production `UserDefaults`/keychain storage
/// (swift-testing skill: unit tests touch no real disk).
struct SecretDJKioskAppTests {
	@Test func `the kiosk app target builds and hosts its own tests`() {
		#expect(Bundle.main.bundleIdentifier?.hasSuffix(".kiosk") == true)
	}
}
