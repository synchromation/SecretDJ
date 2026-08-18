import Testing

@testable import SecretDJAPI

enum APICoordinateTests {
	struct `Wire formatting` {
		/// `"%.6f,%.6f"` — `secretdjv3/NetworkingParameterProvider.swift:88-95`.
		@Test func `formats as six-decimal latitude comma longitude`() {
			let coordinate = APICoordinate(latitude: 51.5, longitude: -0.1)

			#expect(coordinate.queryValue == "51.500000,-0.100000")
		}

		@Test func `rounds to six decimal places`() {
			let coordinate = APICoordinate(latitude: 1.0000005, longitude: 2.0000004)

			#expect(coordinate.queryValue == "1.000001,2.000000")
		}
	}
}
