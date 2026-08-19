import SecretDJAPI
import Testing

@testable import SecretDJKiosk

/// Pins ``KioskDeviceImplicitParameterProvider``'s documented seam: no
/// location fix is ever reported yet (its own doc comment explains why —
/// S7.1's scope is the shell, not a new CoreLocation stack), and installed
/// apps default to none, mirroring the consumer's own
/// `DeviceImplicitParameterProvider` until a feature needs otherwise.
struct KioskDeviceImplicitParameterProviderTests {
	@Test func `reports no location`() {
		let provider = KioskDeviceImplicitParameterProvider()

		#expect(provider.location == nil)
	}

	@Test func `reports no installed apps`() {
		let provider = KioskDeviceImplicitParameterProvider()

		#expect(provider.installedApps.isEmpty)
	}
}
