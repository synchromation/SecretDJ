import Testing

@testable import SecretDJAPI

enum APIClientConfigurationTests {
	struct `User-Agent construction` {
		/// LEGACY.md "Backend API and Spotify integration" → "Session
		/// config": `"secret dj <idfv>:<screenWidthPx>:<appVersionWithoutDots>"`
		/// (`secretdjv3/NetworkAccess.swift:71-86`).
		@Test func `formats as secret dj idfv:screenWidth:versionWithoutDots`() {
			let configuration = APIClientConfiguration(
				environment: .production,
				deviceIdentifier: "12345678-ABCD-1234-ABCD-1234567890AB",
				screenWidth: 390,
				clientVersion: "5.1.4",
				isKiosk: false,
			)

			#expect(configuration.userAgent == "secret dj 12345678-ABCD-1234-ABCD-1234567890AB:390:514")
		}

		@Test func `strips every dot from a multi-segment version`() {
			let configuration = APIClientConfiguration(
				environment: .production,
				deviceIdentifier: "idfv",
				screenWidth: 100,
				clientVersion: "1.0.0.0",
				isKiosk: false,
			)

			#expect(configuration.userAgent == "secret dj idfv:100:1000")
		}
	}

	struct Headers {
		/// `secretdjv3/NetworkAccess.swift:78-83`.
		@Test func `matches the legacy static header set`() {
			let configuration = APIClientConfiguration(
				environment: .production,
				deviceIdentifier: "idfv",
				screenWidth: 100,
				clientVersion: "1.0",
				isKiosk: false,
			)

			#expect(configuration.headers["Accept"] == "application/json")
			#expect(configuration.headers["Accept-Language"] == "en")
			#expect(configuration.headers["Accept-Encoding"] == "gzip")
			#expect(configuration.headers["User-Agent"] == configuration.userAgent)
		}
	}
}
