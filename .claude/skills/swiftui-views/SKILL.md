---
name: swiftui-views
description: Conventions for writing SwiftUI views in this app — composition, previews, accessibility, and localization. Use whenever creating or modifying any SwiftUI view.
---

# SwiftUI Views

The golden example is `Features/Counter/CounterView.swift` in the app folder
(see ios-architecture for locations). Match its shape: a small `body`
composed from named private pieces, previews for every meaningful state,
accessibility on anything non-obvious.

## Composition

- Keep `body` to a glanceable composition of named parts. Extract subviews as
  `private var` computed properties when they only read state, or as separate
  `struct` views when they take parameters or are reused.
- A view receives its model ready-made (`let model: CounterModel`); it never
  constructs production dependencies. Use `@State` only for view-local UI
  state (focus, sheet visibility), `@Bindable` when a child needs write
  access to an `@Observable` model.
- Views stay declarative: no business logic in `body` or button closures
  beyond a single call into the model.
- Use current API only: `NavigationStack`/`NavigationSplitView` (never
  `NavigationView`), `foregroundStyle` (never `foregroundColor`),
  `Button("Title", systemImage:)` (never manual `Label` unless customizing).

## Previews

Every view file ends with `#Preview` blocks covering its meaningful states —
including the awkward ones (empty, error, loading, extreme values). Previews
always inject in-memory fakes, never production dependencies. Name each
preview: `#Preview("Fresh install") { ... }`.

## Accessibility

- Icon-only or symbol buttons get their meaning from their title — construct
  them with a real title even when `labelStyle(.iconOnly)` hides it.
- Custom-rendered values get `accessibilityLabel` (what it is) and
  `accessibilityValue` (its current value).
- Never fix font sizes in a way that defeats Dynamic Type; prefer semantic
  fonts (`.title`, `.body`) and `@ScaledMetric` for custom sizes.

## Localization

User-facing strings are string literals inside SwiftUI text APIs — the
project's String Catalog generation (`LOCALIZATION_PREFERS_STRING_CATALOGS`)
extracts them automatically. Never interpolate whole sentences from parts,
and never mark up strings the user won't see (keys, identifiers, log
messages).
