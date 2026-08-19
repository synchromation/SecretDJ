import Testing

@testable import SharedFeatures

import DesignSystem

/// Coverage for ``MoodTileModel`` — tapping a mood/atmosphere tile
/// (LEGACY.md "Change mood (machine control)"): calls ``AtmosphereChanging``
/// with this screen's default duration, and shows the server's own
/// confirmation copy as a toast on success (PLAN.md S6.3 scope item 1).
enum MoodTileModelTests {
	@MainActor
	struct `Starting up` {
		@Test func `starts idle`() {
			let model = MoodTileModel(
				venueId: "v1",
				atmosphereChanging: InMemoryAtmosphereChanging(),
				toastQueue: ToastQueue(),
			)

			#expect(model.isChanging == false)
		}
	}

	@MainActor
	struct `Changing the atmosphere` {
		@Test func `calls the seam with the tapped tile's item id, this screen's venue, and the default duration`(
		) async {
			let atmosphereChanging = InMemoryAtmosphereChanging()
			let model = MoodTileModel(
				venueId: "v1",
				atmosphereChanging: atmosphereChanging,
				toastQueue: ToastQueue(),
				defaultDurationMinutes: 45,
			)

			await model.changeAtmosphere(itemId: 7)

			#expect(atmosphereChanging.invocations == [
				InMemoryAtmosphereChanging.Invocation(itemId: 7, venueId: "v1", minutes: 45),
			])
		}

		@Test func `a server message on success is queued as a toast`() async {
			let atmosphereChanging = InMemoryAtmosphereChanging(
				result: .success(AtmosphereChangeResult(message: "Playing chilled vibes for the next 30 minutes")),
			)
			let toastQueue = ToastQueue()
			let model = MoodTileModel(venueId: "v1", atmosphereChanging: atmosphereChanging, toastQueue: toastQueue)

			await model.changeAtmosphere(itemId: 7)

			#expect(toastQueue.current?.message == "Playing chilled vibes for the next 30 minutes")
		}

		@Test func `no server message on success queues no toast`() async {
			let atmosphereChanging = InMemoryAtmosphereChanging(result: .success(AtmosphereChangeResult(message: nil)))
			let toastQueue = ToastQueue()
			let model = MoodTileModel(venueId: "v1", atmosphereChanging: atmosphereChanging, toastQueue: toastQueue)

			await model.changeAtmosphere(itemId: 7)

			#expect(toastQueue.current == nil)
		}

		@Test func `a failure queues no toast`() async {
			let atmosphereChanging = InMemoryAtmosphereChanging(result: .failure(.server(message: "Sorry")))
			let toastQueue = ToastQueue()
			let model = MoodTileModel(venueId: "v1", atmosphereChanging: atmosphereChanging, toastQueue: toastQueue)

			await model.changeAtmosphere(itemId: 7)

			#expect(toastQueue.current == nil)
		}

		@Test func `finishes not changing after the call completes`() async {
			let model = MoodTileModel(
				venueId: "v1",
				atmosphereChanging: InMemoryAtmosphereChanging(),
				toastQueue: ToastQueue(),
			)

			await model.changeAtmosphere(itemId: 7)

			#expect(model.isChanging == false)
		}

		@Test func `a second call while one is in flight is a no-op`() async {
			let atmosphereChanging = InMemoryAtmosphereChanging()
			atmosphereChanging.hang()
			let model = MoodTileModel(venueId: "v1", atmosphereChanging: atmosphereChanging, toastQueue: ToastQueue())

			async let first: Void = model.changeAtmosphere(itemId: 7)
			async let second: Void = model.changeAtmosphere(itemId: 8)
			await Task.yield()
			atmosphereChanging.resume(with: .success(AtmosphereChangeResult(message: nil)))
			_ = await (first, second)

			#expect(atmosphereChanging.invocations.count == 1)
		}

		@Test func `isChanging is true while a call is in flight`() async {
			let atmosphereChanging = InMemoryAtmosphereChanging()
			atmosphereChanging.hang()
			let model = MoodTileModel(venueId: "v1", atmosphereChanging: atmosphereChanging, toastQueue: ToastQueue())

			async let change: Void = model.changeAtmosphere(itemId: 7)
			await Task.yield()

			#expect(model.isChanging)
			atmosphereChanging.resume(with: .success(AtmosphereChangeResult(message: nil)))
			await change
			#expect(model.isChanging == false)
		}
	}
}
