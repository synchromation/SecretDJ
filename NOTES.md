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
- S1.4 done (TDD, sonnet subagent; SecretDJAPI now 84 tests / 43
  suites): SessionStore (@Observable) with restore-on-init and
  both-stores-present signed-in gate (mirroring legacy
  requiresLogin()), UserDefaults snapshot store + keychain credential
  store each behind a protocol with an in-memory fake, keychain query
  construction factored for keychain-free testing. Purpose-built
  SessionUser/SessionVenue projections instead of reusing feed-item
  Person/Venue (those are Decodable-only feed types). No first-run
  writes of any kind (the legacy trap), proven by test. Observability
  wiring deliberately left to composition roots.
- S1.5 done (TDD, sonnet subagent): FeedChangeDetector in FeedUI —
  establish/page state machine over FeedHash with the two legacy
  policies (surfaceChange for the consumer's jukebox-changed flow,
  reloadInPlace absorbing hash changes for the kiosk digest).
  Superseded and deleted the S0.3 FeedRenderState placeholder; the
  SharedFeatures placeholder was updated to compose the new detector
  (haiku subagent). Full verify green.
- S1.3a+b done (TDD, sonnet subagent; SecretDJAPI now 121 tests / 56
  suites): auth endpoints (signin/createuser/applesignin/resetpassword
  — facebooksignin deliberately absent behind D1) and user endpoints
  (userdetails/setuserdetails/newavatar multipart/requestdeleteaccount)
  as APIClient extensions, with legacy JSON fixtures copied into the
  package's test resources and wire expectations cited to legacy
  sources. Multipart construction ported byte-for-byte, with one
  documented deliberate divergence: implicit parameters (incl. lang
  per D11) ride multipart requests too. LIVE-CAPTURE markers record
  what only production can confirm (userdetails layout, newavatar
  response shape, requestdeleteaccount). PasswordChangeFail.json
  proved the Success-true-with-negative-ReturnCode envelope quirk.
- S2.3 done — stage S2 complete: Theme.Icon token set (21 semantic
  roles mapped to SF Symbols, checked against the legacy action-bar
  asset names), every symbol name pinned by a parameterized
  platform-resolution test; SF-Symbols-first policy recorded, legacy
  asset re-cuts deferred to consuming tasks. Full verify green.
- S1.3c+d+e done (TDD, sonnet subagent; SecretDJAPI now 186 tests /
  85 suites): SectionListDecoder — the template-driven payload
  dispatch S1.1 deferred, tolerant per legacy (malformed item drops,
  section survives; unknown template → .unsupported items, sections
  kept for FeedUI to drop) — plus feed endpoints (placesnearby, venue,
  eventhistory, profile, playhistory, extracontent, promote), search
  (musicsearch, songs-for-artist via the legacy artists-query quirk,
  artistsavailable flat payload), and selection/digest/styleinfo.
  Seven legacy fixtures copied and cited. IMPORTANT: real fixtures
  exposed two S1.1 Domain bugs — Action.itemId and
  Venue.hasMachineControl decode strictly as Int where the wire sends
  string/bool variants, silently dropping all request-action songs and
  most venues; currently pinned as known-gap regression tests, fix
  follows immediately.
- S3.1 done (TDD, sonnet subagent; FeedUI now 51 tests / 15 suites):
  FeedSectionKind mapping (list/carousel/grid/hidden families per the
  legacy template table; unsupported → nil, dropped with
  DroppedSection reporting so callers can log — FeedUI never imports
  Observability), FeedDisplayModel projection with typed hidden-
  section accessors and stable server-derived ids, and the concrete
  FeedView/FeedSectionView dispatch per the lazy-sections exemplar
  with themed placeholder cells (S3.2 replaces them). FeedUI now
  depends on DesignSystem per the architecture diagram.
- Domain wire-variance fix (tdd bug rule: red first; sonnet subagent):
  a fixture-wide type scan confirmed exactly two variant keys — ItemId
  (int/string) and MachineControl (int/bool/string). Lenient decoding
  helpers applied at only those two proven sites; the known-gap pins
  in SecretDJAPI flipped to positive assertions (78/78 MusicSelection
  songs, 50/50 StyleInfo songs, all venues, hasMachineControl correct
  across representations). Domain 103 tests / API 187 tests.
