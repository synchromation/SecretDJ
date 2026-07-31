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
| [tdd](tdd/SKILL.md) | Order of work when building behavior | Red-green-refactor loop at feature level, red-phase proof (tests must fail for the expected reason), failing-test-first bug fixes, targeted test runs during the loop, what is exempt from TDD (view bodies) |
| [skill-authoring](skill-authoring/SKILL.md) | Creating and maintaining skills | Skill template, contradiction/duplication checks, golden-example grounding, index maintenance, convention-change procedure |

Cross-cutting, owned elsewhere:

- Mechanical style: `.swiftformat` is the style authority, applied with
  SwiftLint (semantic rules only, `.swiftlint.yml`) by the `format-swift.sh`
  PostToolUse hook; `.swift-format` mirrors the same style for Xcode's
  built-in formatter. Skills don't restate rules these tools enforce; style
  changes start in `.swiftformat` and are mirrored to `.swift-format`.
- Build/test verification: `Scripts/verify.sh`, enforced by the
  `verify-on-stop.sh` Stop hook.
- Project map and commands: `CLAUDE.md`.
