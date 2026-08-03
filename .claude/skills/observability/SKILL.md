---
name: observability
description: How the app logs, tracks analytics, leaves crash breadcrumbs, and redacts sensitive values (PII) — everything flows through the Observability package's pipeline, and instrumentation is part of every feature's definition of done. Use whenever writing or changing any feature (instrumentation is automatic, not on request), adding logging/analytics/error reporting, deciding whether a value is safe to log, or configuring a vendor SDK.
---

# Observability

All logging, analytics, and breadcrumbs flow through one pipeline
(`Packages/Observability` — a project-name-free package that transfers
wholesale). Features emit **semantic events**; destinations configured at the
composition root fan them out. Features never import a vendor SDK — vendor
code lives only in adapter targets inside the package
(`ObservabilitySentry`, `ObservabilityTelemetryDeck`).

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
- `Redacted.swift` (and `RedactedTests.swift`) in the package — the
  redaction mechanism and its behavior spec

## Emitting

- **Instrumentation is automatic**: every new or changed feature ships
  instrumented — screens tracked, interactions breadcrumbed, failures
  reported — as part of its definition of done (ios-architecture), without
  being asked. Un-instrumented behavior is incomplete the same way
  untested behavior is.
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

## Privacy and redaction

**Sensitivity is the default.** A dynamic value may appear in the clear
only when it is provably non-identifying: a code-defined name (enum case,
screen name, state), a count, or an internal constant. Everything else —
and anything you are *unsure* about — is treated as sensitive and wrapped:

```swift
observability.log(.info, "signed in as \(Redacted(email, label: "email"))", category: "Auth")
// console + Sentry both see: signed in as ⟨email: j…16 #4f9a⟩
```

- The redacted hint keeps the first character, the length, and a stable
  digest — enough to correlate occurrences ("same account both times")
  and know *what kind* of value was redacted, while identifying no one.
  The `label` names the kind ("email", "postcode", "query").
- Redact **at the emission call site**, never in destinations: every
  destination then receives only the redacted form, and nothing
  downstream can leak what it never received. `Redacted` does not retain
  the original.
- Never rely on `os.Logger`'s `.private` interpolation for protection —
  it guards only the console, not vendor destinations. Console messages
  are `.public` precisely because redaction has already happened.
- Analytics parameters accept no redacted values: if a value needs
  redacting, it does not belong in analytics at all. Analytics events are
  typed precisely so the app's complete emission surface is reviewable.
- Network breadcrumbs carry method, path, status, and duration — never
  bodies, tokens, or query strings.

## Routing policy

| Level | Xcode console | Crash reporter (`ObservabilitySentry`) |
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
destinations are assembled. Vendor destinations
(`SentryDestination(dsn:)`, `TelemetryDeckDestination(appID:)`) are
appended there for release builds; DEBUG stays console-only. Vendor keys
live in dedicated configuration types beside the app entry, so the
transferable exemplars reference them symbolically. Sentry runs with
`enableSwizzling = false` — breadcrumbs are explicit in this app, never
swizzled.

## Testing

Instrumentation is behavior: inject a pipeline over `RecordingDestination`
and assert on `breadcrumbs` / `analytics` / `events` (see the golden
`Instrumentation` suite). Package logic itself is tested natively via
`swift test` — part of every full `Scripts/verify.sh` run.
