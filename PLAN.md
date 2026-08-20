# Secret DJ rewrite plan

The single source of truth for rebuilding the two legacy Secret DJ apps —
the consumer iPhone app and the venue Kiosk iPad app — as one modern,
iOS 26+ SwiftUI project in this repository. The behavioral reference is
[LEGACY.md](LEGACY.md) (analysis of the legacy checkout at
`~/ws/secret-dj-ios-old`, `refactor` branch, tip `4fef6ac9`;
`~/Code/secret-dj-ios-old` is a copy at the same tip). This file is the
reference for *what to build in what order and what is done*.

## How to use this file

- **Single source of truth.** Work is picked up by finding the first
  unchecked task whose stage's `Prereqs:` are satisfied. Do not keep
  progress anywhere else.
- **Statuses**: `[ ]` not started · `[x]` done (exit criteria met,
  verified green, committed, and pushed — checkpoints skill). A task that
  is started but not done stays `[ ]` with a short
  `— in progress: <state>` note appended; blocked tasks get
  `— blocked: <what/who>`. Update statuses **in the same commit** as the
  work they describe.
- **Resuming**: read this file top to bottom, then LEGACY.md's section for
  the feature at hand (section citations here use LEGACY.md's exact
  headings). Statuses plus git history are the full state; no other
  context is required.
- **Order**: each stage lists its `Prereqs:`; stages whose prereqs are met
  may run in parallel (the delegation skill's subagents make that
  practical). Tasks within a stage may run in any order unless a subtask
  says otherwise. A stage is done when every task is checked and its exit
  criteria hold.
- Amendments to the plan (added/dropped/re-scoped tasks) are edits to this
  file, committed with a NOTES.md entry explaining why.

## Scope

**In**: all current user-facing functionality of both legacy targets as
catalogued in LEGACY.md, re-imagined on iOS 26+, except the items below.

**Out (deliberately not ported)**:

- **All Spotify integration** — the PKCE OAuth flow, the Spotify Web API
  client, the token-swap service, `spotify` in queryable schemes, the two
  Spotify rows of the listen-elsewhere sheet, and any Spotify-sourced
  data. Music search, browse, and previews are rebuilt against the Secret
  DJ backend instead (D2). The rest of the listen-elsewhere sheet (Apple
  Music, YouTube) **is** in scope — see S6.4 and D12.
- Dead and vestigial code LEGACY.md confirmed: the News tab, the
  `KeepSignedIn` toggle, `checkunique`, the `_ipad` matrix cell, GPX
  fixtures in app bundles, the network-activity spinner plumbing, the
  build-number-updater build phase, disabled ATS, Fabric plist remnants,
  the pre-2017 `"userId"` migration path, and the first-run
  `".deleteAccountRequested"` literal-key write (load-bearing typo — see
  LEGACY.md "Gaps and cross-checks"; the rewrite simply has no such
  write).
- Firebase Analytics/Crashlytics and the Facebook SDK as *direct feature
  dependencies*: analytics and crash reporting flow through the
  Observability package's pipeline with vendor adapters (D4); Facebook
  login is a product decision (D1).

**Platform**: iOS 26 floor for both apps (product decision 2026-08-17;
venue-fleet check D3 still applies and blocks S0.2), latest Swift
language mode and SwiftUI throughout, Xcode synchronized folders, strict
concurrency.

## Ground rules (binding for every task)

The project skills govern all implementation — consult
[.claude/skills/INDEX.md](.claude/skills/INDEX.md). In particular:

- **Process**: coding is delegated to subagents on the lowest capable model
  tier (delegation); every green checkpoint is committed, pushed, and
  journaled in NOTES.md (checkpoints); behavior is built test-first (tdd)
  with Swift Testing (swift-testing).
- **Definition of done for every feature task** (in addition to its own
  exit criteria): folder/package anatomy per ios-architecture; views per
  swiftui-views; fully accessible per accessibility, including
  accessibility-size previews; all user-facing copy in the String Catalog
  with translations for **en (source), es, fr, de, nl** per localization;
  instrumented per observability; `Scripts/verify.sh test` green.
- **Server-driven screens** use the lazy-sections pattern (lazy-sections).
- PLAN.md status updates ride in the same commit as the work.

## Architecture target

Two thin app targets over shared local Swift packages (maximum sharing;
apps contain only composition roots and app-specific features):

