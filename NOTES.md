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
- Began implementing the plan. S0.4 done: ios-architecture gained the
  multi-target placement rule (single-app features in the app's
  Features/, shared features and infrastructure in local packages;
  packages never depend on app targets), INDEX.md updated in the same
  change.
- S0.5 (all but kiosk seeding): localization is now five languages —
  Portuguese removed from the skill, the adaptation sheets, the live
  String Catalog (reference copy synced byte-identically), and
  knownRegions; CLAUDE.md and INDEX.md updated; verify green. Kiosk
  catalog seeding waits for the S0.2 target.
- S0.1 done: deployment floor set to iOS 26.0 (built with the Xcode 27 /
  iOS 27 SDK — normal arrangement), Swift 6 language mode and default
  MainActor isolation confirmed unchanged; verify green.
- S0.2 done (and S0.5 closed with it): SecretDJKiosk app target
  (iPad-only, landscape, status bar hidden, iOS 26) + hosted
  SecretDJKioskTests with a placeholder Swift Testing suite, shared
  scheme, synchronized folders, five-language kiosk String Catalog, and
  verify.sh extended — it now runs the consumer scheme on the newest
  iPhone simulator and the kiosk scheme on the newest iPad simulator,
  with targeted filters routing to the right scheme. Both schemes green.
  Notes: kiosk bundle id is a placeholder until S0.6;
  UIRequiresFullScreen is deprecated as of iOS 26 (warning only) —
  revisit in S0.6.
- S0.3 done: five local packages scaffolded (SecretDJDomain,
  SecretDJAPI → Domain, FeedUI → Domain, DesignSystem, SharedFeatures →
  Domain+FeedUI+DesignSystem), each with a small real placeholder type
  and native Swift Testing tests; both app targets link all five
  (pbxproj package references + product dependencies); verify's package
  loop now runs six packages, then both schemes — all green. The
  production API host (api4.secretdj.com, confirmed in LEGACY.md) seeds
  SecretDJAPI's environment type; staging is a marked placeholder. A
  linking-proof edit to CounterView was reverted to keep the
  swiftui-views exemplar byte-identical to its reference copy — the
  kiosk root imports DesignSystem instead, and pbxproj product
  dependencies prove consumer linking at build time.
- S0.6 done: legacy bundle ids kept (com.c-burn.secretdj,
  com.secretdj.kiosk) per new decision D14 — the rewrites ship as
  updates to the existing App Store listings, so S9.1 must raise
  CFBundleVersion above the legacy floors (5287/10226). Consumer gets
  its own entitlements (Sign in with Apple + own keychain group, no
  sharing per D5); kiosk has none. ATS confirmed on (zero exceptions
  anywhere). secretdj:// URL scheme deliberately dropped (its only
  consumer was Spotify OAuth); queryable schemes are
  instagram/twitter/uber on the consumer only, via a minimal physical
  Info.plist merged with the generated one. Marketing version 6.0.0.
  Placeholder app icons (violet consumer, amber kiosk).
  UIRequiresFullScreen removed (deprecated on iOS 26; kiosk runs under
  Guided Access). Both schemes verified green, deprecation warning gone.
- S0.7 done — S0 complete. All decisions live in PLAN.md's Decision log
  with owners and defaults; resolved so far by the product owner: D2,
  D10, D11 (2026-08-17) plus the iOS 26 floor; D14 default taken
  (update-in-place). Still open for the product owner: D1 (Facebook
  login), D3 (venue fleet vs iOS 26), D9 (ticker behavior), D12
  (affiliate hand-offs), D13 (kiosk-side moderation). Stage exit
  evidence: hosted test suites launch both apps to their roots on
  iOS 26 simulators in every full verify; all targets and six packages
  exercised; convention changes (S0.4, S0.5) committed.
- S1.1 done (TDD, 95 tests / 46 suites, sonnet subagent): the domain
  vocabulary as value types in SecretDJDomain — Template/ItemType
  (one OptionSet bitmask where legacy had two duplicate enums),
  Action/ActionKind/ActionButton with .unsupported(Int) fallbacks,
  Song with the intermission contract (songId "0", \n\n message
  split), Venue/Person with identity-validated decoding, Artist
  (preserving legacy's outer-level field quirk), TopUp (fixing
  legacy's vendor-cast bug), Promotion, Control (fixing the malformed
  "#00000" default), Item/Section/SectionList, SongRequestResult
  (ReturnCode -8 branch typed), LikeInfo/LikeResult. Item/Section/
  SectionList are deliberately not Decodable — template-driven payload
  dispatch belongs to SecretDJAPI (S1.3); gaps recorded as // S1.3:
  comments. News tab excluded per scope (code 500 → unsupported).
  SwiftLint's inclusive_language note on jukeboxBlacklistSong accepted:
  it is the wire protocol's vocabulary.
- S2.1 done (TDD, 18 tests / 8 suites, sonnet subagent): DesignSystem
  Theme — semantic color roles with explicit light/dark sRGB
  components, ColorToken bridging to dynamic platform colors, a
  sanctioned-pairings table that is itself API, and a native WCAG
  contrast suite proving every sanctioned text/background pairing
  ≥ 4.5:1 in both appearances (lowest margin 5.17:1); typography
  tokens that structurally cannot carry fixed point sizes (semantic
  styles + weight/design only). Brand violet accent, lightened in
  dark mode where the base hue fails contrast. Full verify green
  across six packages and both schemes after both lanes landed.
- Remote wired: github.com/synchromation/SecretDJ (remote name
  "SecretDJ"), main tracking SecretDJ/main, full history pushed. The
  checkpoints convention's push-after-every-commit is now live —
  earlier "no remote" notes are superseded.

## 2026-08-18

- Remote renamed to "origin" (tracking carried over).
- S1.2 done (TDD, 60 tests / 35 suites, sonnet subagent): SecretDJAPI
  request core — APIRequestBuilder with the AFNetworking-compatible
  query encoding pinned against the legacy NetworkAccessTests
  known answers, HMAC-SHA1 request signing (wire compatibility per D7,
  documented as such), SHA-1 password hashing, the applesignin
  day-of-year digest with injected clock/calendar (timezone fragility
  ported deliberately, proven by test), the full implicit parameter
  set (location, appmask OptionSet, client version, device language
  per D11, appmodel=1 kiosk flag) behind a protocol seam, structured
  User-Agent, the ReturnCode/Message envelope as a typed primitive for
  S1.3, and an async transport seam with fake. No endpoint methods yet
  (S1.3).
- S2.2 done (TDD for logic, 33 tests / 14 suites, sonnet subagent +
  code-reviewer pass): DesignSystem components — primary/secondary
  ButtonStyles (44pt targets, token-only theming), ToastQueue
  (@Observable, injected clock, FIFO one-at-a-time with per-toast
  timers) + toastPresenter modifier (VoiceOver announcements,
  reduce-motion cross-fade), BannerSurface chrome, Empty/Error/
  Progress state surfaces that own zero copy. Three contrast-proven
  Theme additions (accentText, accentPressed, accent-on-secondary)
  ride the existing sanctioned-pairings test. Reviewer caught and
  fixed a sub-44pt toast tap area and missing preview variants.
  Full verify green across six packages and both schemes.