- S1.3f–i done — stage S1 complete (TDD, sonnet subagent; SecretDJAPI
  now 234 tests): requestsong with the -8/ImageSize funnel typed
  through the envelope, like/unlike over the ItemType bitmask,
  machinecontrol (400/401/402), top-up feed + topupnotify
  (credited/alreadyProcessed/retryable outcomes, multipart reused),
  redeemjukeboxvoucher, numpaidcredits, watchonyoutube with the
  song-signature port, checkin (scope=everyone), and skinresources →
  typed SkinManifest (attract/idle config, toast appearance, full
  color/asset role enums, unknown entries preserved raw for forward
  compatibility — the S7.2 contract). Judgment call recorded:
  RequestSongFail.json's Success:false envelope treated as a
  fixture-authoring mistake vs its siblings; pinned as APIError.server
  with citation. LIVE-CAPTURE gaps: watchonyoutube, numpaidcredits,
  the -8/ImageSize branch, topupnotify ReturnCode 1. Full verify
  green.
- Product owner resolved every open decision (2026-08-18): D1 KEEP
  Facebook login (S4.4 now includes the facebooksignin endpoint,
  FB plist config, and queryable schemes); D3 iOS 26 kiosk floor
  confirmed; D9 keep the ticker's scroll show/hide verbatim; D12 DROP
  the listen-elsewhere sheet entirely (watchonyoutube endpoint +
  song-signature removed again as dead code); D13 legacy parity for
  kiosk moderation; D14 legacy bundle ids confirmed. D11 mechanism
  refined: device language rides the standard Accept-Language header
  on every request, not a query parameter (SecretDJAPI refactored
  red-first; 229 tests). Live capture approved at max one API call
  per second, read-only endpoints only; a production test account
  exists with credentials in .secrets/ (gitignored — never committed).
