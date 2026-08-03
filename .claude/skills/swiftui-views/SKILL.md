---
name: swiftui-views
description: Conventions for writing SwiftUI views in this app — composition, previews, accessibility, and localization. Use whenever creating or modifying any SwiftUI view.
---

# SwiftUI Views

The golden example is [CounterView.swift](references/CounterView.swift).
Match its shape: a small `body` composed from named private pieces, previews
for every meaningful state, accessibility on anything non-obvious.

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
including the awkward ones (empty, error, loading, extreme values) and an
accessibility text size (accessibility skill). Previews always inject
in-memory fakes, never production dependencies. Name each preview:
`#Preview("Fresh install") { ... }`.

## Accessibility

Views are accessible by design — labelling, adjustable elements, Dynamic
Type, and layout variations at accessibility text sizes are owned by the
[accessibility skill](../accessibility/SKILL.md); its verification steps
are part of every view's definition of done.

## Localization

User-facing strings are string literals inside SwiftUI text APIs so the
String Catalog extracts them. Everything else — languages, tone of voice,
translation rules, what counts as user-facing — is owned by the
[localization skill](../localization/SKILL.md).
