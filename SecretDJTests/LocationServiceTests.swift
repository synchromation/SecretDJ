import Foundation
import Observability
import SecretDJAPI
import Testing

@testable import SecretDJ

/// A mutable box for a fake `now()` clock — a plain `var` local to a test
/// can't be captured by ``LocationService``'s escaping `now` closure, so
/// tests advance time through this instead.
@MainActor
private final class TestClock {
	var date: Date

	init(_ date: Date) {
		self.date = date
	}

	func advance(by seconds: TimeInterval) {
		date = date.addingTimeInterval(seconds)
	}
}

@MainActor
enum LocationServiceTests {
	struct `Starting up` {
		@Test func `reads the provider's initial authorization status`() {
			let provider = InMemoryLocationProviding(authorizationStatus: .authorized)
			let service = LocationService(provider: provider, coordinateBox: LocationCoordinateBox())

			#expect(service.authorizationStatus == .authorized)
		}

		@Test func `has no coordinate before any fix`() {
			let service = LocationService(provider: InMemoryLocationProviding(), coordinateBox: LocationCoordinateBox())

			#expect(service.coordinate == nil)
		}

		@Test func `has no first-fix age before any fix`() {
			let service = LocationService(provider: InMemoryLocationProviding(), coordinateBox: LocationCoordinateBox())

			#expect(service.firstFixAge() == nil)
		}
	}

	struct `Requesting authorization` {
		@Test func `requests when-in-use authorization when not yet determined`() {
			let provider = InMemoryLocationProviding(authorizationStatus: .notDetermined)
			let service = LocationService(provider: provider, coordinateBox: LocationCoordinateBox())

			service.requestAuthorizationIfNeeded()

			#expect(provider.requestWhenInUseAuthorizationCallCount == 1)
		}

		@Test func `does not re-prompt once authorization is already determined`() {
			let provider = InMemoryLocationProviding(authorizationStatus: .authorized)
			let service = LocationService(provider: provider, coordinateBox: LocationCoordinateBox())

			service.requestAuthorizationIfNeeded()

			#expect(provider.requestWhenInUseAuthorizationCallCount == 0)
		}

		@Test func `updates authorization status when the provider reports a change`() {
			let provider = InMemoryLocationProviding(authorizationStatus: .notDetermined)
			let service = LocationService(provider: provider, coordinateBox: LocationCoordinateBox())

			provider.simulateAuthorizationChange(to: .authorized)

			#expect(service.authorizationStatus == .authorized)
		}

		@Test func `refreshing pulls a status change the OS made while the app wasn't listening`() {
			let provider = InMemoryLocationProviding(authorizationStatus: .denied)
			let service = LocationService(provider: provider, coordinateBox: LocationCoordinateBox())
			provider.authorizationStatus = .authorized

			service.refreshAuthorizationStatus()

			#expect(service.authorizationStatus == .authorized)
		}
	}

	struct `Requesting a location` {
		@Test func `requests a fix when authorized`() {
			let provider = InMemoryLocationProviding(authorizationStatus: .authorized)
			let service = LocationService(provider: provider, coordinateBox: LocationCoordinateBox())

			service.requestLocation()

			#expect(provider.requestLocationCallCount == 1)
		}

		@Test func `does not request a fix when authorization is denied`() {
			let provider = InMemoryLocationProviding(authorizationStatus: .denied)
			let service = LocationService(provider: provider, coordinateBox: LocationCoordinateBox())

			service.requestLocation()

			#expect(provider.requestLocationCallCount == 0)
		}

		@Test func `does not request a fix when authorization is still undetermined`() {
			let provider = InMemoryLocationProviding(authorizationStatus: .notDetermined)
			let service = LocationService(provider: provider, coordinateBox: LocationCoordinateBox())

			service.requestLocation()

			#expect(provider.requestLocationCallCount == 0)
		}
	}

