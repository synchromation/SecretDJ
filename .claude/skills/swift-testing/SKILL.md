---
name: swift-testing
description: How tests are written in this project — Swift Testing framework, naming, structure, and fakes. Use whenever writing or modifying tests, and whenever new logic is added (all logic ships with tests).
---

# Swift Testing

The golden examples are
[CounterModelTests.swift](../../../Untitled ProjectTests/CounterModelTests.swift)
and
[UserDefaultsCounterStoreTests.swift](../../../Untitled ProjectTests/UserDefaultsCounterStoreTests.swift).
Match their shape.

## Ground rules

- **Framework**: Swift Testing (`import Testing`, `@Test`, `#expect`,
  `#require`) — never XCTest, except XCUITest if a UI automation test is ever
  explicitly requested.
- **Coverage is part of the definition of done**: any new model, dependency
  implementation, or piece of logic ships with tests in the same change. A
  view's logic must live in its model precisely so it can be tested.
- **Tests come first**: the order of work (spec → red → green → refactor)
  is owned by the [tdd skill](../tdd/SKILL.md); this skill owns how the
  tests themselves are written.
- Test files live in `Untitled ProjectTests/`, one file per type under test,
  named `<TypeName>Tests.swift`, containing a `struct <TypeName>Tests`.
  New files there are picked up automatically.
- Import the app with `@testable import Untitled_Project`.

## Structure and naming

- Test names are behavior statements that read as English:
  `restoresTheSavedCountOnLaunch`, not `testInit` or `init_savedCount_41`.
- Arrange / act / assert, separated by single blank lines (see any test in
  the golden files). Collapse to fewer blocks only when a stage is a single
  obvious line.
- One behavior per test. Prefer several small tests over one test with many
  expectations about different behaviors.
- Use `#require` (with `throws`) to unwrap optionals; never force-unwrap.

## Determinism

- Unit tests touch no real network, disk, clock, or shared `UserDefaults`.
  Inject the feature's in-memory fake (e.g. `InMemoryCounterStore`); when
  testing a real adapter, isolate it (scratch `UserDefaults` suite, temp
  directory) as `UserDefaultsCounterStoreTests` does.
- Prefer fakes (real implementations with in-memory storage) over mocks with
  expectation recording. Assert on observable outcomes, not call sequences.
- Async code is tested with `async` test functions and `await` — never
  sleeps or timeouts.

## Running

```bash
Scripts/verify.sh test
```

The Stop hook runs this automatically; a turn cannot end with failing tests.
Never weaken, delete, or `.disabled()` a test to get past the hook unless the
test itself asserts genuinely wrong behavior — and say so explicitly when you
do.
