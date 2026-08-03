---
name: accessibility
description: Making every screen fully accessible — VoiceOver labelling and semantics, Dynamic Type with layout variations at accessibility text sizes, contrast, motion, and hit targets. Use whenever creating or modifying any view, and when reviewing UI for accessibility.
---

# Accessibility

Accessibility is designed in, not audited in later. The golden example is
`CounterView.swift`
([swiftui-views references](../swiftui-views/references/CounterView.swift)):
a scaled display, an adjustable VoiceOver element, and a layout that
reshapes itself at accessibility text sizes.

## Labelling and semantics

- Every interactive control gets its meaning from a real, localized title
  — construct icon buttons with `Button("Title", systemImage:)` even when
  `labelStyle(.iconOnly)` hides the text.
- Custom-rendered values get `accessibilityLabel` (what it is) and
  `accessibilityValue` (its current state). Labels are user-facing
  strings: they live in the string catalog (localization skill).
- **Prefer richer semantics over more elements**: a value the user can
  change becomes one adjustable element
  (`accessibilityAdjustableAction`) — see the count display; composite
  views combine with `.accessibilityElement(children: .combine)` so
  VoiceOver reads one sensible element, not fragments; row actions get
  `.accessibilityAction`s.
- Section titles get `.accessibilityAddTraits(.isHeader)` so VoiceOver
  users can navigate by headings.
- Decoration is invisible: `Image(decorative:)` or
  `.accessibilityHidden(true)` for anything that adds no information.
- `accessibilityHint` sparingly, only when the outcome isn't obvious from
  the label.

## Dynamic Type and adaptive layout

- Semantic fonts (`.title`, `.body`) by default; custom sizes only via
  `@ScaledMetric(relativeTo:)` so they scale with the user's setting.
  Never a fixed point size; `minimumScaleFactor` is a last resort, not a
  layout strategy.
- **Layouts reshape at accessibility sizes**: read
  `@Environment(\.dynamicTypeSize)` and branch on `.isAccessibilitySize`
  — horizontal control rows become vertical stacks, icon-only buttons
  show their titles (see `controls` in the golden example). Use
  `AnyLayout(HStackLayout/VStackLayout)` when animation identity must
  survive the switch, or `ViewThatFits` when the best arrangement depends
  on space rather than a threshold.
- Never cap `dynamicTypeSize` on a view without a written reason.
- Text wraps rather than truncates; no fixed-height containers around
  text.

## Beyond text

- Never rely on color alone to convey state — pair it with a symbol,
  label, or shape change; honor
  `\.accessibilityDifferentiateWithoutColor`.
- Gate non-essential animation on `\.accessibilityReduceMotion`
  (cross-fade instead of movement).
- Hit targets at least 44×44 points — bordered button styles guarantee
  this; custom tap areas use `.contentShape` and padding, not tiny
  glyphs.
- Maintain contrast: system colors and materials adapt; custom colors
  must pass 4.5:1 for text in both light and dark appearance.

## Verification (part of the definition of done)

1. Every view's previews include an accessibility text size:
   `#Preview` with `.environment(\.dynamicTypeSize, .accessibility5)` —
   and the layout must be *usable* there, not merely not-broken.
2. Walk the screen with VoiceOver (or Accessibility Inspector) when a
   screen is new or its structure changed: every element reachable, every
   label sensible, nothing decorative announced.
3. When a UI test target exists, `performAccessibilityAudit()` runs in it
   for every screen.
