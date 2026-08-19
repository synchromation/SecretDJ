/// ``LocationService``s backed by ``InMemoryLocationProviding`` — previews
/// only, never production (previews always inject fakes, per
/// swiftui-views).
enum PreviewLocationService {
	@MainActor
	static func authorized() -> LocationService {
		make(authorizationStatus: .authorized)
	}

	@MainActor
	static func denied() -> LocationService {
		make(authorizationStatus: .denied)
	}

	@MainActor
	static func notDetermined() -> LocationService {
		make(authorizationStatus: .notDetermined)
	}

	@MainActor
	private static func make(authorizationStatus: LocationAuthorizationStatus) -> LocationService {
		LocationService(
			provider: InMemoryLocationProviding(authorizationStatus: authorizationStatus),
			coordinateBox: LocationCoordinateBox(),
		)
	}
}
