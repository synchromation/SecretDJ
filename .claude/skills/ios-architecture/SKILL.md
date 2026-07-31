---
name: ios-architecture
description: How features are structured in this app — file layout, @Observable models, dependency injection, and separation of concerns. Use whenever adding a new feature, adding logic to an existing feature, or deciding where any new Swift code belongs.
---

# iOS Architecture

Every feature in this app follows one shape. The Counter feature is the golden
example — match its structure, naming, and granularity exactly.

Locations (used throughout the skills): **the app folder** is the source
folder that shares the `.xcodeproj`'s name; **the tests folder** is its
`<app>Tests/` sibling. Read these files in the app folder before writing a
new feature:

- `Features/Counter/CounterModel.swift` — the observable model
- `Features/Counter/CounterStoring.swift` — a dependency seam
- `Features/Counter/UserDefaultsCounterStore.swift` — the production implementation
- `Features/Counter/InMemoryCounterStore.swift` — the test/preview implementation
- `App/` — the `@main` app struct, the composition root

## Feature anatomy

Each feature lives in its own folder under `Features/<Name>/` in the app
folder:

```
Features/Counter/
├── CounterView.swift            # SwiftUI view(s) — declarative, thin
├── CounterModel.swift           # @Observable model — state + logic
├── CounterStoring.swift         # protocol for each side-effecting dependency
├── UserDefaultsCounterStore.swift   # production implementation
└── InMemoryCounterStore.swift       # in-memory implementation for tests/previews
```

Tests mirror this in the tests folder (see the swift-testing skill).

## Rules

**Models** are `@Observable final class`, expose state as `private(set) var`,
and mutate it only through intention-named methods (`increment()`, not
`setCount(_:)`). The project builds with default `@MainActor` isolation
(`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`), so models are main-actor
without annotation; move work off the main actor explicitly (`nonisolated`,
actors) only when there is a measured reason. Use `ObservableObject`/
`@Published` never — this project uses the Observation framework.

**Dependencies** (persistence, networking, clocks, anything that touches the
world outside the process) sit behind a small protocol, injected through the
model's initializer. Every protocol has a production implementation and an
in-memory fake. Nothing reaches a singleton (`UserDefaults.standard`,
`URLSession.shared`) from inside logic code — singletons appear only as
default arguments in production implementations or at the composition root.

**Composition** happens in the `@main` app struct in `App/`: production
dependencies are constructed there and handed down. State flows down, events
flow up; no view reaches sideways into another view's state.

**Separation of concerns applies at every level:**
- App level: one folder per feature; shared infrastructure would go in a
  `Support/` folder (create it when a second feature needs something).
- Type level: one primary type per file, named after the file.
- Function level: one responsibility per function. When a function grows a
  second concern, extract a private helper with an intention-revealing name
  (see `CounterModel.update(to:)`). Group logical steps inside a function
  with single blank lines.

**Swift language mode is 6** with strict concurrency. Use `async/await` and
actors; never GCD, completion handlers, or `@unchecked Sendable` shortcuts.

## Definition of done for a feature

1. Folder structure matches the anatomy above.
2. All logic lives in the model or deeper — never in the view.
3. Every side-effecting dependency has a protocol, a production
   implementation, and an in-memory fake.
4. Tests cover the model and any non-trivial implementation, and were
   written first (tdd skill for the process, swift-testing for mechanics).
5. Views follow the swiftui-views skill (previews, accessibility).
6. `Scripts/verify.sh` passes.

New Swift files are picked up automatically (the project uses synchronized
folders), but files for a *new target* or changes to targets require editing
`project.pbxproj` — flag that rather than improvising.
