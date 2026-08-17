# Notes

Append-only working journal (checkpoints skill): short dated entries as
work happens; every commit includes this file's delta.

## 2026-08-16

- Added the checkpoints skill: commit and push at every green
  checkpoint, and keep this journal — requested so work can be
  previewed as it lands. Checkpoint defined as a verifying state to
  stay compatible with the tdd loop (red is never committed).
- Context from earlier today (see git history): skills aligned with the
  Claude Fable 5 prompting guide, and the delegation skill added
  (coding tasks run in subagents on the lowest capable model tier).
- This repo has no git remote yet, so commits land locally and pushes
  aren't possible until one is configured.
- Wrote LEGACY.md: a full analysis of the legacy Secret DJ codebase at
  ~/ws/secret-dj-ios-old (refactor branch), as the reference for the
  rewrite. Produced by an eleven-analyst + completeness-critic agent
  audit; every claim cites its source file. Highlights worth knowing
  before rewrite planning: the consumer app is almost entirely
  server-driven UI (templates + actions in feed JSON); the pub's music
  never plays on the device (the kiosk controls a remote jukebox);
  three SwiftUI pilots already exist behind UserDefaults feature flags;
  and the critic found a load-bearing typo in UserManager's first-run
  defaults that must not be "fixed" (unifying the keys would brick
  fresh installs). Open questions for the product owner are collected
  at the end of the document.

## 2026-08-17

- Renamed notes.md to NOTES.md (via an intermediate Notes.md, then a
  brief NOTES.MD typo, git mv throughout, history preserved) and
  updated every reference (CLAUDE.md, checkpoints/SKILL.md, INDEX.md).
- Added the lazy-sections skill: the pattern for vertically scrolling,
  backend-driven feeds of heterogeneous sections, adapted from
  LazySectionsDemo (~/Code/stacks) — chosen because LEGACY.md shows the
  legacy consumer app is exactly this kind of server-driven feed. The
  12-file golden exemplar was built as live code in the app, verified
  green by the full test suite (with and without the temp code), then
  copied byte-identically into references/ per skill-authoring's
  standalone-catalog rule. Adaptations from the demo: @ScaledMetric
  dimensions and semantic fonts replace fixed points (Dynamic Type
  works, layout still resolves per size change, not per frame), cells
  are combined accessibility elements, RowCell reflows at accessibility
  sizes, fixture text is Text(verbatim:) so the String Catalog stays
  clean. Two review passes (skills compliance + demo fidelity) gated
  the result; their must-fixes (wrapping in the accessibility branch,
  leaf-view previews) are in. Coding ran on sonnet subagents per the
  delegation skill.
- Wrote PLAN.md: the staged rewrite plan for both legacy apps (consumer
  + kiosk) on iOS 27, Spotify removed, shared local packages, five
  languages (Portuguese dropped from the localization skill's set —
  scheduled as convention change S0.5). Ten stages S0–S9 with per-task
  checkboxes; PLAN.md is the single source of truth and statuses ride in
  the same commit as work. Draft was adversarially reviewed on three
  axes (coverage vs LEGACY.md, sequencing/restartability, skills
  conventions) — the coverage critic caught real omissions now included
  (likes/buzz, kiosk skin system + attract config, out-of-credits
  pic-for-credits funnel, voucher/restore flows, .pbz download-then-
  decode preview playback, appmodel=1 and User-Agent wire contract,
  ?RESTART? staff reset) and corrected a kiosk-scope misread (legacy
  kiosk has no queue/skip controls; moderation is consumer-side via
  machinecontrol). Thirteen product decisions (D1–D13) logged with
  defaults; the big open ones are D2 (music catalog/previews without
  Spotify), D3 (venue iPad fleet vs iOS 27), D10 (skin system), and D11
  (server copy is English-only today vs the five-language requirement).
- Product owner decisions received and folded into PLAN.md: platform
  floor lowered to iOS 26; D2 resolved (backend serves music search and
  previews without Spotify — preview Content-Type still to confirm);
  D10 resolved (keep server-based venue skinning, typed manifest); D11
  resolved (multi-language stands; the client sends the device language
  with every server call and the backend returns localized copy — no
  localization-skill amendment needed). D3's fleet check remains open,
  now against iOS 26.
