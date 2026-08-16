# Skills index

One line per skill: scope, and the conventions it owns. A convention has
exactly one owning skill — check here before adding guidance anywhere.
Maintained by the skill-authoring procedure; update in the same change as any
skill addition, edit, or removal.

| Skill | Scope | Owns |
|---|---|---|
| [ios-architecture](ios-architecture/SKILL.md) | Structure of features and placement of code | Feature folder anatomy, @Observable model rules, dependency-injection seams (protocol + production + in-memory fake), composition root, separation of concerns at app/type/function level, scope discipline (task-bounded code, seams per real dependency, boundary-only validation), Swift 6 concurrency stance, feature definition of done |
| [swiftui-views](swiftui-views/SKILL.md) | Writing SwiftUI views | View composition and extraction, model access from views (`let model` / `@State` / `@Bindable`), current-API choices, previews |
| [accessibility](accessibility/SKILL.md) | Making every screen fully accessible | VoiceOver labelling and semantics (labels/values/hints, adjustable elements, combined elements, headers, hidden decoration), Dynamic Type (`@ScaledMetric`, no fixed sizes), layout variations at accessibility text sizes, color/motion/hit-target rules, accessibility-size previews and audit steps in the definition of done |
| [localization](localization/SKILL.md) | All user-facing copy and its translation | String Catalog mechanism (literal extraction, translator comments, plural/gender variation, placeholders), the six-language set (en source + es/de/pt/fr/nl), tone of voice and its per-language adaptation sheets, glossary, load-bearing phrases, no-logic-on-visible-strings rule, server-text rule, copy definition of done |
| [swift-testing](swift-testing/SKILL.md) | Writing and running tests | Swift Testing usage and its full capability catalog (parameterized, async/confirmation, throwing, traits, known issues, attachments, exit tests), test file placement and naming, raw-identifier test names (behavior statements in backticks), nested suites per concern, arrange/act/assert layout, fakes-over-mocks, determinism rules, no-weakening-tests rule |
| [tdd](tdd/SKILL.md) | Order of work when building behavior | Red-green-refactor loop at feature level, red-phase proof (tests must fail for the expected reason), failing-test-first bug fixes, targeted test runs during the loop, what is exempt from TDD (view bodies) |
| [delegation](delegation/SKILL.md) | Who executes coding work, and on which model | Delegate-every-coding-task rule (subagent on the lowest model tier the task allows), model-tier ladder (haiku → sonnet → opus → fable) and escalate-on-failed-review, self-contained subagent briefs, orchestrator review duty, no recursive delegation |
| [observability](observability/SKILL.md) | Logging, analytics, crash breadcrumbs, and event privacy | Pipeline-only emission (no vendor SDKs in features), instrument-by-default rule, typed per-feature analytics enums, explicit breadcrumbs (screens/interactions/network), diagnostic level routing policy, default-sensitive redaction (`Redacted` hints), composition of destinations, RecordingDestination test pattern |
| [documentation](documentation/SKILL.md) | When and how to write DocC comments | Contract-boundary rule (protocol members, enum cases, type summaries), no-restatement rule, tag usage, /// style and DocC links, no docs in bodies / on conformances / on tests |
| [skill-authoring](skill-authoring/SKILL.md) | Creating and maintaining skills | Skill template, contradiction/duplication checks, golden-example grounding, reference-copy sync with live exemplars, transferability rule (no project names in skills/agents/hooks), index maintenance, convention-change procedure, lesson recording (fold mid-task lessons into the owning skill with their why, delete disproven guidance) |

Golden examples travel inside each skill's `references/` folder; where a
live instance exists in the app (here: `Features/Counter/`), copy and
instance stay in step per the skill-authoring procedure.

Cross-cutting, owned elsewhere:

- Mechanical style: `.swiftformat` is the style authority, applied with
  SwiftLint (semantic rules only, `.swiftlint.yml`) by the `format-swift.sh`
  PostToolUse hook; `.swift-format` mirrors the same style for Xcode's
  built-in formatter. Skills don't restate rules these tools enforce; style
  changes start in `.swiftformat` and are mirrored to `.swift-format`.
- Build/test verification: `Scripts/verify.sh`, enforced by the
  `verify-on-stop.sh` Stop hook.
- Project map and commands: `CLAUDE.md`.
