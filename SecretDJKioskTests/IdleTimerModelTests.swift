import Foundation
import Observability
import Testing

@testable import SecretDJKiosk

/// ``IdleTimerModel`` — the attract/idle countdown pair ported from
/// `secretdjv3/KioskTimer.swift` (see the model's own doc comment for the
/// full legacy citation). ``ManualIdleTimerClock`` stands in for real
/// elapsed time, keyed by duration so attract and idle can be fired
/// independently — mirroring legacy's two independent one-shot `Timer`s
/// (swift-testing skill: async code is never tested with sleeps).
@MainActor
enum IdleTimerModelTests {
	private static func config(
		attractURL: String? = "https://example.com/attract.html",
		attractTimeoutSeconds: String = "20",
		idleTimeoutSeconds: String = "10",
	) throws -> KioskBehavioralConfig {
		var properties: [Int: String] = [1021: attractTimeoutSeconds, 1004: idleTimeoutSeconds]
		if let attractURL {
			properties[1020] = attractURL
		}
		return try KioskBehavioralConfig(manifest: SkinManifestFixture.make(properties: properties))
	}

	struct `Starting up` {
		@Test func `arms both the attract and idle countdowns at the configured durations`() throws {
			let clock = ManualIdleTimerClock()

			_ = try IdleTimerModel(config: config(), clock: clock)

			#expect(Set(clock.pendingDurations) == [.seconds(10), .seconds(20)])
		}

		@Test func `arms only the idle countdown when the skin has no attract URL`() throws {
			let clock = ManualIdleTimerClock()

			_ = try IdleTimerModel(config: config(attractURL: nil), clock: clock)

			#expect(clock.pendingDurations == [.seconds(10)])
		}
	}

	struct `Attract firing` {
		@Test func `shows the attract screen once its countdown fires`() throws {
			let clock = ManualIdleTimerClock()
			let model = try IdleTimerModel(config: config(), clock: clock)

			clock.fire(after: .seconds(20))

			#expect(model.isShowingAttract)
		}

		@Test func `leaves an interaction breadcrumb`() throws {
			let recorder = RecordingDestination()
			let clock = ManualIdleTimerClock()
			_ = try IdleTimerModel(
				config: config(),
				clock: clock,
				observability: ObservabilityPipeline(destinations: [recorder]),
			)

			clock.fire(after: .seconds(20))

			#expect(recorder.breadcrumbs.contains(.interaction(description: "attractShown")))
		}
	}

	struct `Idle firing` {
		@Test func `signals a return to root once its countdown fires`() throws {
			let clock = ManualIdleTimerClock()
			let model = try IdleTimerModel(config: config(), clock: clock)

			clock.fire(after: .seconds(10))

			#expect(model.idleTimeoutFireCount == 1)
		}

		@Test func `does nothing while the attract screen is already showing`() throws {
			let clock = ManualIdleTimerClock()
			let model = try IdleTimerModel(config: config(), clock: clock)
			clock.fire(after: .seconds(20))

			clock.fire(after: .seconds(10))

			#expect(model.idleTimeoutFireCount == 0)
		}

		@Test func `is not breadcrumbed`() throws {
			let recorder = RecordingDestination()
			let clock = ManualIdleTimerClock()
			_ = try IdleTimerModel(
				config: config(),
				clock: clock,
				observability: ObservabilityPipeline(destinations: [recorder]),
			)

			clock.fire(after: .seconds(10))

			#expect(recorder.breadcrumbs.isEmpty)
		}
	}

	struct `Interaction resets` {
		@Test func `dismisses the attract screen and rearms both countdowns at full duration`() throws {
			let clock = ManualIdleTimerClock()
			let model = try IdleTimerModel(config: config(), clock: clock)
			clock.fire(after: .seconds(20))

			model.recordInteraction()

			#expect(!model.isShowingAttract)
			#expect(Set(clock.pendingDurations) == [.seconds(10), .seconds(20)])
		}

		@Test func `leaves an interaction breadcrumb when it dismisses attract`() throws {
			let recorder = RecordingDestination()
			let clock = ManualIdleTimerClock()
			let model = try IdleTimerModel(
				config: config(),
				clock: clock,
				observability: ObservabilityPipeline(destinations: [recorder]),
			)
			clock.fire(after: .seconds(20))

			model.recordInteraction()

			#expect(recorder.breadcrumbs.contains(.interaction(description: "attractDismissed")))
		}

		@Test func `rearms the countdowns silently when attract wasn't showing`() throws {
			let recorder = RecordingDestination()
			let clock = ManualIdleTimerClock()
			let model = try IdleTimerModel(
				config: config(),
				clock: clock,
				observability: ObservabilityPipeline(destinations: [recorder]),
			)

			model.recordInteraction()

			#expect(recorder.breadcrumbs.isEmpty)
			#expect(Set(clock.pendingDurations) == [.seconds(10), .seconds(20)])
		}
	}

	struct `Preview suppression` {
		@Test func `suspends both countdowns while a preview plays`() throws {
			let clock = ManualIdleTimerClock()
			let model = try IdleTimerModel(config: config(), clock: clock)

			model.setPreviewPlaying(true)

			#expect(clock.pendingDurations.isEmpty)
		}

		@Test func `resumes both countdowns at full duration once the preview stops`() throws {
			let clock = ManualIdleTimerClock()
			let model = try IdleTimerModel(config: config(), clock: clock)
			model.setPreviewPlaying(true)

			model.setPreviewPlaying(false)

			#expect(Set(clock.pendingDurations) == [.seconds(10), .seconds(20)])
		}

		@Test func `an interaction while a preview plays does not rearm the countdowns`() throws {
			let clock = ManualIdleTimerClock()
			let model = try IdleTimerModel(config: config(), clock: clock)
			model.setPreviewPlaying(true)

			model.recordInteraction()

			#expect(clock.pendingDurations.isEmpty)
		}

		@Test func `setting the same playing state twice does not disturb already-suspended countdowns`() throws {
			let clock = ManualIdleTimerClock()
			let model = try IdleTimerModel(config: config(), clock: clock)
			model.setPreviewPlaying(true)

			model.setPreviewPlaying(true)

			#expect(clock.pendingDurations.isEmpty)
		}
	}
}