	struct `Receiving a fix` {
		@Test func `stores the coordinate the provider delivers`() {
			let provider = InMemoryLocationProviding(authorizationStatus: .authorized)
			let service = LocationService(provider: provider, coordinateBox: LocationCoordinateBox())

			provider.simulateLocationUpdate(LocationCoordinate(latitude: 51.5, longitude: -0.1))

			#expect(service.coordinate == LocationCoordinate(latitude: 51.5, longitude: -0.1))
		}

		@Test func `feeds the coordinate box as an APICoordinate, for the implicit parameter provider`() {
			let box = LocationCoordinateBox()
			let provider = InMemoryLocationProviding(authorizationStatus: .authorized)
			let service = LocationService(provider: provider, coordinateBox: box)

			provider.simulateLocationUpdate(LocationCoordinate(latitude: 51.5, longitude: -0.1))

			#expect(service.coordinate != nil)
			#expect(box.current == APICoordinate(latitude: 51.5, longitude: -0.1))
		}
	}

	struct `Tracking the first fix` {
		@Test func `dates the first fix from the moment it arrives`() {
			let clock = TestClock(Date(timeIntervalSince1970: 1000))
			let provider = InMemoryLocationProviding(authorizationStatus: .authorized)
			let service = LocationService(
				provider: provider,
				coordinateBox: LocationCoordinateBox(),
				now: { clock.date },
			)

			provider.simulateLocationUpdate(LocationCoordinate(latitude: 51.5, longitude: -0.1))
			clock.advance(by: 5)

			#expect(service.firstFixAge() == .seconds(5))
		}

		@Test func `a later fix does not reset the first-fix age`() {
			let clock = TestClock(Date(timeIntervalSince1970: 1000))
			let provider = InMemoryLocationProviding(authorizationStatus: .authorized)
			let service = LocationService(
				provider: provider,
				coordinateBox: LocationCoordinateBox(),
				now: { clock.date },
			)

			provider.simulateLocationUpdate(LocationCoordinate(latitude: 51.5, longitude: -0.1))
			clock.advance(by: 5)
			provider.simulateLocationUpdate(LocationCoordinate(latitude: 51.6, longitude: -0.2))
			clock.advance(by: 5)

			#expect(service.firstFixAge() == .seconds(10))
		}
	}

	/// Instrumentation is behavior and is tested like any other (observability
	/// skill): inject a `RecordingDestination` and assert on emitted events.
	struct Instrumentation {
		@Test func `an authorization change leaves a breadcrumb`() {
			let recorder = RecordingDestination()
			let provider = InMemoryLocationProviding(authorizationStatus: .notDetermined)
			let service = LocationService(
				provider: provider,
				coordinateBox: LocationCoordinateBox(),
				observability: ObservabilityPipeline(destinations: [recorder]),
			)

			provider.simulateAuthorizationChange(to: .authorized)

			#expect(service.authorizationStatus == .authorized)
			#expect(recorder.breadcrumbs == [.interaction(description: "locationAuthorizationChanged")])
		}

		@Test func `reporting the same status again leaves no further breadcrumb`() {
			let recorder = RecordingDestination()
			let provider = InMemoryLocationProviding(authorizationStatus: .authorized)
			let service = LocationService(
				provider: provider,
				coordinateBox: LocationCoordinateBox(),
				observability: ObservabilityPipeline(destinations: [recorder]),
			)

			provider.simulateAuthorizationChange(to: .authorized)

			#expect(service.authorizationStatus == .authorized)
			#expect(recorder.breadcrumbs.isEmpty)
		}

		@Test func `a coordinate never appears in a breadcrumb`() {
			let recorder = RecordingDestination()
			let provider = InMemoryLocationProviding(authorizationStatus: .authorized)
			let service = LocationService(
				provider: provider,
				coordinateBox: LocationCoordinateBox(),
				observability: ObservabilityPipeline(destinations: [recorder]),
			)

			provider.simulateLocationUpdate(LocationCoordinate(latitude: 51.5, longitude: -0.1))

			#expect(service.coordinate != nil)
			#expect(recorder.breadcrumbs.isEmpty)
		}
	}
}
