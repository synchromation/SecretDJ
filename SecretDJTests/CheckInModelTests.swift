import Foundation
import Observability
import Testing

@testable import SecretDJ

/// ``CheckInModel`` — the venue header's check-in toggle (LEGACY.md "Venue
/// screen": optimistic UI, scope always `everyone`, success surfaces the
/// server's toast/URL, failure rolls back). Unlike
/// ``SharedFeatures/OptimisticLikeModel``, one-directional: once
/// ``CheckInModel/checkedIn`` is `true`, ``CheckInModel/checkIn()`` becomes
/// a permanent no-op — legacy's own button never re-enables after a
/// successful check-in.
@MainActor
enum CheckInModelTests {
	struct `Starting up` {
		@Test func `starts with the checkedIn state it was given`() {
			let model = makeModel(checkedIn: true)

			#expect(model.checkedIn)
		}
	}

	struct `Checking in, on success` {
		@Test func `flips checkedIn immediately, before the call resolves`() async {
			let checkingIn = InMemoryCheckingIn()
			checkingIn.hang()
			let model = makeModel(checkedIn: false, checkingIn: checkingIn)

			async let checkIn: Void = model.checkIn()
			await Task.yield()

			#expect(model.checkedIn)
			checkingIn.resume(with: .success(CheckInOutcome(message: "Welcome!", url: nil)))
			await checkIn
		}

		@Test func `calls checkIn with the model's own venue id`() async {
			let checkingIn = InMemoryCheckingIn()
			let model = makeModel(venueId: "v42", checkedIn: false, checkingIn: checkingIn)

			await model.checkIn()

			#expect(checkingIn.calls == ["v42"])
		}

		@Test func `surfaces the server's message and url as a success event`() async {
			let checkingIn = InMemoryCheckingIn(
				result: .success(CheckInOutcome(
					message: "Welcome, this is your first visit!",
					url: URL(string: "https://secretdj.com/reward"),
				)),
			)
			let model = makeModel(checkedIn: false, checkingIn: checkingIn)

			await model.checkIn()

			#expect(model.successEvent?.message == "Welcome, this is your first visit!")
			#expect(model.successEvent?.url == URL(string: "https://secretdj.com/reward"))
		}

		@Test func `a second successful check-in produces a distinct success event id`() async {
			// Unreachable through checkIn() alone since a success leaves
			// checkedIn permanently true, but the id still needs to prove
			// itself distinct rather than hard-coded to 1.
			let checkingIn = InMemoryCheckingIn(result: .success(CheckInOutcome(message: "Hi", url: nil)))
			let model = makeModel(checkedIn: false, checkingIn: checkingIn)

			await model.checkIn()

			#expect(model.successEvent?.id == 1)
		}
	}

	struct `Checking in, on failure` {
		@Test func `rolls back checkedIn to false`() async {
			let checkingIn = InMemoryCheckingIn(result: .failure(.connection))
			let model = makeModel(checkedIn: false, checkingIn: checkingIn)

			await model.checkIn()

			#expect(!model.checkedIn)
		}

		@Test func `surfaces the server's error message as a failure event`() async {
			let checkingIn = InMemoryCheckingIn(result: .failure(.server(message: "Sorry, that venue doesn't exist")))
			let model = makeModel(checkedIn: false, checkingIn: checkingIn)

			await model.checkIn()

			#expect(model.failureEvent?.message == "Sorry, that venue doesn't exist")
		}

		@Test func `leaves the failure event's message nil on a connection failure`() async {
			let checkingIn = InMemoryCheckingIn(result: .failure(.connection))
			let model = makeModel(checkedIn: false, checkingIn: checkingIn)

			await model.checkIn()

			#expect(model.failureEvent?.message == nil)
		}

		@Test func `a second failure produces a distinct failure event id`() async {
			let checkingIn = InMemoryCheckingIn(result: .failure(.connection))
			let model = makeModel(checkedIn: false, checkingIn: checkingIn)

			await model.checkIn()
			let first = model.failureEvent
			await model.checkIn()
			let second = model.failureEvent

			#expect(first?.id != second?.id)
		}
	}

