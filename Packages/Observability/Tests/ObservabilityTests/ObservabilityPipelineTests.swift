import Testing

@testable import Observability

enum ObservabilityPipelineTests {
	struct `Fanning out` {
		@Test func `every destination receives every event`() {
			let first = RecordingDestination()
			let second = RecordingDestination()
			let pipeline = ObservabilityPipeline(destinations: [first, second])

			pipeline.interaction("increment")

			#expect(first.events == second.events)
			#expect(first.events.count == 1)
		}

		@Test func `the disabled pipeline swallows events silently`() {
			ObservabilityPipeline.disabled.interaction("increment")
		}
	}

	struct `Emitting events` {
		@Test func `log carries level, message, and category`() {
			let destination = RecordingDestination()
			let pipeline = ObservabilityPipeline(destinations: [destination])

			pipeline.log(.warning, "cache miss", category: "Counter")

			let expected = Diagnostic(level: .warning, message: "cache miss", category: "Counter")

			#expect(destination.events == [.diagnostic(expected)])
		}

		@Test func `reported errors become error-level diagnostics`() {
			let destination = RecordingDestination()
			let pipeline = ObservabilityPipeline(destinations: [destination])

			pipeline.report(SampleFailure.storeUnavailable, category: "Counter")

			let expected = Diagnostic(level: .error, message: "storeUnavailable", category: "Counter")

			#expect(destination.events == [.diagnostic(expected)])
		}

		@Test func `screens, interactions, and network calls become breadcrumbs in order`() {
			let destination = RecordingDestination()
			let pipeline = ObservabilityPipeline(destinations: [destination])

			pipeline.screen("Counter")
			pipeline.interaction("increment")
			pipeline.network(method: "GET", path: "/counts", statusCode: 200, duration: .milliseconds(120))

			let expected: [Breadcrumb.Kind] = [
				.screen(name: "Counter"),
				.interaction(description: "increment"),
				.network(method: "GET", path: "/counts", statusCode: 200, duration: .milliseconds(120)),
			]

			#expect(destination.breadcrumbs == expected)
		}

		@Test func `tracked events are flattened to name and parameters`() {
			let destination = RecordingDestination()
			let pipeline = ObservabilityPipeline(destinations: [destination])

			pipeline.track(SampleEvent.somethingHappened)

			#expect(destination.analytics == [AnalyticsPayload(name: "somethingHappened", parameters: [:])])
		}
	}

	struct `Diagnostic levels` {
		@Test func `levels compare by severity`() {
			#expect(DiagnosticLevel.debug < .info)
			#expect(DiagnosticLevel.warning < .error)
			#expect(DiagnosticLevel.error < .critical)
		}
	}
}

// MARK: - Test scaffolding

private enum SampleFailure: Error {
	case storeUnavailable
}

private enum SampleEvent: String, AnalyticsEvent {
	case somethingHappened

	var name: String {
		rawValue
	}
}
