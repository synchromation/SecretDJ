---
name: ios-architecture
description: How features are structured in this app — file layout, @Observable models, dependency injection, and separation of concerns. Use whenever adding a new feature, adding logic to an existing feature, or deciding where any new Swift code belongs.
---

# iOS Architecture

Every feature in this app follows one shape. The Counter feature is the golden
example — match its structure, naming, and granularity exactly.

Locations (used throughout the skills): **the app folder** is the source
folder that shares the `.xcodeproj`'s name; **the tests folder** is its
`<app>Tests/` sibling.

The golden examples travel with this skill. Read them before writing a new
feature:

- [CounterModel.swift](references/CounterModel.swift) — the observable model
- [CounterStoring.swift](references/CounterStoring.swift) — a dependency seam
- [UserDefaultsCounterStore.swift](references/UserDefaultsCounterStore.swift) — the production implementation
- [InMemoryCounterStore.swift](references/InMemoryCounterStore.swift) — the test/preview implementation
- [ExampleApp.swift](references/ExampleApp.swift) — the `@main` app struct, the composition root

Where a live instance of the exemplar exists in the app folder (in this
repository: `Features/Counter/`), it and these copies must stay in step —
see skill-authoring.

## Feature anatomy

Each feature lives in its own folder under `Features/<Name>/` in the app
folder:

```
Features/Counter/
├── CounterView.swift            # SwiftUI view(s) — declarative, thin
├── CounterModel.swift           # @Observable model — state + logic
├── CounterStoring.swift         # protocol for each side-effecting dependency
├── UserDefaultsCounterStore.swift   # production implementation
├── InMemoryCounterStore.swift       # in-memory implementation for tests/previews
└── CounterEvent.swift           # typed analytics events (observability skill)
```

Tests mirror this in the tests folder (see the swift-testing skill).

**Multi-target placement**: when the project has more than one app
target, a feature used by a single app lives in that app's
`Features/<Name>/`; anything used by more than one app lives in a local
Swift package under `Packages/`, keeping this same internal anatomy.
Shared non-feature infrastructure (domain model, API client, design
system) gets its own package. App targets hold only composition roots
and single-app features; packages never depend on app targets. Package
tests run natively (`swift test`) in every full verify.

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
model's initializer. Cross-cutting observability is injected the same way —
models take an `ObservabilityPipeline` defaulting to `.disabled`
(observability skill). Every protocol has a production implementation and an
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

**Scope** follows the task: don't add features, refactors, or abstractions
beyond what it requires — the simplest code that fits the anatomy above
wins. Seams exist per real dependency, not per possibility; validate at
those seams, where the outside world enters, and don't handle states that
can't occur.

**Swift language mode is 6** with strict concurrency. Use `async/await` and
actors; never GCD, completion handlers, or `@unchecked Sendable` shortcuts.

## Definition of done for a feature

1. Folder structure matches the anatomy above.
2. All logic lives in the model or deeper — never in the view.
3. Every side-effecting dependency has a protocol, a production
   implementation, and an in-memory fake.
4. Tests cover the model and any non-trivial implementation, and were
   written first (tdd skill for the process, swift-testing for mechanics).
5. Views follow the swiftui-views skill (previews) and are accessible by
   design (accessibility skill).
6. The feature is instrumented — screens, interactions, failures — with
   sensitive values redacted (observability skill).
7. `Scripts/verify.sh` passes.

New Swift files are picked up automatically (the project uses synchronized
folders), but files for a *new target* or changes to targets require editing
`project.pbxproj` — flag that rather than improvising.
