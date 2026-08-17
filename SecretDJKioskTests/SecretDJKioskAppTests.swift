import Foundation
import Testing

@testable import SecretDJKiosk

// Placeholder coverage for the kiosk app target until S7 lands its real
// composition root; it stands in for feature tests and proves the target,
// its hosted-test wiring, and the module import all work end to end.

struct SecretDJKioskAppTests {
	@Test func `the kiosk app target builds and hosts its own tests`() {
		_ = SecretDJKioskApp()

		#expect(Bundle.main.bundleIdentifier?.hasSuffix(".kiosk") == true)
	}
}
