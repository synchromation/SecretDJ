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