- S3.2 done (sonnet subagent; DesignSystem 39 tests, FeedUI 76 tests):
  domain-agnostic cell library (MediaRow/PersonRow/VenueRow/Card/Tile/
  TopUpRow/EventRow/Promotion cells + RemoteArtworkView) on Theme/Icon
  tokens per lazy-sections; FeedUI maps every Item payload to
  primitive cell props (FeedCellProps, exhaustively switched, TDD'd),
  placeholder cell deleted. FeedDisplayItem carries its originating
  template (award/checkIn decode venue-shaped; the template
  disambiguates). Known gap flagged honestly: Domain never decodes
  ItemImage/artwork URIs (S1.1 omission) — artwork falls back to
  icons; scheduled next round.
- Live capture done (sonnet subagent, ≤1 req/s, read-only only): 15
  production fixtures captured through the package's OWN request
  builder and HMAC signing — production accepted our wire contract,
  the strongest S1.2 validation possible. Five LIVE-CAPTURE markers
  resolved (nowplaying, extracontent, musicsearch, musicdigest,
  numpaidcredits, plus userdetails' layout confirmed); tokens and the
  account email redacted in fixtures; remaining markers all gate on
  forbidden write endpoints, correctly untouched. Two doc-comment
  corrections (musicdigest carries a top-level Hash; numpaidcredits
  has an unmodeled NumCredits). One real server error captured as-is
  (styleinfo with item=0). API package steady at 229 tests.
- Artwork gap closed (TDD, sonnet subagent): ItemImage in Domain with
  legacy's resolution bitmask, size-class buckets, fallback ladder,
  and the image's-own-ItemType base-path rule (a song's cover can be
  album-bucketed — proven by PlayHistory.json); image fields on
  Song/Venue/Person/Artist/Jukebox/Promotion, tolerant decode; FeedUI
  resolves real artwork URLs (size2x2 row bucket). TopUp's wire image
  deliberately unwired (no cell artwork field — no dead code). Domain
  135 / FeedUI 83 / API 229 tests.
- S3.3 done (TDD, sonnet subagent; FeedUI 127 tests): FeedActionRouter
  + typed FeedActionOutcome vocabulary with an injectable InstalledApps
  seam — legacy FeedActionProvider rules ported with citations
  (item-action-overrides-payload-default gate, artist song-count
  branch, promotion social deep-link conversion when installed with
  externalBrowser routing and the URL-less engagePromotion ping,
  server-gated Uber launch, machinecontrol as skip/neverPlay). Taps
  thread through the section ForEach level so cell props stay
  closure-free per lazy-sections; the kiosk's change-mood tiles ride
  the same changeAtmosphere path for S7. The Song-tap hidden-jukebox
  correlation variant is documented as S3.4-scope (needs SectionList
  context). "Blacklist" surfaced as .neverPlay in the outcome
  vocabulary; the wire identifier stays as the protocol names it.
- S3.4 done (TDD, sonnet subagent; FeedUI 154 tests): FeedScreenModel
  over injected seams — FeedLoading protocol + actor fake, per-screen
  FeedConfiguration (legacy 20s/3s-GPS cadence via a fix-age seam),
  guarded pagination, jukeboxChangedEvent as a pure signal, state
  phases driving DesignSystem surfaces; FeedScreen with .refreshable
  and event-driven pagination. The deferred song-tap jukebox
  correlation landed via the hidden jukebox list.
- S3.5 done — stage S3 complete: deterministic 60-section stress
  fixture with previews (incl. accessibility5) and a shape/determinism
  test, then an adversarial code-review audit against lazy-sections'
  scroll rules. Six findings, all fixed red-first (sonnet subagent):
  carousel dimensions now derive from CardCell's own base constants
  (the exemplar's can-never-drift pattern); cell props computed once
  at FeedDisplayModel build, stored on FeedDisplayItem; pagination
  trigger replaced with a sentinel footer inside the LazyVStack (the
  section-granular onAppear under-fired on merged pages); section and
  item ids collision-proofed with hash folding + deterministic
  occurrence suffixes; appendPage skips overlapping page windows;
  EventRowCell's positional ForEach documented. FeedUI 163 /
  DesignSystem 39 tests; full verify green. The audit also suggested
  two articulations worth folding into the lazy-sections skill later
  (RemoteArtworkView's fixed-frame contract; explicit unreachable-case
  handling) — noted for a future skill-authoring pass.
- S4.1+S4.2 done (TDD, sonnet subagent): the consumer app's login
  feature — gate-on-launch in the composition root (SessionStore +
  APIClient constructed there, placeholder replaced; signed-in interim
  screen until S5's tabs), LoginModel/SignUpModel/
  ForgottenPasswordModel over an AuthenticationServicing seam with an
  in-memory fake, ProfileDetailsValidator ported as spec (regexes
  cited to legacy source), 41 localized keys in five languages
  (needs_review; "screen name" added to the glossary), full
  instrumentation with tests proving credentials/identifying values
  never hit diagnostics. Production smoke (R3): one-shot sign-in via
  the app's own stack succeeded on attempt 1 as nickbot — no tokens
  recorded. SecretDJTests now hosts real feature tests (83 across the
  suite); test target gained Domain/API package deps in pbxproj.
  Full verify green.
- S4.5 done (TDD, sonnet subagent): Features/Onboarding with a typed
  per-route step sequence (native → photo only, since S4.2's details
  form already collects gender; apple → gender+photo and facebook →
  photo modeled for S4.3/S4.4), avatar pipeline ported from legacy
  (square center-crop, 1024 cap, JPEG 0.9; the interactive crop UI
  deliberately not ported), PhotosPicker + seamed camera capture,
  localized camera usage description via a new consumer
  InfoPlist.xcstrings (five languages), RootView re-gated so sign-up
  flows through onboarding before the signed-in screen. The agent
  caught and fixed a real token bug: SessionStore.rotateToken now
  fires even on ReturnCode-failed responses (the server can rotate on
  failure; dropping it left the next call stale-signed) — regression
  test added. One flagged TDD deviation: OnboardingModel's spec was
  written alongside its seam types rather than strictly red-first.
  API package 232 tests; full verify green.

## 2026-08-19

- S4.3 done: Sign in with Apple. Built by a delegated team (the seams:
  AppleAuthorizing over ASAuthorizationController with double-resume
  guards and no force-unwrapped anchors; the keychain first-auth
  name/email cache in SecretDJAPI matching legacy's account key; the
  apple username step over setuserdetails) plus an escalated opus
  finisher after the sonnet orchestrator stalled twice on statements
  of intent — the finisher assembled AppleSignInModel review (the
  model landed concurrently from the team's own worker; reviewed
  line-by-line against its 23-test spec rather than duplicated), the
  official Apple button (used as chrome only so authorization flows
  through the testable seam — SwiftUI's SignInWithAppleButton would
  bypass it), the username screen, and the RootView-priority wiring
  (username → onboarding.apple → signed in; the step must outrank the
  signed-in gate because applesignin signs in immediately). 42 Apple
  tests green; 3 new localized keys (five languages, needs_review).
  R3 note: the live SIWA smoke is PENDING a real device/human — the
  auth sheet, once-only name/email delivery, and the server's
  acceptance of the day-of-year digest (timezone-fragile per
  LEGACY.md, ported as-is per D7) are unverified until then. Lesson
  for the delegation ladder: nested sub-orchestration caused the
  stalls and a mid-flight write race; direct single-agent completion
  briefs work better for assembly tasks.
- S4.6 done (TDD, sonnet subagent, direct/no-subagents): Features/
  Account — two-step sober deletion flow (explanation screen + native
  destructive confirmation) over an AccountServicing seam, sign-out
  wiping both stores on success, and a calm deletion-requested
  terminal screen replacing legacy's blocking-alert + exit(0). No
  client-side blocked flag persisted (the legacy trap's rationale
  cited in doc comments; the server owns the account's fate). Flow
  presented from RootView above the signed-in gate — a sheet would be
  torn down the instant sign-out flips the gate. Sign-out kept
  model-less per the scope rule (one call + breadcrumb). 10 localized
  keys (German uses "Leider" per the sober-context tone rule);
  requestdeleteaccount fake-tested only, never smoked. Consumer suite
  163 tests; full verify green.
- S4.4 done — stage S4 complete (sonnet subagent, direct): Facebook
  sign-in on facebook-ios-sdk 18.1.0, consumer target only. Config
  ported from the legacy plist (FacebookAppID 144876722233890, fb URL
  scheme, queryable schemes, auto-log-events and advertiser-ID
  collection both off); FacebookClientToken ships as a marked
  placeholder — the modern SDK requires it, legacy predates it, ONLY
  the Meta dashboard has it: until supplied, the button doesn't
  render and the SDK never initializes, so the app runs fully without
  it. facebookSignIn endpoint landed in SecretDJAPI (D1 marker
  replaced; the wire payload generalized to SocialSignInWirePayload;
  Facebook's distinct digest salt verified independently; API package
  244 tests). FacebookSignInModel mirrors Apple's shape behind
  FacebookAuthorizing + TrackingAuthorizing seams; a Swift 6
  data-race with the SDK's non-Sendable AccessToken was caught and
  fixed by extracting Sendable fields in the completion. The Apple
  username step generalized to SocialUsername* (renames, not copies)
  and AppleAuthenticatedSession to SocialAuthenticatedSession.
  Legacy's 1s ATT-grant delay workaround deliberately not ported
  (2022-era SDK bug, unverifiable here — flagged). ATT usage
  description localized. Flagged TDD deviation: the model/wiring
  layer was written tests-with-implementation rather than strictly
  red-first. Live FB smoke pending real Meta credentials. Full verify
  green.
- S5.1+S5.2 done (TDD, sonnet subagent, direct): the real three-tab
  consumer shell — TabView with per-tab NavigationStacks over
  @Observable TabRouters, a typed AppDestination vocabulary mapped
  failably from FeedActionOutcome (side-effect outcomes deliberately
  return nil — S6's job), TabsModel with the legacy cross-tab
  show(tab:) affordance, tab roots screen-tracked and switches
  breadcrumbed; Profile tab absorbed sign-out/delete-account entry.
  Eleven localized keys; ComingSoon destination screens keep
  navigation exercisable until S6 lands real screens.
- S5.3 done — stage S5 complete (TDD, sonnet subagent, direct):
  LocationService (@Observable, implementing FeedUI's
  GPSFixAgeProviding with a first-fix-only timestamp) over a
  CoreLocation-free LocationProviding seam; a Mutex-backed
  nonisolated LocationCoordinateBox bridges MainActor state to
  SecretDJAPI's synchronous implicit-parameter read (explicit
  nonisolated needed under default MainActor isolation — caught by
  verify); permission-denied surface wired into Places Nearby with
  foreground re-check; localized when-in-use usage description.
  Coordinates never reach diagnostics. The agent mutation-tested its
  guards (six deliberate reverts, six matching failures) and caught
  its own vacuous ARC-deallocated instrumentation test. Full verify
  green.
- S6.1 done (TDD, sonnet subagent, direct): Places Nearby for real —
  APIClientFeedLoading, the reusable app-side FeedLoading adapter
  (fresh one-shot location before every load, session credentials
  read fresh per fetch so auto-refresh outlives token rotation,
  rotated tokens applied, typed error if a call outlives sign-out);
  PlacesNearbyScreen at the legacy cadence with no pagination
  (matching the legacy provider), venue-map screen deriving
  annotations from the already-loaded feed (jukebox venues distinct
  and accessible, camera fit, pin taps reuse showVenue), shell-level
  ToastQueue composed for jukebox-changed. Twelve localized keys.
- S6.5 done (TDD, sonnet subagent, direct): Activity feed as the
  smallest adapter reuse — eventhistory, auto-refresh, no pagination
  (legacy inheritance no-op, cited), fixture test from the live
  EventHistory capture proving cell/route selection for event, award,
  check-in, and person items. Three localized keys. Both tasks full
  verify green. (Process slip recorded: these two commits went out
  without their PLAN.md checkbox flips — statuses ride in this
  follow-up commit instead. The checkpoints rule stands.)
- S6.2 done (TDD, sonnet subagent, direct; 306 tests across the
  suite): VenueScreen + NowPlayingScreen over sessionFeed with
  auto-refresh; the reusable OptimisticLikeModel in Support/Like
  (synchronous flip, re-entry guard proven by reentrancy tests,
  rollback + failure toast, server likeInfo adopted verbatim per D11,
  reconcile(with:) so auto-refresh can't stomp an in-flight toggle);
  the legacy social-links rule ported as a FeedLoading decorator
  (Instagram first, cap three, cited to VenueFeedViewController) so
  generic rendering needed no venue-specific views; AppDestination
  gained nowPlaying. Self-review caught and fixed: an all-invalid-URL
  section escaping the cap, a sub-44pt like target, untested
  promotion-engagement view logic (extracted to a seamed model), and
  stale like state across refreshes. Eleven localized keys.
- S6.3 first half done (TDD, sonnet subagent, direct): SharedFeatures
  gains MusicSelection (screen over injected FeedLoading; MoodTileModel
  over an AtmosphereChanging seam with server-copy toast; consumer
  injects surfaceChange, kiosk will inject reloadInPlace) and
  MusicSearch (SearchModel: artist mode fetches once then filters and
  A-Z groups locally, track mode debounces via an injected clock with
  stale-response suppression) — both zero-copy per the FeedScreenCopy
  pattern, backend access only through seams (package never sees
  SecretDJAPI). DesignSystem gains SectionIndexStrip (one combined
  adjustable accessibility element, tested geometry). FeedUI gains an
  event-driven scrollRequest binding. Consumer wires real screens
  behind .jukebox/.search/.songsForArtist (destinations now carry
  venueId, resolved by the calling screen). Ten localized keys.
  Deferred within S6.3: the legacy mood-duration picker — tiles use a
  documented 30-minute default; noted on the S6.3 checkbox. Full
  verify green (DesignSystem 51, SharedFeatures 26, FeedUI 167).
- S6.3 complete (second half; TDD, sonnet subagent, direct): TuneIn in
  SharedFeatures — TuneInScreenModel derives request/skip/never-play
  visibility from the song's own server-granted actions (moderation
  hides the request button per legacy business rule 7), drives
  SongRequesting/MachineControlling seams with double-tap guards, and
  embeds the OptimisticLikeModel, now relocated into SharedFeatures
  (consumer keeps the APIClient adapter; LikeFailureEvent.message went
  optional so package views never invent copy). The consumer funnel is
  wired per business rule 5: no-picture → plain-copy confirm →
  pic-for-credits sheet reusing extracted avatar components
  (AvatarPickerButtons/CameraCapture) with the server reward toast and
  a re-offer; has-picture → .topUps(noCredits) (ComingSoon until
  S6.7). TuneInTarget.song widened to carry the full Song (no by-id
  endpoint exists); .song destinations carry venueId. Twelve localized
  keys, money-adjacent copy plain. Suite: consumer 321, SharedFeatures
  76, FeedUI 167, Domain 135, API 240, DesignSystem 51 — full verify
  green.
- S6.4 done (TDD, sonnet subagent, direct): the shared preview player
  in SharedFeatures/Playback — download-then-decode per the .pbz
  contract (AVAudioPlayer(data:) behind AudioPlaying/PreviewDownloading
  seams), single active preview app-wide with a generation counter
  killing stale downloads, 30s cap on an injected clock,
  cancel-during-download, stop-on-exit scoped to the owning screen's
  song. isPlaying spans download+playback (matching legacy's
  notification timing) and is the documented S7.3 attract-suppression
  signal. Song.previewURL was already modeled — no Domain change.
  TuneIn gains the play/stop button (hidden without a preview URI);
  AVAudioSession .playback configured at the root with legacy's
  IOBufferDuration cargo-cult deliberately dropped. Four localized
  keys. Full verify green.
- S6.6 done (TDD, sonnet subagent, direct): ProfileScreen serves both
  the own-profile tab root and others' profiles via .person (personId
  parameterized, own-ness read live against the session per legacy);
  header with circular avatar, fixed "My Profile" vs verbatim screen
  name, person like on others' profiles only (legacy hides it on your
  own — cited); avatar change reuses the OnboardingServicing upload
  seam and the extracted picker components (third reuse), success
  refreshes the feed and toasts any reward copy; no auto-refresh
  (matched to the legacy provider). FeedUI gains
  FeedScreenModel.personDetails off the hiddenProfile section.
  Single "Profile" tracking name matching legacy's undistinguished
  analytics. Six localized keys. Full verify green.
- S6.7 done (TDD, sonnet subagent, direct; suite now 1372 tests):
  top-ups on StoreKit 2 behind a ProductPurchasing seam (scriptable
  fake with a simulated transaction stream; the real actor adapter
  verified against the actual iOS 27 SDK and compiled by verify but
  never unit-touched). The finish/no-finish rule lives in one shared
  TopUpNotifySubmitter: credited/alreadyProcessed finish, retryable
  and transport errors stay unfinished — StoreKit 2's durable
  unfinished-transaction queue replaces legacy's finish-before-verify
  ordering and PendingTopUps resubmit-on-every-screen machinery. The
  launch-time listener drains unfinished transactions once; Restore =
  AppStore.sync + purchaseRestored notifies, with numpaidcredits
  driving the nothing-to-restore message per legacy. "No payment was
  taken." used only where truthful (pre-charge failures), per-language
  fixed renderings from the adaptation sheets; post-charge notify
  failures show the server's message instead. Voucher bar + insertCoin
  vs noCredits header contexts wired; .topUps destination is real.
  Sixteen localized keys with glossary-consistent terms. Full verify
  green.
- S6.8 + S6.10 done (TDD, sonnet subagent; resumed once after a
  wait-stall; suite 413 consumer tests): check-in as a one-directional
  optimistic model (legacy never un-checks; reconcile never regresses
  true on stale refreshes), server URL replacing the toast per
  legacy's ToastHandler rule; directions as an Apple Maps walking
  hand-off — the 2017 custom map/call/SMS screen deliberately not
  ported (cited in code and on the S6.10 checkbox). Real finds: the
  hailRide outcome was a silent no-op (now opens externally from every
  outcome-forwarding screen) and VenueScreen was never passed
  observability (its instrumentation would have been dead in
  production). New gap scheduled as S6.12: SectionList.actions'
  toolbar buttons are mapped and tested but never rendered. Four
  localized keys + two glossary rows. Full verify green. (The Stop
  hook's mid-flight verify collision with the agent's own run produced
  one spurious terminated-verify report — both subsequent full runs
  were green.)
- S6.9 done (TDD, sonnet subagent, direct): the extra-content ticker —
  ExtraContentModel over loading + clock seams (10s rotation, paused
  while hidden, forced visible on first fetch per legacy's bounce-in),
  TickerView on BannerSurface deliberately not keyed by entry id so
  rotations update in place without stealing VoiceOver focus; scroll
  direction per D9 verbatim via a new pure FeedScrollDirection +
  FeedView.onScrollGeometryChange reading only contentOffset.y and
  emitting only on direction flips (justified against lazy-sections'
  scrollPosition warning; nil-gated to zero cost elsewhere); legacy's
  pan-translation semantics mapped and documented. Tap routing: song →
  venue's Now Playing when a venue context exists (nil on Places per
  legacy's failed cast), person → activity tab. Red proven by stubbing
  behavior to no-ops (16/24 failed as expected). One localized key.
  Full verify green.
- S6.11 done (TDD, sonnet subagent, direct): Settings behind a gear on
  the own profile (sign-out/delete-account relocated; footer + markers
  removed) — change details (prefill/validate/save per the legacy
  SwiftUI pilot, cited), change password (current password checked
  LOCALLY against the stored SHA-1, never sent — legacy contract),
  change gender (submit-on-tap per the legacy flow, reusing an
  extracted GenderPicker), auto-lock as an in-app toggle on the legacy
  DisableAutoLock key applied immediately and re-applied on scene
  activation (cited), about/legal rows with S9.2-placeholder URLs in
  an SFSafariViewController wrapper. New SettingsServicing seam only
  for the permutations nothing else modeled; gender reuses
  OnboardingServicing. SessionStore gains updatePasswordHash/
  updateScreenName (TDD). Deliberate divergence recorded: outcomes
  toast rather than the pilot's silent pop. Twenty-six localized keys.
  Full verify green.
- S6.12 done — stage S6 complete, the consumer app is functionally
  complete (TDD, sonnet subagent; resumed once after a wait-stall):
  server-driven toolbar buttons now render — FeedDisplayModel exposes
  SectionList.actions filtered by legacy's double guard (renderable
  button + recognized kind, mirrored from ActionBarButtonItem.init?),
  FeedScreenModel republishes them on full loads only and exposes
  outcome(forBarButton:); a ToolbarContent component maps
  insertCoin/hailTaxi/launchSearch to Theme icons with localized
  accessible labels and routes taps through each screen's existing
  outcome handler, so hail-taxi breadcrumbs and side effects apply
  unchanged. Wired on PlacesNearby/Venue/NowPlaying/Activity per
  legacy's ActionBarButtonProvider usage. One new localized key.
  Full verify green.
- S7.1 done (TDD, sonnet subagent, direct; suite 530 tests): the kiosk
  shell — composition root with a kiosk implicit-parameter provider
  (appmodel=1 via APIClientConfiguration.isKiosk; location a
  documented nil seam until a kiosk location feature exists), its own
  keychain service per D5, console-only observability (vendor adapters
  a documented follow-up), and the signed-in gate to a placeholder
  kiosk home showing the venue. Venue sign-in over a thin kiosk-local
  KioskSignInServicing (consumer's seam is target-internal and mostly
  kiosk-irrelevant — justified); a response without Venues.Force is
  rejected as not-a-venue-account per legacy; the forced venue is
  stored (id stands in for the name until S7.4 resolves it). Staff
  reset replaces ?RESTART?: five taps top-left in a 3s window
  (injected clock, tested) → confirmation → sign-out + registered
  cache clears (URLCache now; a documented seam for S7.2's skin
  assets) → back to sign-in, no exit(0). Twelve localized kiosk keys.
  Full verify green.
- S7.2 done (TDD, sonnet subagent, direct; 566 app tests): the skin
  system — SkinModel over loading/asset-download/store seams (bounded
  4-way concurrent asset fetch with observable progress; cache-hit
  relaunches skip the network; any failure blocks kiosk entry behind a
  retry-only surface per legacy; the skin store registers with the
  staff reset). KioskBehavioralConfig derives attractURL + 10s
  attract/idle defaults cited to legacy's KioskAppConfig — S7.3's
  contract. Chrome per D10: KioskSkin resolves manifest colors with a
  runtime WCAG 4.5:1 check on the toast pairing — a failing or
  unparsable server color drops BOTH colors of the pair back to
  Theme's sanctioned tokens together, and ResolvedSkinColor carries
  provenance so tests assert the fallback. New #AARRGGBB parser
  alongside DesignSystem's 6-digit one. Five localized kiosk keys.
  Full verify green.

## 2026-08-20

- S7.3 done (TDD, sonnet subagent; resumed once after a wait-stall):
  the attract/idle system — IdleTimerModel with legacy's exact
  semantics cited to KioskTimer/KioskApplication (one-shot countdowns
  always restarted at FULL duration; preview playback cancels both
  outright — true suspension; idle no-ops while attract shows; no
  attractURL means no attract, idle still runs); interaction observed
  via a root simultaneousGesture that never consumes touches,
  replacing the UIApplication sendEvent subclass; AttractScreen is one
  VoiceOver-labelled Button wrapping a non-interactive WKWebView at
  the skin's URL with a visible Tap to Continue pill (legacy's
  invisible dismiss had no VoiceOver at all); the kiosk root now
  constructs the shared PreviewPlayerModel (one app-wide instance per
  its contract) and sets isIdleTimerDisabled while signed in
  (guided-access assumption doc-flagged against R1). One localized
  key. Watch item: IdleTimerModelTests' attract-breadcrumb test failed
  ONCE with zero diagnostics and passed both full reruns — if it
  recurs in S7.7/S8 runs, investigate rather than retry.
- S7.4 + S7.5 done (TDD, sonnet subagent; resumed once): the kiosk
  home replaces the placeholder — a fixed now-playing header
  (KioskNowPlayingModel polling playhistory at the legacy 20s;
  intermission renders the \n\n-split two-line message with artwork
  suppressed via a pure TDD'd KioskNowPlayingDisplay; venue name
  resolved into the session) above SharedFeatures'
  MusicSelectionScreen reused wholesale with reloadInPlace injected
  (hash changes absorbed, never a toast). Song taps port legacy's
  kiosk write path exactly (cited): KioskTuneInScreen wraps the shared
  TuneIn — unmetered requesting for venue accounts, no out-of-credits
  funnel (unreachable), moderation stays server-action-gated per D13.
  Kiosk-local thin adapters over the shared protocols (the GPS-fix
  rule deliberately dropped as a phone-only workaround). Sixteen
  localized kiosk keys reusing consumer translations verbatim where
  identical. ALSO: the S7.3 watch-item flake is solved — the test
  discarded its model (weak-self clock closures deallocated before
  firing); both discard sites fixed, root-caused via xcresulttool.
  Full verify green.
- S7.6 + S7.7 done — stage S7 complete (TDD, sonnet subagents): kiosk
  search reuses MusicSearchScreen/SongsForArtistScreen wholesale
  (kiosk adapter + copy; header-mounted search button per legacy;
  iPad grids already proven by the digest; system keyboard confirmed
  per D10; A–Z strip accessibility confirmed by reuse). Resilience:
  FeedConfiguration gains an opt-in ErrorRecovery backoff (5s
  doubling to a 300s cap, never gives up — unattended iPads have no
  staff to retry; coarse breadcrumbs on attempt 1 and every 5th),
  armed on the kiosk's resting screens; memory-stability proof tests
  (50-cycle refresh/poll, state replaced not accumulated — no bugs
  found); composition tests prove attract and recovery run on
  independent clocks (attract can't be blocked by error states,
  dismissing attract lands on a healed screen). The flagged
  idle-return gap closed: AttractIdleContainerView publishes its
  IdleTimerModel via the environment (kioskSkin pattern) and
  KioskHomeView pops its NavigationStack to root on idle firing,
  citing legacy's didExceedIdleTimeout; search deliberately carries no
  recovery of its own since idle-abandonment now returns home where
  recovery lives (documented). FeedUI gained an Observability
  dependency for the recovery breadcrumbs. Eleven localized kiosk
  keys. Full verify green. On-hardware soak explicitly deferred to
  S8.4/S9.3.
- S8.2 automated half done (sonnet subagent; the biggest single-agent
  run yet): UI-test mode in both composition roots (UITEST_MODE /
  UITEST_SIGNED_IN launch env; fixture transport answering every feed
  endpoint with one deterministic SectionList; pre-seeded kiosk skin
  store; observability disabled; animations off — audits were
  sampling mid-fade), two XCUITest targets via pbxproj surgery, and a
  new verify.sh uitest action (default test untouched so the Stop
  hook stays fast). Eighteen audit tests green across 13 screens incl.
  AX5 Dynamic Type runs. Real fixes at the source: fixed-height
  frames around single-line text in three cells became minHeight (the
  skill's no-fixed-height rule — a genuine clipping risk),
  FeedSectionHeader's lineLimit removed, ForgottenPassword's close
  button moved onto the theme accent for contrast. Deferred with
  markers + a documented allow-list (new issues still fail): UIKit
  text-field "text clipped" (3 fields, component-generic), a
  Dynamic-Type partial-support report (element-diverse), and two
  element-scoped contrast items needing Accessibility Inspector on
  hardware. The manual VoiceOver walk of all 13 screens is listed in
  PLAN.md as the remaining human half.
- S8.1 done (sonnet subagent): 239 keys / 956 translation entries
  audited across three catalogs — one gap fixed (the numeric-only
  %lld key), zero conformance violations (payment phrases verbatim,
  no formal address anywhere, placeholders/newlines preserved; the
  one Title Case flag was a Dutch proper-noun false positive). German
  longest-language layout tests added to both UI-test targets (23/23
  uitest green). A pre-existing flaky race in OptimisticLikeModelTests
  fixed with deterministic waiting (confirmed pre-existing via stash).
  MAJOR FINDING — D11: the backend does not localize yet. Live
  capture (≤1 req/s, read-only) requested placesnearby under all five
  Accept-Language values; every copy field returned byte-identical
  English (two request shapes confirmed; the client's header is
  correct). Recorded on D11 in PLAN.md as the gating item before S9.
- Native-speaker review scheduled for the S8.1 needs_review queue:
  936 entries across es/fr/de/nl (234 per language) spanning all
  three catalogs. Priority pass first on the ~35 high-risk entries
  (account deletion, payment/top-up, permission prompts, password
  flows) before the remaining general-UI copy. No entries were
  flipped to translated by the audit — that stays a native speaker's
  call per the localization skill.
- S8.5 done (read-only cross-check + fix agents): the full LEGACY.md
  walk found the rewrite faithful on all 12 spot-checked business
  rules (funnel, intermission, hash policies, like rollback, check-in
  URL-over-toast, machinecontrol gating, skin fallbacks, attract
  semantics, appmodel, User-Agent — whose "px" label in LEGACY.md is
  itself the minor error, legacy sends points — signing, kiosk
  unmetered requests). Three findings dispositioned: (1) FIXED —
  .openURL/.openSocialApp/.engagePromotion outcomes were silently
  dropped outside VenueScreen; a uniform four-helper chain
  (hailRide/openURL/socialApp/engagePromotion) now runs on all five
  feed screens AND TabsView's routed-screen path, with the in-app
  browser sheet housed per screen, promotion pings venue-gated per
  legacy (venueId optional; no-venue surfaces breadcrumb only), all
  TDD'd red-first; (2) rich toasts scheduled as S8.6 for a product
  call; (3) the mood-duration picker became decision D15 (default:
  keep the fixed 30-minute override). Also fixed the remaining
  blind-yield flake class in SharedFeatures (MoodTile/TuneIn suites,
  same deterministic-wait treatment as S8.1's like fix; 3x stable).
  The kiosk backoff timings (no legacy precedent) await a product/ops
  sanity nod. Full verify green.
