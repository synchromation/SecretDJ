import Observability
import Testing

@testable import SecretDJ

@MainActor
enum AutoLockPreferenceModelTests {
	struct `Starting up` {
		@Test func `reflects the store's persisted value when disabled`() {
			let store = InMemoryAutoLockPreferenceStore(isDisabled: true)

			let model = AutoLockPreferenceModel(store: store)

			#expect(model.isDisabled == true)
		}

		@Test func `reflects the store's persisted value when enabled`() {
			let store = InMemoryAutoLockPreferenceStore(isDisabled: false)

			let model = AutoLockPreferenceModel(store: store)

			#expect(model.isDisabled == false)
		}
	}

	struct `Updating the preference` {
		@Test func `updates the published value`() {
			let store = InMemoryAutoLockPreferenceStore(isDisabled: false)
			let model = AutoLockPreferenceModel(store: store)

			model.updateIsDisabled(true)

			#expect(model.isDisabled == true)
		}

		@Test func `persists the new value to the store`() {
			let store = InMemoryAutoLockPreferenceStore(isDisabled: false)
			let model = AutoLockPreferenceModel(store: store)

			model.updateIsDisabled(true)

			#expect(store.isAutoLockDisabled() == true)
		}

		@Test func `leaves an interaction breadcrumb`() {
			let recorder = RecordingDestination()
			let store = InMemoryAutoLockPreferenceStore(isDisabled: false)
			let model = AutoLockPreferenceModel(
				store: store,
				observability: ObservabilityPipeline(destinations: [recorder]),
			)

			model.updateIsDisabled(true)

			#expect(recorder.breadcrumbs.contains(.interaction(description: "toggleAutoLock")))
		}

		@Test func `does nothing when set to its current value`() {
			let store = InMemoryAutoLockPreferenceStore(isDisabled: false)
			let recorder = RecordingDestination()
			let model = AutoLockPreferenceModel(
				store: store,
				observability: ObservabilityPipeline(destinations: [recorder]),
			)

			model.updateIsDisabled(false)

			#expect(recorder.breadcrumbs.isEmpty)
		}
	}
}
