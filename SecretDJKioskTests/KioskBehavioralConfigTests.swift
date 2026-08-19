import Foundation
import Testing

@testable import SecretDJKiosk

/// ``KioskBehavioralConfig`` — derives S7.3's attract/idle timing and the
/// attract URL from a ``SecretDJAPI/SkinManifest``, falling back to
/// legacy's own defaults (`secretdjv3/KioskAppConfig.swift`:
/// `defaultAttractTimeout`/`defaultIdleTimeout`, both 10s) when the venue
/// skin doesn't set a value.
struct KioskBehavioralConfigTests {
	@Test func `reads every field the manifest supplies`() throws {
		let manifest = try SkinManifestFixture.make(properties: [
			1020: "https://example.com/attract.html",
			1021: "120",
			1004: "20",
		])

		let config = KioskBehavioralConfig(manifest: manifest)

		#expect(config.attractURL == URL(string: "https://example.com/attract.html"))
		#expect(config.attractTimeoutSeconds == 120)
		#expect(config.idleTimeoutSeconds == 20)
	}

	@Test func `falls back to legacy's 10 second defaults when the manifest omits timeouts`() throws {
		let manifest = try SkinManifestFixture.make()

		let config = KioskBehavioralConfig(manifest: manifest)

		#expect(config.attractTimeoutSeconds == 10)
		#expect(config.idleTimeoutSeconds == 10)
	}

	@Test func `has no attract URL when the manifest omits one, with no fallback URL`() throws {
		let manifest = try SkinManifestFixture.make()

		let config = KioskBehavioralConfig(manifest: manifest)

		#expect(config.attractURL == nil)
	}
}
