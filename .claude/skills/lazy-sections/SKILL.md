---
name: lazy-sections
description: The lazy-sections pattern for vertically scrolling, backend-driven feeds of heterogeneous content — one outer lazy container, typed section kinds, immutable cell values, and scroll-performance rules. Use whenever building or modifying a screen that renders server-driven sections or arbitrary mixed content in a vertical scroll (feeds, home screens, mixed-layout search results).
---

# Lazy Sections

The pattern for screens whose content is a vertical feed of arbitrary,
backend-driven sections, each rendering as a list, carousel, or grid.
Match the golden exemplar in `references/` (adapted from the
LazySectionsDemo pattern and verified in this project):

- Value model: [SectionKind.swift](references/SectionKind.swift),
  [FeedItem.swift](references/FeedItem.swift),
  [FeedSection.swift](references/FeedSection.swift)
- Feed: [FeedView.swift](references/FeedView.swift),
  [SectionBody.swift](references/SectionBody.swift),
  [SectionHeader.swift](references/SectionHeader.swift)
- Section layouts: [ListSection.swift](references/ListSection.swift),
  [CarouselSection.swift](references/CarouselSection.swift),
  [GridSection.swift](references/GridSection.swift)
- Cells: [RowCell.swift](references/RowCell.swift),
  [CardCell.swift](references/CardCell.swift),
  [TileCell.swift](references/TileCell.swift)

## When it applies

The section list is data: the backend decides what sections appear and in
what order, and kinds vary per response. A screen with one homogeneous
list and a fixed layout doesn't need this — plain `List`/`ScrollView` per
swiftui-views.

## Structure

- **One lazy container for the whole feed**: a vertical `ScrollView` with
  a single outer `LazyVStack`; each section is `Section { body } header:`.
  Section bodies materialise as they approach the viewport. Inner lazy
  containers add little inside an already-lazy feed — measure before
  adding one.
- **Section kinds are a closed enum**; `SectionBody` switches on it to
  concrete section views — never `AnyView` (type erasure destroys
  structural identity and makes diffing far more expensive). A new kind
  is a new enum case plus section view, exhaustively switched. Decode
  server kinds the client doesn't know to nil and drop those sections.

## Data

- Sections and items are immutable value types — `Identifiable`,
  `Hashable`, and `Sendable` (implicitly: internal value types with
  `Sendable` stored properties conform by construction, and the formatter
  strips a redundant explicit conformance) — with stable server-derived
  ids: stable identity gives correct, cheap `ForEach` diffing; never key
  by index.
- Every displayed value is computed once, when the model is built:
  formatted strings, resolved colors. Never format or derive in a view
  body. Cells take only immutable values — no closures, no observable
  objects — so scrolling observes nothing and triggers zero invalidation.
- Feed text arrives from the backend already localized (localization
  skill's server-text rule). Preview fixture text uses `Text(verbatim:)`
  so the String Catalog stays clean.

## Scroll performance

- **Stable cell dimensions per size category**: `@ScaledMetric` for
  dimensions and `lineLimit(_:reservesSpace:)` for text — Dynamic Type
  works, and layout stays cheap because scaled metrics resolve when the
  size category changes, not per frame. No `GeometryReader` in cells, no
  measurement feedback loops.
- **Carousels are contained**: horizontal `ScrollView` + `LazyHStack` +
  `.scrollTargetLayout()` + `.viewAligned`, with an externally fixed
  (scaled) height so the vertical feed never measures carousel content.
- **No `.shadow()` or materials in scrolling content** — the two most
  common scroll-performance killers. Flat fills only.
- **Programmatic scrolling is event-driven**: `ScrollViewReader` with an
  anchor placed outside the lazy container. Don't drive it from a
  `.scrollPosition(id:)` binding — that writes state on the main thread
  continuously while the user scrolls.
- Section-header pinning (`pinnedViews`) costs a little every frame —
  off unless the design needs it.

## Accessibility and the model

- Cells are combined accessibility elements, headers carry `.isHeader`,
  and layouts branch at `.isAccessibilitySize` where the geometry breaks
  — the exemplar shows the minimal form; everything else the
  accessibility skill owns applies unchanged. In the accessibility-size
  branch there is no fixed height to protect, so text wraps freely there
  — `lineLimit` earns its keep only inside fixed-height compact layouts.
- Leaf views (cells, the header) carry their own previews, including an
  accessibility text size. Thin wrappers (`SectionBody`, the three
  section layouts) are previewed through `FeedView`'s previews — the one
  sanctioned exception to swiftui-views' every-file preview rule.
- The `@Observable` model feeding the view follows ios-architecture; only
  the root feed view reads it, and everything below receives plain values.
  Screen tracking and interaction breadcrumbs attach at the screen's
  model-owning wrapper (observability skill), not inside these reusable
  feed views.
