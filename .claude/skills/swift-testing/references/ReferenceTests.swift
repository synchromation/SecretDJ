import Foundation
import Testing

@testable import MyApp

/// The golden reference for tests in this project.
///
/// Everything here follows the swift-testing skill: raw-identifier test names,
/// nested suites separating concerns, arrange / act / assert stages separated
/// by blank lines, and in-memory fakes injected through each feature's
/// dependency seam. The first three suites are the canonical shape; the later
/// suites catalog the wider Swift Testing toolbox — parameterized tests,
/// async patterns, throwing expectations, traits, known issues, attachments,
/// and exit tests.
enum ReferenceTests {
	/// Plain synchronous tests: arrange a model over a fake store, act, then
	/// assert with `#expect`.
	struct `Starting up` {
		/// The simplest shape — arrange and assert; no act stage is needed.
		@Test func `starts at zero with an empty store`() {
			let model = CounterModel(store: InMemoryCounterStore())

			#expect(model.count == 0)
		}

		/// Fakes are seeded through their initializer, never by mutating
		/// production state.
		@Test func `restores the saved count on launch`() {
			let store = InMemoryCounterStore(count: 41)

			let model = CounterModel(store: store)

			#expect(model.count == 41)
		}
	}

	/// One nested suite per concern keeps behaviors grouped and the test
	/// navigator readable.
	struct `Changing the count` {
		/// Act on the model through its intention-named methods only.
		@Test func `increment raises the count by one`() {
			let model = CounterModel(store: InMemoryCounterStore())

			model.increment()

			#expect(model.count == 1)
		}

		/// One behavior per test — decrement gets its own test rather than
		/// sharing one with increment.
		@Test func `decrement lowers the count by one`() {
			let model = CounterModel(store: InMemoryCounterStore())

			model.decrement()

			#expect(model.count == -1)
		}

		/// Start from a non-default state by seeding the fake.
		@Test func `reset returns the count to zero`() {
			let model = CounterModel(store: InMemoryCounterStore(count: 41))

			model.reset()

			#expect(model.count == 0)
		}
	}

	/// Assert on outcomes observable through the dependency seam — what the
	/// store received — not on how the model called it.
	struct Persistence {
		/// The fake exposes its state (`store.count`) so tests never need
		/// call-recording mocks.
		@Test func `every change is persisted to the store`() {
			let store = InMemoryCounterStore()
			let model = CounterModel(store: store)

			model.increment()
			model.increment()

			#expect(store.count == 2)
		}
	}

	/// Parameterized tests run the same body once per argument; each case
	/// appears (and can be re-run) individually in the test navigator.
	struct `Parameterized tests` {
		/// A single `arguments:` collection — one run per element.
		@Test(arguments: [1, 3, 5])
		func `incrementing repeatedly reaches that count`(steps: Int) {
			let model = CounterModel(store: InMemoryCounterStore())

			for _ in 0 ..< steps {
				model.increment()
			}

			#expect(model.count == steps)
		}

		/// `zip` pairs two collections positionally. Prefer it over passing
		/// two collections (which would run the cartesian product) when the
		/// values belong together as input/expectation pairs.
		@Test(arguments: zip([0, 41, -7], [1, 42, -6]))
		func `increment moves any starting count up by one`(start: Int, expected: Int) {
			let model = CounterModel(store: InMemoryCounterStore(count: start))

			model.increment()

			#expect(model.count == expected)
		}
	}

	/// Asynchronous behavior: mark the test `async` and `await` the work —
	/// never sleep or poll.
	struct `Asynchronous behavior` {
		/// Await async work directly in the test body.
		@Test func `counts persist across tasks`() async {
			let store = InMemoryCounterStore()
			CounterModel(store: store).increment()

			let restored = await Task { CounterModel(store: store).count }.value

			#expect(restored == 1)
		}

		/// `confirmation` proves a callback fires the expected number of
		/// times before the body returns — the async-event counterpart of
		/// asserting on a fake's state.
		@Test func `every change reports a save`() async {
			await confirmation("save reported", expectedCount: 2) { saved in
				let model = CounterModel(store: ClosureCounterStore { _ in saved() })

				model.increment()
				model.increment()
			}
		}
	}

	/// Throwing APIs and optionals: `try`, `#require`, and `#expect(throws:)`.
	struct `Throwing and optionals` {
		/// `#require` unwraps an optional or fails the test — never
		/// force-unwrap (a format rule enforces this in tests). The scratch
		/// `UserDefaults` suite keeps the test off the app's real defaults.
		@Test func `a scratch defaults store round-trips a count`() throws {
			let suiteName = "test.\(UUID().uuidString)"
			let defaults = try #require(UserDefaults(suiteName: suiteName))
			let store = UserDefaultsCounterStore(defaults: defaults)

			store.save(41)

			#expect(store.savedCount() == 41)
		}

		/// `#expect(throws:)` asserts that a specific error type is thrown.
		@Test func `parsing rejects text that is not a number`() {
			#expect(throws: CounterCodec.ParsingError.self) {
				try CounterCodec.count(from: "forty-one")
			}
		}

