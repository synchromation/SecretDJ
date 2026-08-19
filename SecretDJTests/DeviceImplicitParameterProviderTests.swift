import SecretDJAPI
import Testing

@testable import SecretDJ

struct DeviceImplicitParameterProviderTests {
	@Test func `reports no location before the coordinate box has ever been updated`() {
		let provider = DeviceImplicitParameterProvider(coordinateBox: LocationCoordinateBox())

		#expect(provider.location == nil)
	}

	@Test func `reports the coordinate box's most recent fix`() {
		let box = LocationCoordinateBox()
		box.update(APICoordinate(latitude: 51.5, longitude: -0.1))
		let provider = DeviceImplicitParameterProvider(coordinateBox: box)

		#expect(provider.location == APICoordinate(latitude: 51.5, longitude: -0.1))
	}
}