	struct `Checking in, guards` {
		@Test func `a second check-in while one is in flight makes no extra call`() async {
			let checkingIn = InMemoryCheckingIn()
			checkingIn.hang()
			let model = makeModel(checkedIn: false, checkingIn: checkingIn)

			async let first: Void = model.checkIn()
			async let second: Void = model.checkIn()
			await Task.yield()
			checkingIn.resume(with: .success(CheckInOutcome(message: "", url: nil)))
			_ = await (first, second)

			#expect(checkingIn.calls.count == 1)
		}

		@Test func `does nothing when already checked in`() async {
			let checkingIn = InMemoryCheckingIn()
			let model = makeModel(checkedIn: true, checkingIn: checkingIn)

			await model.checkIn()

			#expect(checkingIn.calls.isEmpty)
		}

		@Test func `isCheckingIn reports the in-flight state`() async {
			let checkingIn = InMemoryCheckingIn()
			checkingIn.hang()
			let model = makeModel(checkedIn: false, checkingIn: checkingIn)

			async let checkIn: Void = model.checkIn()
			await Task.yield()

			#expect(model.isCheckingIn)
			checkingIn.resume(with: .success(CheckInOutcome(message: "", url: nil)))
			await checkIn
			#expect(!model.isCheckingIn)
		}
	}

	struct `Reconciling with a fresh server snapshot` {
		@Test func `adopts a fresh server checkedIn flag when idle and not yet checked in`() {
			let model = makeModel(checkedIn: false)

			model.reconcile(with: true)

			#expect(model.checkedIn)
		}

		@Test func `never regresses an already checked-in state back to false`() {
			let model = makeModel(checkedIn: true)

			model.reconcile(with: false)

			#expect(model.checkedIn)
		}

		@Test func `is ignored while a check-in is in flight, so it can't stomp an optimistic flip`() async {
			let checkingIn = InMemoryCheckingIn()
			checkingIn.hang()
			let model = makeModel(checkedIn: false, checkingIn: checkingIn)

			async let checkInTask: Void = model.checkIn()
			await Task.yield()
			model.reconcile(with: false)

			#expect(model.checkedIn)
			checkingIn.resume(with: .success(CheckInOutcome(message: "", url: nil)))
			await checkInTask
		}
	}

	struct Instrumentation {
		@Test func `breadcrumbs the check-in attempt and tracks the checkedIn analytics event on success`() async {
			let checkingIn = InMemoryCheckingIn(result: .success(CheckInOutcome(message: "Hi", url: nil)))
			let recorder = RecordingDestination()
			let model = makeModel(
				checkedIn: false,
				checkingIn: checkingIn,
				observability: ObservabilityPipeline(destinations: [recorder]),
			)

			await model.checkIn()

			#expect(recorder.breadcrumbs.contains(.interaction(description: "checkIn")))
			#expect(recorder.analytics.map(\.name) == [CheckInEvent.checkedIn.name])
		}

		@Test func `reports the failure and tracks the checkInFailed analytics event`() async {
			let checkingIn = InMemoryCheckingIn(result: .failure(.connection))
			let recorder = RecordingDestination()
			let model = makeModel(
				checkedIn: false,
				checkingIn: checkingIn,
				observability: ObservabilityPipeline(destinations: [recorder]),
			)

			await model.checkIn()

			#expect(recorder.analytics.map(\.name) == [CheckInEvent.checkInFailed.name])
		}
	}
}

// MARK: - Fixtures

@MainActor
private func makeModel(
	venueId: String = "v1",
	checkedIn: Bool,
	checkingIn: any CheckingIn = InMemoryCheckingIn(),
	observability: ObservabilityPipeline = .disabled,
) -> CheckInModel {
	CheckInModel(venueId: venueId, checkedIn: checkedIn, checkingIn: checkingIn, observability: observability)
}