		/// The happy path of a throwing API is a plain `try` in the arrange
		/// stage — an unexpected throw fails the test by itself.
		@Test func `parsing reads a numeric string`() throws {
			let count = try CounterCodec.count(from: "41")

			#expect(count == 41)
		}
	}

	/// Traits attach metadata and control to tests and suites.
	struct `Traits and metadata` {
		/// Tags (declared once, in the `Tag` extension below) group related
		/// tests across suites for filtering in Xcode or `swift test`.
		@Test(.tags(.persistence)) func `tagged tests can be filtered`() {
			let store = InMemoryCounterStore()

			CounterModel(store: store).increment()

			#expect(store.count == 1)
		}

		/// `.bug` links a test to its tracker issue in results and reports.
		@Test(.bug("https://example.com/issues/41")) func `bug references appear in results`() {
			let model = CounterModel(store: InMemoryCounterStore())

			#expect(model.count == 0)
		}

		/// `.timeLimit` fails a runaway test instead of hanging the suite.
		@Test(.timeLimit(.minutes(1))) func `time limits stop runaway tests`() {
			let model = CounterModel(store: InMemoryCounterStore())

			#expect(model.count == 0)
		}

		/// `.enabled(if:)` runs the test only when its precondition holds —
		/// prefer it over commenting tests out.
		@Test(.enabled(if: ProcessInfo.processInfo.environment["SKIP_SLOW_TESTS"] == nil))
		func `conditional tests run only when their precondition holds`() {
			let model = CounterModel(store: InMemoryCounterStore())

			#expect(model.count == 0)
		}

		/// `.disabled` skips unconditionally — always give the reason.
		@Test(.disabled("demonstrates a skipped test — the body never runs"))
		func `disabled tests are skipped with a reason`() {
			#expect(Bool(false), "never evaluated: the trait skips this test")
		}
	}

	/// `.serialized` runs a suite's tests one at a time instead of in
	/// parallel — a last resort for tests sharing unavoidable state. This is
	/// the one place `@Suite` appears: only when it carries traits.
	@Suite(.serialized)
	struct `Serialized examples` {
		/// Serial execution means this test cannot race its sibling below.
		@Test func `serialized tests never overlap`() {
			let model = CounterModel(store: InMemoryCounterStore())

			model.increment()

			#expect(model.count == 1)
		}

		/// Still prefer isolated state (fresh fakes per test) even when
		/// serialized.
		@Test func `each test still gets fresh state`() {
			let model = CounterModel(store: InMemoryCounterStore())

			#expect(model.count == 0)
		}
	}

	/// Known issues and diagnostic attachments.
	struct `Known issues and attachments` {
		/// `withKnownIssue` keeps an understood failure visible without
		/// failing the suite: the expectation inside intentionally fails
		/// here to demonstrate the mechanics. The test starts failing again
		/// the moment the issue is fixed, prompting removal of the wrapper.
		@Test func `known issues stay visible without failing the suite`() {
			let model = CounterModel(store: InMemoryCounterStore())

			model.decrement()

			withKnownIssue("demonstration: counts are deliberately not clamped at zero") {
				#expect(model.count == 0)
			}
		}

		/// `Attachment.record` files diagnostic artifacts alongside the
		/// results — invaluable when a failure only reproduces in CI.
		@Test func `attachments capture diagnostic state`() {
			let store = InMemoryCounterStore(count: 41)

			Attachment.record("restored count: \(CounterModel(store: store).count)", named: "counter-state.txt")

			#expect(store.count == 41)
		}
	}

	#if os(macOS)
		/// Exit tests run their body in a fresh process and assert on how it
		/// terminates — the only way to test `fatalError`/`precondition`
		/// paths. Process spawning requires macOS; simulator runs compile
		/// this out.
		struct `Exit behavior` {
			/// The body executes in a child process; the parent asserts on
			/// its exit condition.
			@Test func `fatal errors terminate the process`() async {
				await #expect(processExitsWith: .failure) {
					fatalError("demonstrates an exit test")
				}
			}
		}
	#endif
}

// MARK: - Test scaffolding

/// Tags used by the examples above — declare each tag once, in an extension.
extension Tag {
	@Tag static var persistence: Self
}

/// A store that reports every save to a closure — scaffolding for the
/// `confirmation` example.
private final class ClosureCounterStore: CounterStoring {
	private let onSave: (Int) -> Void

	init(onSave: @escaping (Int) -> Void) {
		self.onSave = onSave
	}

	func savedCount() -> Int {
		0
	}

	func save(_ count: Int) {
		onSave(count)
	}
}

/// A tiny throwing API — scaffolding for the throwing-expectation examples.
private enum CounterCodec {
	enum ParsingError: Error {
		case notANumber
	}

	static func count(from text: String) throws -> Int {
		guard let value = Int(text) else {
			throw ParsingError.notANumber
		}

		return value
	}
}
