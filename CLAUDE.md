# Project guide

Multiplatform SwiftUI app (iOS-first), Swift 6 language mode, Xcode
synchronized folders (new Swift files are picked up automatically; target
changes need `project.pbxproj` edits).

## Map

The app source folder shares the `.xcodeproj`'s name; the unit test folder
is `<app>Tests/` beside it.

- `<app>/App/` — composition root (the `@main` app struct)
- `<app>/Features/<Name>/` — one folder per feature
- `<app>Tests/` — Swift Testing unit tests
- `Packages/Observability/` — logging/analytics/breadcrumb pipeline (SPM;
  its tests run natively in every full verify)
- `Scripts/verify.sh` — canonical build + test command (auto-detects the project)
- `.claude/skills/` — project conventions; `INDEX.md` lists them

## Commands

```bash
Scripts/verify.sh test    # build + full test suite (pinned simulator)
Scripts/verify.sh build   # build only
```

## Conventions

Detailed conventions live in skills and load on demand — consult
`.claude/skills/INDEX.md` for ownership. In short: features follow the
Counter exemplar (ios-architecture), views follow swiftui-views and are
accessible by design (accessibility), backend-driven feeds follow the
lazy-sections pattern (lazy-sections), behavior is
built test-first via red-green-refactor (tdd), all logic ships with Swift
Testing tests (swift-testing), DocC comments mark contract boundaries only
(documentation), logging/analytics/breadcrumbs go through the Observability
pipeline (observability), user-facing copy is localized into six languages
with a defined tone of voice (localization), coding tasks are executed by
subagents on the lowest model tier the task allows (delegation), work is
committed, pushed, and journaled in NOTES.md at every green checkpoint
(checkpoints), and skills themselves are managed via skill-authoring.

Hooks enforce mechanics: SwiftFormat then SwiftLint run on every edited Swift
file (`.swiftformat` is the style authority; `.swiftlint.yml` covers only what
a formatter can't fix; `.swift-format` mirrors the style for Xcode's built-in
formatter), and a Stop hook runs `Scripts/verify.sh test` — a turn cannot end
with a broken build or failing tests, and tests must never be weakened to
satisfy it.
