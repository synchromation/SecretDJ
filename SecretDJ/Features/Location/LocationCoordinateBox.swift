import SecretDJAPI
import Synchronization

/// The thread-safe bridge from ``LocationService``'s `@MainActor` coordinate
/// state to ``DeviceImplicitParameterProvider/location``, which
/// `APIRequestBuilder` reads synchronously from a nonisolated context on
/// every API call (`SecretDJAPI` sets no default actor isolation). Declared
/// `nonisolated` to opt out of this app module's default main-actor
/// isolation — it must be callable from that nonisolated context — with a
/// `Mutex`-guarded value keeping the crossing safe without an
/// `@unchecked Sendable` shortcut (ios-architecture).
final nonisolated class LocationCoordinateBox: Sendable {
	private let storage = Mutex<APICoordinate?>(nil)

	/// The most recently stored fix, or `nil` before ``update(_:)`` has ever
	/// been called.
	var current: APICoordinate? {
		storage.withLock { $0 }
	}

	func update(_ coordinate: APICoordinate) {
		storage.withLock { $0 = coordinate }
	}
}