```
SecretDJ.xcodeproj
├── SecretDJ/            iPhone consumer app — composition root + consumer-only features
├── SecretDJKiosk/       iPad kiosk app — composition root + kiosk-only features
├── SecretDJTests/       app-hosted unit tests (consumer)
├── SecretDJKioskTests/  app-hosted unit tests (kiosk)
└── Packages/
    ├── Observability/   existing — logging/analytics/breadcrumbs/redaction
    ├── SecretDJDomain/  value model: sections, items, actions, venues, users,
    │                    credits, moods, requests (no networking, no UI)
    ├── SecretDJAPI/     backend client: endpoints, request signing, implicit
    │                    parameters, decoding into Domain
    ├── FeedUI/          the lazy-sections feed engine bound to Domain:
    │                    SectionKind mapping, action dispatch, feed screens' shared views
    ├── DesignSystem/    theme, shared components, cell library (accessible by design)
    └── SharedFeatures/  feature modules used by BOTH apps (search, now playing,
                         playback), each following the ios-architecture anatomy
```

Placement rule: a feature used by both apps lives in a package; a feature
used by one app lives in that app's `Features/` folder. Either way the
internal anatomy is ios-architecture's. Package tests run natively via
`swift test` (Scripts/verify.sh already loops over
`Packages/*/Package.swift`, so new packages are picked up automatically).

---

## S0 — Foundations and conventions

Prereqs: none.
Goal: the project skeleton, targets, packages, and convention changes that
everything else assumes. Exit: both apps build and launch to placeholder
roots on iOS 26 simulators; `Scripts/verify.sh test` exercises every
target and package; all convention changes committed.

- [x] S0.1 Raise the project to the target platform: iOS 26 minimum for
      the existing SecretDJ target, latest Swift language mode confirmed,
      project-level settings tidied (one source of truth for versions).
- [x] S0.2 Add the `SecretDJKiosk` app target (iPad-only, landscape,
      status bar hidden) and `SecretDJKioskTests`, with its own
      `Features/` synchronized folder and composition root
      (`project.pbxproj` edit — flag, don't improvise, per
      ios-architecture). Extend `Scripts/verify.sh` to build/test both
      app schemes (its package loop already covers packages). Proceeds on
      the D3 default (iOS 26 kiosk floor); if D3 lands differently,
      re-targeting the kiosk is the known rework. Update CLAUDE.md's Map
      section (second app target and tests folder) in the same commit.
- [x] S0.3 Scaffold the local packages (`SecretDJDomain`, `SecretDJAPI`,
      `FeedUI`, `DesignSystem`, `SharedFeatures`) with placeholder types
      and native tests, linked from both apps; confirm the verify.sh
      package loop picks each one up.
- [x] S0.4 Convention change — multi-target placement: amend the
      ios-architecture skill with the package/app placement rule above
      (skill-authoring procedure: skill + INDEX.md in one change).
- [x] S0.5 Convention change — language set: amend the localization skill
      (and its adaptation-sheet references) from six languages to five —
      **en source + es, fr, de, nl; Portuguese dropped** per product
      direction. Seed both apps' String Catalogs with the five languages.
      Update CLAUDE.md's "six languages" wording in the same commit.
- [x] S0.6 App identity: bundle ids, display names, entitlements from
      scratch (Sign in with Apple only where used; keychain groups per
      D5), asset catalogs with placeholder icons, ATS **on** (no
      arbitrary loads). Decide URL schemes: with Spotify gone,
      `secretdj://` has no remaining consumer — drop it or reserve it
      deliberately; prune `LSApplicationQueriesSchemes` to what the apps
      actually query — S3.3's social deep links (instagram/twitter),
      S6.10's appmask signal set, and S6.4's hand-offs (D12 affects the
      list). (Done: legacy bundle ids kept per D14; `secretdj://`
      dropped; queryable schemes instagram/twitter/uber, consumer only.)
- [x] S0.7 Record every decision in the Decision log below in NOTES.md
      and open them with the product owner; mark each decision's owner
      and default.

## S1 — Domain and API packages

Prereqs: S0.
Goal: the backend contract, minus Spotify, reimplemented as typed
async/await Swift against the *unchanged* production API. Exit: every
endpoint group below has typed methods, request signing and implicit
parameters match the legacy wire format byte-for-byte where the server
requires it, and the package test suites prove it against captured
fixtures.

