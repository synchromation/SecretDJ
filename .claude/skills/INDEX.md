# Skills index

One line per skill: scope, and the conventions it owns. A convention has
exactly one owning skill — check here before adding guidance anywhere.
Maintained by the skill-authoring procedure; update in the same change as any
skill addition, edit, or removal.

| Skill | Scope | Owns |
|---|---|---|
| [ios-architecture](ios-architecture/SKILL.md) | Structure of features and placement of code | Feature folder anatomy, @Observable model rules, dependency-injection seams (protocol + production + in-memory fake), composition root, separation of concerns at app/type/function level, Swift 6 concurrency stance, feature definition of done |
| [swiftui-views](swiftui-views/SKILL.md) | Writing SwiftUI views | View composition and extraction, model access from views (`let model` / `@State` / `@Bindable`), current-API choices, previews, accessibility, localization |
| [swift-testing](swift-testing/SKILL.md) | Writing and running tests | Swift Testing usage, test file placement and naming, behavior-statement test names, arrange/act/assert layout, fakes-over-mocks, determinism rules, no-weakening-tests rule |
| [skill-authoring](skill-authoring/SKILL.md) | Creating and maintaining skills | Skill template, contradiction/duplication checks, golden-example grounding, index maintenance, convention-change procedure |

Cross-cutting, owned elsewhere:

- Mechanical formatting: `.swiftformat` config, applied by the
  `format-swift.sh` PostToolUse hook — skills don't restate formatting rules.
- Build/test verification: `Scripts/verify.sh`, enforced by the
  `verify-on-stop.sh` Stop hook.
- Project map and commands: `CLAUDE.md`.
