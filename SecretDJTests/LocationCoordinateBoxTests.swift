import SecretDJAPI
import Testing

@testable import SecretDJ

struct LocationCoordinateBoxTests {
	@Test func `has no coordinate before any update`() {
		let box = LocationCoordinateBox()

		#expect(box.current == nil)
	}

	@Test func `returns the coordinate from the most recent update`() {
		let box = LocationCoordinateBox()

		box.update(APICoordinate(latitude: 51.5, longitude: -0.1))
		box.update(APICoordinate(latitude: 40.7, longitude: -74.0))

		#expect(box.current == APICoordinate(latitude: 40.7, longitude: -74.0))
	}
}