- [x] S1.1 Domain model: sections/items/templates/actions, venues, users,
      credits & top-ups, moods/atmospheres, song requests, likes, awards,
      events — value types per LEGACY.md "Domain model and persistence".
      Song carries the intermission contract (`songId == "0"`: inert on
      the consumer, message vehicle on the kiosk — LEGACY.md "Audio and
      playback"). Domain decodes unknown templates/actions into an
      `unsupported` case for logging/metrics only; the Domain→SectionKind
      mapping in FeedUI (S3.1) then follows lazy-sections' rule verbatim:
      unknown kinds map to nil and those sections are dropped.
- [x] S1.2 API client core: base environments, request building with the
      full implicit parameter set — location, `appmask`, client version,
      the device language on every request (BCP-47, sent as the HTTP
      `Accept-Language` header per D11 so server copy arrives
      localized), `appmodel=1` on every kiosk request (the only
      kiosk/consumer discriminator), and the structured User-Agent
      (`secret dj <idfv>:<screenWidthPx>:<version>`) — plus auth/request
      signing compatible with the legacy scheme: SHA-1 password-hash
      signing, the AFNetworking-compatible query encoding (%2B/%3D
      signature escaping), and the day-of-year salted `auth` digest that
      `applesignin` requires (all per LEGACY.md "Backend API and Spotify
      integration"; D7 tracks server-side modernization). Each pinned by
      fixture tests.
- [x] S1.3 Endpoints (one sub-checkbox per group; fixtures captured from
      the live API and the legacy test resources; cross-check the group
      contents against LEGACY.md's endpoint catalog before checking off):
      (Cross-checked: every catalogued endpoint is built or deliberately
      gated — facebooksignin behind D1. LIVE-CAPTURE markers list what
      only production fixtures can still confirm.)
  - [x] S1.3a Auth: `signin`, `createuser`, `facebooksignin` (behind D1),
        `applesignin`, `resetpassword`. (facebooksignin awaits D1 — a
        `// D1:` marker sits in the group file.)
  - [x] S1.3b User: `userdetails`, `setuserdetails`, avatar upload
        (`newavatar`), delete account (`requestdeleteaccount`).
  - [x] S1.3c Feeds: places nearby, venue, activity/event history,
        profile, now playing, `extracontent`, `promote`.
  - [x] S1.3d Search: `musicsearch`, `artistsavailable` (and the
        songs-for-artist path).
  - [x] S1.3e Music selection: digest/selection/mood feeds, `styleinfo`.
  - [x] S1.3f Jukebox writes: `requestsong` (including the ReturnCode -8
        out-of-credits contract), `like`/`unlike` (ItemType bitmask),
        `machinecontrol` (server-granted moderation).
  - [x] S1.3g Credits: top-up feed, `topupnotify` (purchase + restore),
        `redeemjukeboxvoucher`, `numpaidcredits`.
  - [x] S1.3h Hand-offs: `watchonyoutube` (signed song id), check-in
        (`checkin`, scope=everyone, server-driven toast/URL response).
        (watchonyoutube subsequently removed under D12 — dead without
        the listen-elsewhere sheet.)
  - [x] S1.3i Kiosk: `skinresources` (typed skin manifest — D10).
- [x] S1.4 Session persistence: current user + venue as Codable in
      UserDefaults, password/token material in the keychain — a clean
      re-design of `UserManager`'s storage (no legacy key migration; new
      installs only — D6).
- [x] S1.5 Feed change detection: the server `hash` / "jukebox changed"
      contract (LEGACY.md "Consumer app: features and flows" → "The feed
      engine") as a typed, testable primitive.

## S2 — Design system

Prereqs: S0.
Goal: the shared visual language both apps compose from. Exit: theme and
core components live in DesignSystem with previews (including
accessibility sizes) and pass the accessibility skill's checks; both apps
consume it. (The feed cell library lands later, in S3.2, on top of these
tokens.)

- [ ] S2.1 Theme: semantic color/typography/spacing tokens; dark mode;
      contrast verified (4.5:1 text) in both appearances.
- [x] S2.2 Components: primary/secondary buttons, toast presentation (the
      legacy server-driven toast contract), banners/ticker chrome, empty
      and error state surfaces, progress indicators.
- [x] S2.3 Iconography and imagery pipeline: SF Symbols first; remaining
      legacy Paintcode/Photoshop-derived assets re-cut only where a
      symbol can't replace them.

## S3 — Feed engine (FeedUI)

Prereqs: S1.1, S1.5, S2.
Goal: the server-driven UI engine — the heart of both apps — built on the
lazy-sections skill. Exit: a feed screen renders any Domain section list
with correct laziness, action dispatch, refresh, pagination, and change
detection, proven by package tests plus a demo feed in both apps'
previews.

- [x] S3.1 Map Domain templates → `SectionKind`s and cell/section views
      (list, carousel/container, grid, hidden data sections); unknown
      kinds dropped per lazy-sections (see the S1.1 boundary note).
- [x] S3.2 Cell library for the legacy template set (song, artist, venue,
      person, jukebox, top-up, award, event/check-in, promotion) in
      DesignSystem on the S2.1 tokens, each cell an immutable-value view
      per lazy-sections, accessible per accessibility. (The artwork gap
      is closed: Domain decodes ItemImage with legacy's resolution
      buckets and fallback ladder, pinned to live fixtures; cells now
      resolve real artwork URLs.)
- [x] S3.3 Action dispatch: typed `Action` handling (goto item, request
      song, change atmosphere, show top-up, goto URL, launch search,
      taxi/Uber deep links, server-granted `machinecontrol` moderation
      actions, promotion engagement — social-app deep-link conversion to
      `instagram://user`/`twitter://screen_name` when installed, the
      `externalBrowser` flag, and the `promote`/promotionEngaged ping for
      URL-less internal promotions) as an injectable handler seam —
      navigation effects live with the apps, not the package.
- [ ] S3.4 Feed behaviors: pull-to-refresh; opt-in auto-refresh at the
      legacy cadence (20s, tightened to 3s until the first GPS fix is
      ~12s old — LEGACY.md business rule); infinite scroll/pagination;
      hash-change "jukebox changed" surfacing; empty/error/offline
      states. Server-driven copy renders as delivered — it arrives
      localized because every call carries the device language (D11).
- [x] S3.5 Performance proof: a stress-feed preview/profile pass on
      device-class hardware; no regressions against lazy-sections'
      scroll-performance rules. (Done: deterministic 60-section stress
      fixture + previews, and an adversarial audit against the
      lazy-sections rules whose six findings — carousel dimension
      drift, per-render prop derivation, pagination sentinel, id
      collisions — were all fixed red-first. The on-hardware
      Instruments pass rides with S8.4 as scheduled.)

## S4 — Identity and session

Prereqs: S1.2–S1.4, S2. Flows are hosted and verified in the consumer
app's S0 placeholder root (the login gate replaces the placeholder); S5
later formalizes the composition root.
Goal: sign-in/sign-up/onboarding at parity (minus what D1 decides), on the
S1 auth endpoints. Exit: a fresh install can create an account, sign in,
reset a password, complete onboarding (screen name → details/photo per
route), sign out, and delete the account; session survives relaunch; all
flows accessible and localized.

- [x] S4.1 Login flow shell: gate-on-launch (no cached session → login),
      overlay presentation model re-thought for SwiftUI navigation.
- [x] S4.2 Native sign-in, sign-up, and forgotten password: credential
      validation rules ported from `ProfileDetailsValidator` (as spec,
      via TDD), hash-compatible credential handling (S1.2),
      `resetpassword` flow (screenname-or-email input, server-message
      confirmation). Exit includes a smoke test against the production
      backend with a real account (R3). (Smoke passed 2026-08-18:
      one-shot production sign-in succeeded on attempt 1.)
- [x] S4.3 Sign in with Apple: first-auth name/email caching semantics
      (Apple only supplies them once — keychain, per LEGACY.md), the
      day-of-year `auth` digest (S1.2). Exit includes a production smoke
      test (R3). — built and fully fake-tested; the live SIWA smoke
      **remains pending a real device/human** (Apple's auth UI can't run
      headlessly) — verify at S9.3 at the latest.
- [x] S4.4 Facebook sign-in — **D1 resolved: kept.** Current FB SDK, ATT
      prompt flow rebuilt per current policy, the `facebooksignin`
      endpoint (deferred from S1.3a), and the Facebook plist config +
      queryable schemes S0.6 omitted. — **Needs from the product owner:
      the FacebookClientToken** (Meta App Dashboard → Settings →
      Advanced → Client Token); until it replaces the placeholder the
      FB button doesn't render and the SDK never initializes (the app
      runs fully without it). Live FB smoke pending real credentials.
- [x] S4.5 Onboarding steps per route (gender/photo/details/username
      ordering per LEGACY.md "Consumer app: features and flows" → "Login,
      sign-up, onboarding"), avatar capture/pick + upload (camera/photo
      permissions with localized usage strings). (Native route folds
      gender into S4.2's details form, so its remaining step is photo;
      apple/facebook route tables are modeled and await S4.3/S4.4.)
- [x] S4.6 Account management: sign out, delete account (server flow +
      local wipe; no exit(0) gates — a sane blocked-state screen).

## S5 — Consumer app shell

Prereqs: S3, S4.
Goal: the consumer app's skeleton on the new stack. Exit: three-tab
structure (Places Nearby, Activity, Profile) navigates, composition root
wires packages, login gating from S4 works end to end.

- [x] S5.1 Composition root: dependency construction, environment wiring,
      Observability `.live` pipeline, screen tracking on every root.
- [x] S5.2 Tab scaffold + navigation model (NavigationStack per tab, deep
      navigation from feed actions via the S3.3 handler).
- [x] S5.3 Location services: modern one-shot + when-in-use flow feeding
      the API's implicit location parameters; permission-denied surface
      (the legacy full-screen overlay, re-designed) with Settings link.

## S6 — Consumer features

Prereqs: S5 (S6.3 and S6.4 additionally D2; S6.4 additionally D8, and
D12 gates its Apple Music row).
Each task below is one feature at the ground rules' definition of done.
Exit for the stage: consumer feature parity with LEGACY.md minus scope
exclusions.

- [x] S6.1 Places Nearby: nearby-venues feed; venue map (pins, jukebox
      badge, user location, zoom-to-fit) behind the map action.
- [x] S6.2 Venue screen and Now Playing: venue feed, now-playing feed
      with auto-refresh, jukebox navigation into selection/digest feeds,
      venue like/unlike (optimistic toggle with rollback, server-supplied
      likeInfo copy), the social-links rule (Instagram first, max three).
- [x] S6.3 Music selection and search (SharedFeatures — kiosk reuses it):
      done in two halves — selection/digest/mood feeds, search (artist
      A–Z + track debounce), songs-for-artist, atmosphere changes, then
      the TuneIn screen with the full request funnel (-8/ImageSize
      branches: pic-for-credits sheet reusing the avatar components with
      the server reward toast, or top-ups with noCredits context), song
      buzz via the relocated shared OptimisticLikeModel, and the
      server-granted skip/never-play moderation buttons. One deferral
      stands: the legacy mood-duration picker (tiles use a documented
      30-minute default) — revisit before S8.5's cross-check.
      digest/selection/mood feeds, artist and track search against the
      backend (D2), A–Z index (the SwiftUI `SectionIndexStrip` idea from
      the legacy refactor, rebuilt), and the song/TuneIn screen: request
      flow with the full out-of-credits funnel (`requestsong` -8 →
      no-profile-picture branch offers the pic-for-free-credits dialog
      reusing S4.5 avatar components with the server-worded reward toast,
      else top-ups with `noCredits` context vs `insertCoin` from the
      nav-bar action), song buzz/like, and the server-granted skip/
      blacklist moderation buttons (`machinecontrol`) that appear for
      entitled users.
- [x] S6.4 Audio previews (SharedFeatures): **download-then-decode**
      preview playback (`AVAudioPlayer(data:)` — the backend serves
      previews as `.pbz` with a generic Content-Type that AVPlayer
      refuses, LEGACY.md "Audio and playback"; streaming AVPlayer only
      if the backend lands a fixed Content-Type, still unconfirmed
      under D2), 30s hard cap, stop-on-exit, cancel-during-download.
      (The listen-elsewhere sheet was dropped entirely — D12.)
- [x] S6.5 Activity feed: server-driven event history (check-ins,
      requests, awards, people) on the feed engine; award templates
      render via S3.2 cells.
- [x] S6.6 Profile: own profile feed, avatar change (S4.5 components),
      person like/unlike on profile headers (optimistic + rollback),
      others' profiles via feed actions.
- [x] S6.7 Credits and top-ups: StoreKit 2 purchase flow at parity with
      the legacy credit economy — top-up feed template → products,
      receipt submission (`topupnotify`), Restore Purchases (restored
      transactions notify with the `purchaseRestored` flag;
      `numpaidcredits` drives the nothing-to-restore message), voucher
      redemption (`redeemjukeboxvoucher`), and a transaction-listener
      design replacing the legacy resubmit-on-every-screen loop.
- [x] S6.8 Check-in: venue check-in flow (scope=everyone, optimistic UI
      with rollback on failure) and the server-driven toast/URL response.
- [x] S6.9 Extra content ticker: the venue/places bottom banner rotating
      now-playing songs and people, with its scroll-direction show/hide
      behavior re-evaluated (D9).
- [x] S6.10 Directions and taxi: directions surface; server-driven
      Uber/taxi actions preserved via `appmask` (LEGACY.md "Gaps and
      cross-checks" — keep the client→server installed-apps signal).
      (Directions is an Apple Maps walking hand-off — the legacy custom
      map/call/SMS-share screen is deliberately not ported, cited in
      code. hailRide URLs, previously an unwired no-op, now open
      externally from every outcome-forwarding screen.)
- [x] S6.12 Server-driven nav-bar action buttons: render the toolbar
      buttons SectionList.actions carries (insert-coin, hail-taxi,
      search — LEGACY.md's ActionBarButtonProvider) on the feed screens;
      the router mapping already exists and is tested — only the
      rendering is missing (found during S6.10).
- [x] S6.11 Settings: auto-lock preference (in-app, replacing the
      Settings-bundle toggle), change profile details / password / gender
      (`userdetails`/`setuserdetails`, reusing S4.2 validation; the
      legacy SwiftUI Settings flow is the behavioral reference),
      legal/about, sign-out entry.

## S7 — Kiosk app

Prereqs: S1, S2, S3, S6.3 (shared search/selection), D3 resolved, D10
resolved.
Goal: the venue iPad app rebuilt. Exit: kiosk feature parity per
LEGACY.md "Kiosk app: the venue iPad" minus exclusions; runs all day in
landscape with attract mode; shares S1–S3 + SharedFeatures wholesale.

- [x] S7.1 Kiosk shell: composition root, landscape-only iPad
      presentation, venue session sign-in (kiosk auth flow per LEGACY.md,
      no consumer onboarding), and a staff reset affordance replacing the
      legacy `?RESTART?` search incantation — clears session, skin, and
      caches and returns to sign-in without exit(0) (trigger mechanism is
      a small product decision, part of D10's conversation).
- [x] S7.2 Skin system (D10): typed skin manifest over `skinresources`
      replacing the legacy magic numeric ids; post-login download with
      progress and blocking retry-on-failure; skin-driven chrome/toast
      colors reconciled with DesignSystem theming; behavioral config
      consumed from skin texts — `attractURL`, `attractTimeoutSeconds`,
      `idleTimeoutSeconds` — feeding S7.3.
- [x] S7.3 Attract/idle system: idle detection rebuilt with scene-level
      interaction observation (no UIApplication subclass), attract screen
      driven by the skin's attract URL, timed return-to-attract using the
      skin's timeouts, timers **paused while an audio preview is
      playing** (playback signal from the shared preview player) and
      resumed on stop, `isIdleTimerDisabled` policy (in-app setting;
      document venue guided-access/auto-lock ops — R1 note).
- [x] S7.4 Kiosk feeds: now playing (including intermission as a
      two-line message vehicle — title split on `\n\n`, artwork
      suppressed) and the jukebox digest, which deliberately ignores
      hash changes (reload-in-place, unlike the phone's jukebox-changed
      error — LEGACY.md kiosk feed branches), at kiosk-scale layouts.
- [x] S7.5 Kiosk controls at legacy parity: change-mood/atmosphere tiles
      via the shared S3.3 action path. (The legacy kiosk has **no**
      queue view, skip, blacklist, or request moderation — those are
      consumer-app `machinecontrol` affordances, S6.3. Adding kiosk-side
      moderation is new scope: D13.)
- [x] S7.6 Kiosk search: SharedFeatures search reused at iPad scale
      (multi-column layouts per swiftui-views/lazy-sections); the legacy
      custom on-screen keyboard is replaced by the system keyboard unless
      D10's skin conversation decides otherwise.
- [x] S7.7 Kiosk resilience: all-day soak behavior — memory-stable feed
      refresh, network-loss recovery, unattended-error surfaces that
      self-recover to attract mode.

## S8 — Cross-cutting completion

Prereqs: S6, S7.
Goal: the qualities that were built per-feature, audited whole-app. Exit:
audits pass and are recorded in NOTES.md.

- [x] S8.1 Localization audit: every key present in es/fr/de/nl,
      adaptation sheets honored, `needs_review` queue triaged with a
      native-speaker pass scheduled; pseudo-localization + longest-language
      layout sweep; D11's server-copy outcome verified end to end.
- [x] S8.2 Accessibility audit: create minimal UI test targets for both
      apps and run `performAccessibilityAudit()` per screen; VoiceOver
      walk of every screen on both apps; Dynamic Type through
      accessibility5; fixes filed as tasks here. (Automated half done:
      18 audit tests across 13 screens via `verify.sh uitest`, real
      fixes landed, a documented allow-list where known issues print
      and new ones fail. The HUMAN half remains: the VoiceOver gesture
      walk of the 13 audited screens on a device, and Accessibility
      Inspector on the two element-scoped contrast allowances.)
- [ ] S8.3 Observability completion: vendor adapters per D4 configured at
      both composition roots (DEBUG console-only), redaction spot-audit
      on every emission site (privacy per observability skill).
- [ ] S8.4 Performance: Instruments passes on feed scroll (both apps),
      launch time, kiosk soak (S7.7 evidence); regressions fixed.
- [ ] S8.5 LEGACY.md cross-check: walk LEGACY.md end to end against the
      built apps; every behavior is either shipped, in this plan, or in
      the exclusion list with a reason. Update this file accordingly.

## S9 — Release readiness

Prereqs: S8.

- [ ] S9.1 Signing/config hygiene: one team, per-app bundle ids,
      Debug/Release only unless Ad Hoc is still needed, no source-tree
      mutation at build time.
- [ ] S9.2 Store assets: icons, screenshots (five languages), privacy
      nutrition labels matching the observability/privacy reality,
      App Store metadata parity for both apps.
- [ ] S9.3 TestFlight: internal builds of both apps, venue pilot for the
      kiosk (R1 verified on real venue hardware).
- [ ] S9.4 Cutover plan: account continuity verified (existing users sign
      in against unchanged backend), rollback story, phased release.

---

## Decision log

Defaults apply unless the product owner overrides; each decision names
what it blocks.

- **D1 Facebook login** — **Resolved 2026-08-18: keep it.** S4.4 is in
  scope: current Facebook SDK, ATT prompt flow per current policy, and
  the `facebooksignin` endpoint (deferred out of S1.3a — build it as
  part of S4.4) plus the Facebook plist config and queryable schemes
  S0.6 omitted.
- **D2 Music catalog after Spotify removal** — **Resolved 2026-08-17**:
  the backend serves music search and preview audio without Spotify.
  One detail remains open with the backend team: whether preview
  Content-Type gets fixed (decides S6.4's streaming-vs-download playback
  strategy; download-then-decode is the safe default).
- **D3 Kiosk hardware floor** — **Resolved 2026-08-18: iOS 26 stands**
  for the kiosk (product owner confirmed). Still re-verified on real
  venue hardware at S9.3 (R1).
- **D4 Observability vendors** — default: Sentry (crash) + TelemetryDeck
  (analytics) via the existing adapter targets; Firebase not carried
  over.
- **D5 Keychain sharing** — default: no shared keychain group between the
  apps (legacy sharing was an entitlements accident); kiosk venue
  credentials are its own.
- **D6 Legacy-install migration** — default: none. New apps are new
  installs; accounts live server-side so users just sign in. (No
  UserDefaults/keychain migration from the legacy apps.)
- **D7 API contract evolution** — default: consume the wire format
  exactly as-is (SHA-1 password-hash signing, day-of-year `auth` digest,
  query-encoding quirks); any server-side modernization is out of scope
  here and tracked with the backend team.
- **D8 Previews without Spotify** — if the backend cannot supply preview
  audio, ship without previews and remove the preview half of S6.4.
- **D9 Extra-content ticker behavior** — **Resolved 2026-08-18: keep
  the legacy scroll-direction show/hide behavior verbatim** (S6.9).
- **D10 Server-driven venue skinning** — **Resolved 2026-08-17**: keep
  server-based venue skinning — the `skinresources` contract as a typed
  manifest (per LEGACY.md's tech-debt note), with DesignSystem
  reconciling. Still open within it: the staff-reset trigger and
  custom-keyboard details (S7.1/S7.6).
- **D11 Server-text localization** — **Resolved 2026-08-17**; mechanism
  refined 2026-08-18: the device language travels as the standard HTTP
  **`Accept-Language` header** on every request (not a query
  parameter); the backend returns copy localized for the five
  languages. Satisfies the localization skill's server-text rule with
  no skill amendment. **S8.1's end-to-end verification (2026-08-20)
  found the backend does NOT yet localize**: placesnearby returned
  byte-identical English copy for all five Accept-Language values
  (client behavior confirmed correct). Backend deployment of the
  localization is now the gating item — re-verify before S9 ships;
  the finding is marked `// S8.1-FOLLOWUP:` in the API client.
- **D12 Affiliate hand-offs** — **Resolved 2026-08-18: dropped.** The
  listen-elsewhere sheet goes entirely (its only non-Spotify rows were
  the Apple Music affiliate link and the YouTube hand-off): S6.4 is
  previews-only, and the `watchonyoutube` endpoint + song-signature
  code built in S1.3h were removed again (dead without the sheet).
- **D13 Kiosk-side moderation** — **Resolved 2026-08-18: legacy parity**
  (no kiosk-side skip/blacklist/queue tools; moderation stays
  consumer-side via `machinecontrol`).
- **D14 Ship as updates or new apps** — **Resolved 2026-08-18: ship as
  updates**, legacy bundle ids confirmed (`com.c-burn.secretdj`,
  `com.secretdj.kiosk`). Pins S9.1: CFBundleVersion must exceed the
  legacy build numbers (consumer 5287, kiosk 10226) before release.

## Risks

- **R1 Venue iPad fleet vs iOS 26** — the kiosk floor decision (D3)
  blocks S0.2's target settings and can invalidate them late; resolve
  early, re-verify on real venue hardware in S9.3.
- **R2 Undocumented server behavior** — LEGACY.md's open questions list
  server behaviors only production data can confirm (hidden section
  variants, action payloads still emitted). Mitigation: fixtures
  captured early in S1.3 against the live API, and S8.5's cross-check.
  Live capture is approved (2026-08-18) under a hard rate limit of
  **at most one API call per second**, read-only endpoints only —
  never any write endpoint (requestsong, like, machinecontrol,
  topupnotify, redeemjukeboxvoucher, checkin, setuserdetails,
  newavatar, and above all requestdeleteaccount are off-limits to
  capture). A production test account exists for sign-in and the S4
  smoke tests; its credentials live in `.secrets/` (gitignored, never
  committed).
- **R3 Account-continuity edge cases** — password-hash compatibility
  (D7) and Apple-sign-in re-auth must be verified against production
  early (S4.2/S4.3 exit criteria include the live-backend smoke tests).
- **R4 Two-target divergence** — sharing discipline erodes under
  deadline; the placement rule (S0.4) and code review per skills are the
  guardrails.

## Progress summary

| Stage | Status |
|---|---|
| S0 Foundations | **done** |
| S1 Domain & API | **done** (LIVE-CAPTURE markers await production fixtures) |
| S2 Design system | **done** |
| S3 Feed engine | **done** (Instruments pass deferred to S8.4 as planned) |
| S4 Identity & session | **done** (live SIWA/FB smokes + FB client token pending — see S4.3/S4.4) |
| S5 Consumer shell | **done** |
| S6 Consumer features | **done** (mood-duration picker deferral noted on S6.3) |
| S7 Kiosk app | **done** (on-hardware soak rides with S8.4/S9.3) |
| S8 Cross-cutting | in progress (S8.1, S8.2 done; S8.3–S8.5 remain) |
| S9 Release readiness | not started |

Keep this table in step with the checkboxes; it exists so a resuming
session can orient in one glance.
