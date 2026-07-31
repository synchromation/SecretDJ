---
name: observability
description: How the app logs, tracks analytics, and leaves crash breadcrumbs — everything flows through the Observability package's pipeline. Use whenever adding logging, analytics, error reporting, or instrumentation to any feature, or configuring a vendor SDK.
---

# Observability

All logging, analytics, and breadcrumbs flow through one pipeline
(`Packages/Observability` — a project-name-free package that transfers
wholesale). Features emit **semantic events**; destinations configured at the
composition root fan them out. Features never import a vendor SDK — vendor
code lives only in adapter targets inside the package
(`ObservabilityTelemetryDeck`, a future Sentry adapter).

Golden examples:

- [CounterEvent.swift](references/CounterEvent.swift) — a feature's typed
  analytics events
- `CounterModel` ([ios-architecture references](../ios-architecture/references/CounterModel.swift)) —
  interaction instrumentation in an observable model
- The `Instrumentation` suite in
  [ReferenceTests.swift](../swift-testing/references/ReferenceTests.swift) —
  asserting on emitted events with `RecordingDestination`
- `Packages/Observability/Sources/Observability/` — the pipeline itself,
  doc-commented per the documentation skill

## Emitting

- **Models** take `observability: ObservabilityPipeline = .disabled` in
  their initializer — the null-object default keeps tests and previews
  silent. The composition root passes `.live`.
- **Interactions**: intention-named model methods call
  `observability.interaction("increment")` — named for the intention,
  never gesture mechanics. Explicit instrumentation only; no swizzling.
- **Analytics**: business-meaningful moments additionally call
  `track(...)` with a case of the feature's event enum
  (`enum <Feature>Event: String, AnalyticsEvent`, one per feature, in the
  feature folder). Routine interactions are breadcrumbs, not analytics.
- **Screens**: `.tracksScreen("Name")` on each screen's root view; the
  pipeline reaches views via `\.observability` in the environment.
- **Diagnostics**: `log(level, message, category:)` with the feature name
  as category; non-fatal failures use `report(error, category:)`.
- **Network** (when a networking layer exists): one middleware records
  method, path, status, and duration — never bodies, tokens, or full query
  strings.

## Privacy

Nothing identifying goes into any event: no user IDs, no free-form user
content, no full URLs. Analytics events are typed precisely so the app's
complete emission surface is reviewable in code.

## Routing policy

| Level | Xcode console | Crash reporter (future Sentry adapter) |
|---|---|---|
| debug, info | ✓ | — |
| notice, warning | ✓ | breadcrumb only — attached to later errors, never standalone issues |
| error, critical | ✓ | captured event with the breadcrumb trail |

The console destination is always on, so diagnostics, breadcrumbs, *and
outgoing analytics* are all live-visible in Xcode's debug console — filter
by category (feature names, `Breadcrumbs`, `Analytics`). Each vendor
adapter's routing lives in its `receive(_:)` switch, nowhere else.

## Composition

`ObservabilityPipeline.live` in the app entry file is the only place
destinations are assembled. Vendor destinations (e.g.
`TelemetryDeckDestination(appID:)`) are appended there for release builds;
DEBUG stays console-only.

## Testing

Instrumentation is behavior: inject a pipeline over `RecordingDestination`
and assert on `breadcrumbs` / `analytics` / `events` (see the golden
`Instrumentation` suite). Package logic itself is tested natively via
`swift test` — part of every full `Scripts/verify.sh` run.
