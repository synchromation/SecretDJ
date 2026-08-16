# Legacy Secret DJ — codebase analysis

An analysis of the legacy Secret DJ iOS codebase at `~/ws/secret-dj-ios-old`
(git remote `synchromation/secret-dj-ios`), captured 2026-08-16 from the
`refactor` branch (tip `4fef6ac9`), as the reference for the greenfield
SwiftUI rewrite based on this repository's conventions.

One Xcode project, two apps for a pub jukebox service:

- **Secret DJ** (iPhone) — the consumer app: customers of pubs with the
  Secret DJ service pick songs to play on the venue's jukebox.
- **Secret DJ Kiosk** (iPad) — the venue app: pub employees control the
  music, running all day on an iPad at the bar.

Produced by a multi-agent audit (eleven analysts, one per dimension, plus a
completeness critic that cross-checked their combined coverage); every claim
cites the file it came from. Open questions the code could not answer are
collected at the end.

## Contents

- [Project and build configuration](#project-and-build-configuration)
- [Consumer app: features and flows](#consumer-app-features-and-flows)
- [Kiosk app: the venue iPad](#kiosk-app-the-venue-ipad)
- [Backend API and Spotify integration](#backend-api-and-spotify-integration)
- [Domain model and persistence](#domain-model-and-persistence)
- [Audio and playback](#audio-and-playback)
- [Monetization, identity, analytics, and compliance](#monetization-identity-analytics-and-compliance)
- [UI layer, assets, localization, and accessibility](#ui-layer-assets-localization-and-accessibility)
- [Architecture and tech debt](#architecture-and-tech-debt)
- [Tests, tooling, and quality gates](#tests-tooling-and-quality-gates)
- [Refactor branch: the in-flight modernization](#refactor-branch-the-in-flight-modernization)
- [Gaps and cross-checks](#gaps-and-cross-checks)
- [Open questions](#open-questions)

## Project and build configuration

### Overview

Everything lives in a single Xcode project, `secretdj.xcodeproj` (organization "Hornsey Research Ltd", `project.pbxproj` line ~2881). The `secretdj.xcworkspace` beside it is a thin one-entry wrapper around the project (`secretdj.xcworkspace/contents.xcworkspacedata`) — almost certainly a CocoaPods-era leftover (the `.gitignore` still references `Pods/resources-to-copy-Secret DJ.txt`); dependencies are now pure SPM. Three build configurations exist on every target: **Debug**, **Release**, and **Ad Hoc**.

Both apps compile the *same module* (`PRODUCT_MODULE_NAME = SecretDJ` on both, `productName = secretdjv3` on both targets) from one big shared source folder `secretdjv3/`, differentiated by target membership and compilation conditions — there is no framework/module boundary between consumer and kiosk code.

### The four targets

| Target | Product | Bundle ID | Type | Deployment | Device family | Entry point |
|---|---|---|---|---|---|---|
| **SecretDJ** | `Secret DJ.app` | `com.c-burn.secretdj` | iOS app | **iOS 17.0** | 1 (iPhone-only) | `@UIApplicationMain` on `secretdjv3/AppDelegate.swift` + `secretdjv3/SceneDelegate.swift` |
| **SecretDJKiosk** | `Secret DJ Kiosk.app` | `com.secretdj.kiosk` (Debug/Release); **`com.c-burn.kiosk` in the Ad Hoc config** | iOS app | **iOS 15.6** | 2 (iPad-only) | manual `UIApplicationMain` in `secretdjv3/main.swift` bootstrapping `KioskApplication` (a `UIApplication` subclass that broadcasts a "user touched screen" notification from `sendEvent` — the attract-mode/idle-reset mechanism, `secretdjv3/KioskApplication.swift`) + `KioskAppDelegate`/`KioskSceneDelegate` |
| **SecretDJTests** | `SecretDJTests.xctest` | `com.c-burn.SecretDJTests` | unit-test bundle hosted in `Secret DJ.app` (`TEST_HOST`, pbxproj line 4723) | iOS 17.0 | 1,2 | 42 test files (see below) |
| **SecretDJKioskTests** | `SecretDJKioskTests.xctest` | `com.killfor.SecretDJTests`-style id: `com.killfor.SecretDJKioskTests` | unit-test bundle hosted in `Secret DJ Kiosk.app` | iOS 13.0 (below its own host app's 15.6) | 1,2 | **one placeholder file** (`SecretDJKioskTests/SecretDJKioskTests.swift`) |

The project-level default deployment target is still iOS 12.0 (pbxproj lines 3850/4327/4382); each target overrides it. The consumer app was recently raised to iOS 17 on this `refactor` branch (commit 89b96f7f "Phase 0: iOS 17 floor").

Signing is messy: consumer and kiosk Debug/Release use `DEVELOPMENT_TEAM = L7S67T9D8T`, the kiosk **Ad Hoc** config uses a different team `64422L3U8R` (with the different `com.c-burn.kiosk` bundle id, pbxproj lines 4183/4263), and SecretDJKioskTests uses a third team `45JT2WA84K` (line 2899). `MARKETING_VERSION = 5.1.4` across all app configs.

### Info.plists — and why the duplicates exist

Four Info.plists sit at the repo root; only two are referenced by the project:

- **`SecretDJ-Info.plist`** — live consumer plist (`INFOPLIST_FILE`, pbxproj lines 3884/4417/4520). `CFBundleVersion` 5287.
- **`SecretDJKiosk-Info.plist`** — live kiosk plist (lines 3989/4094/4198). `CFBundleVersion` 10226. Still carries a dead **Fabric/Crashlytics API-key block** from the pre-Firebase era.
- **`SecretDJ copy-Info.plist`** and **`SecretDJKiosk copy-Info.plist`** — referenced by **nothing** in `project.pbxproj` (grep finds zero references). Git shows both were created in commit `7fbb7b85` ("New mac commit prior to upgrade to swift : 1") as literal copies of the live plists (git status `C092`) — i.e. Finder/Xcode backups taken during a machine migration before a Swift upgrade, frozen at marketing versions 4.1.1 (consumer, with a curious `LegacyApp=true` key) and 5.0.2 (kiosk). Safe to drop.
- A **third** stale consumer plist exists at `secretdjv3/SecretDJ-Info.plist` (version 4.1.0.0), also unreferenced — the live file reference explicitly uses `sourceTree = SOURCE_ROOT` (pbxproj line 779).

The enormous build numbers are explained by a **"Build number updater" shell build phase on both app targets** that increments `CFBundleVersion` inside the *source-controlled* Info.plist on every build (pbxproj lines 3156–3183) — meaning every build dirties the working tree. Don't carry this forward.

#### Declared iOS-facing behavior (from the live plists)

- **URL schemes** — consumer registers `secretdj` and `fb144876722233890` under URL name `com.c-burn.secretdj` (`SecretDJ-Info.plist`); kiosk registers only the Facebook scheme. The rewrite must keep `secretdj://` for any deep links.
- **Queryable schemes (`LSApplicationQueriesSchemes`)** — consumer: `instagram`, a long list of `fbapi*`/`fbauth*` variants, `twitter`, `spotify`, `uber`, `tel`; kiosk: Facebook schemes only.
- **Background modes** — none anywhere (no `UIBackgroundModes` in any plist or source).
- **Usage descriptions** — consumer: camera ("To take a photo that you can use as your profile picture."), photo library, location-when-in-use ("We use your location to find your nearest Secret DJ venue."), and `NSUserTrackingUsageDescription` (a candid one about Facebook sign-in). Kiosk: location-when-in-use only.
- **ATS is fully disabled in both apps** (`NSAllowsArbitraryLoads = true`; kiosk adds legacy exception domains for facebook.com/fbcdn.net/akamaihd.net). Tech debt — the rewrite should not replicate this.
- **Facebook config** — `FacebookAppID 144876722233890`, with `FacebookAutoLogAppEventsEnabled=false` and (consumer) `FacebookAdvertiserIDCollectionEnabled=false`.
- **Orientation/UI** — consumer: portrait-only iPhone; kiosk: landscape-only iPad with status bar hidden. Oddity: the kiosk plist still names `UIMainStoryboardFile = Login_iPhone` even though it's iPad-only and scene-based.
- Kiosk-only `InfoPlist.strings` resource exists but is empty boilerplate (`secretdjv3/en.lproj/InfoPlist.strings` region — file found via kiosk resources phase).

### Capabilities & entitlements

One shared file, **`Secret DJ.entitlements`**, is used by *all* configs of *both* apps (`CODE_SIGN_ENTITLEMENTS`, e.g. pbxproj lines 3868/3970): **Sign in with Apple** (`com.apple.developer.applesignin: Default`) plus **keychain access groups** `$(AppIdentifierPrefix)com.c-burn.secretdj` and a wildcard `$(AppIdentifierPrefix)*`. Note the kiosk inherits the *consumer's* keychain group name despite its different bundle id — inferred to be how kiosk and consumer could share credentials, but flagging as an oddity to re-decide in the rewrite.

### SPM dependencies

Two package references (pbxproj lines 4843–4858): **facebook-ios-sdk** (from 9.0.0, resolved **9.3.0** — very old, current SDK is v17+) and **firebase-ios-sdk** (from 11.15.0, resolved **11.15.0**), pinned in `secretdj.xcworkspace/xcshareddata/swiftpm/Package.resolved`. **Both app targets link the identical five products**: `FacebookCore`, `FacebookLogin`, `FacebookShare`, `FirebaseAnalytics`, `FirebaseCrashlytics` (target `packageProductDependencies`, pbxproj lines 2793–2799 and 2822–2827). Test bundles link nothing.

Each app bundles its own `GoogleService-Info.plist` from `secretdjv3/Firebase/phone/` (consumer) and `secretdjv3/Firebase/kiosk/` (kiosk) — two iOS apps registered in one Firebase project `secret-dj-b1082` (verified in both plists; resources phases at pbxproj lines 2996/3034).

Legacy linker flags survive on both app targets: `-ObjC -all_load -lc++ -lstdc++ -lxml2` plus ~20 explicitly named `-framework` flags (pbxproj lines 3892 ff.) — static-library-era ballast, none of it needed in a modern SPM build.

### Build phases & dSYM upload

Both app targets: Sources → Frameworks → Resources → **Build number updater** (see above) → **Crashlytics symbol upload "[MUST BE LAST]"** (pbxproj lines 3184–3222). The upload phases are install-only (`runOnlyForDeploymentPostprocessing = 1`) and their scripts are **mangled/broken**: `"$<BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"` is not valid shell (a corrupted `${BUILD_DIR%...}` expansion), and the input path contains typos (`$(SCROOT)`, `$(BUILT_ PRODUCTS_DIR)`). This is presumably why two **manual repo-root scripts** exist — `upload-phone-dsyms-to-firebase-crashlytics` and `upload-kiosk-dsyms-to-firebase-crashlytics` — which locate `upload-symbols` inside DerivedData's SPM checkouts and upload an `.xcarchive`'s dSYMs against the matching per-app GoogleService-Info.plist. Symbol upload is effectively a manual post-archive chore in this codebase.

No SwiftLint/SwiftFormat build phases exist in the project (zero pbxproj references) and there are no `.xcconfig` files — the root config files are editor/CLI conventions only, not build-enforced.

### Compilation conditions & feature flags

The kiosk target is carved out of the shared module at compile time:

- **Swift:** `OTHER_SWIFT_FLAGS = "-DSECRET_DJ_KIOSK"` on all kiosk configs (pbxproj lines 4053/4158/4262). Only three Swift files actually branch on it (`secretdjv3/ProfileFeedViewController.swift`, `secretdjv3/ToastManager.swift`, `secretdjv3/FeedActionProvider.swift`) — most divergence is handled by target membership instead.
- **ObjC:** `GCC_PREPROCESSOR_DEFINITIONS = KIOSK=1 LEGACY=1` on kiosk configs (lines 3983–3987); `KIOSK` switches text-color macros in `secretdjv3/CommonConstants.h`. `LEGACY` appears unused in current sources (grep found no `#ifdef LEGACY`).
- Both apps still use an **ObjC prefix header** `secretdjv3/secretdj-Prefix.pch` (device-detection macros, `SDJLog`, imports `SecretDJ-Swift.h`) and a **bridging header** `secretdjv3/SecretDJ-Bridging-Header.h` exposing the two remaining ObjC files (`UIImage+ImageEffects`, `BDKCollectionIndexView`) plus CommonCrypto.
- **Runtime feature flags** (refactor-branch work): `secretdjv3/SwiftUI/Core/FeatureFlags.swift` defines per-screen SwiftUI kill switches (`settings`, `changeMood`, `musicSearch`, all default-on) with a `UserDefaults` override key `swiftui.<screen>` that beats the compiled default.
- `SWIFT_VERSION = 5.0` on every target; no Swift 6 or strict-concurrency settings anywhere. Project-level configs enable `LOCALIZATION_PREFERS_STRING_CATALOGS = YES` and `SWIFT_EMIT_LOC_STRINGS = YES` (lines 3852/4329), but `knownRegions` is only English/en/Base (line 2916) — effectively single-language today.

### Target membership split

Computed from the two Sources build phases (pbxproj `01D15ED6…` = SecretDJ, `01A27388…` = SecretDJKiosk):

- **Shared between both apps: 213 files** — essentially the entire domain/network/UI layer: all `*APIAccess`, models (`Song`, `Venue`, `Person`, `News`…), `UserManager`, feed view controllers, login, search, etc., plus the two ObjC files. The two apps are the same codebase wearing different chrome.
- **Consumer-only: just 4 compiled files** — `secretdjv3/AppDelegate.swift`, `secretdjv3/SceneDelegate.swift`, `secretdjv3/UIStackView+BgCol.swift`, and (notably) `SecretDJTests/FixtureAccess.swift`, a JSON-fixture loader from the *test folder* compiled into the production consumer app — **plus** the entire **`secretdjv3/SwiftUI/` folder (24 files)**, attached to the SecretDJ target only as a modern `PBXFileSystemSynchronizedRootGroup` (pbxproj lines 1209–1211, 2818–2820): the refactor branch's SwiftUI bridge, feed engine, search, settings screens, and theme. The kiosk gets none of the SwiftUI work.
- **Kiosk-only: 35 files**, all following a `Kiosk*` naming convention (plus `main.swift`, `StandardKeyButton.swift`, `WideKeyButton.swift`, `SearchClearButton.swift`): `KioskAppDelegate/KioskSceneDelegate/KioskApplication`, `AttractViewController` (screensaver/attract mode), `KioskLoginFlowController`, `KioskNowPlayingViewController`, `KioskMusicSelectionFeedViewController`, the `KioskSearch*` stack including a custom on-screen `KioskSearchKeyboardViewController`, and `KioskTimer`.
- **Resources**: 67 shared (storyboards/xibs/assets), consumer-only 4 (`LaunchScreen.storyboard`, `Directions.storyboard`, `Music.storyboard`, `VerifyTopUpViewController.xib`), kiosk-only 9 (`Kiosk.storyboard`, `Kiosk_iPad.storyboard`, `KioskLogin.storyboard`, `KioskMusic.storyboard`, `Kiosk.xcassets`, kiosk cell xibs, `InfoPlist.strings`). Overall the app folder holds 26 storyboards / 41 xibs / 274 Swift files.
- **Tests**: SecretDJTests compiles 42 files — real coverage of the API-access layer (one `*APIAccessTests` per endpoint group), models, `UserManager`, HMAC/signature providers, keychain, plus new refactor-branch tests (`FeedViewStateBuilderTests`, `MoodFeedDataProviderTests`). **SecretDJKioskTests contains a single placeholder file** — the kiosk has no real test coverage.

### Started-but-empty OpenAPI module, and other strays

- **`Modules/`** is a git-untracked (never committed) SPM package skeleton: `Modules/Sources/Core/` contains nothing but `.DS_Store`, there is **no `Package.swift`**, yet `Modules/.build/checkouts/` holds resolved checkouts of `swift-openapi-generator`, `swift-openapi-runtime`, `swift-openapi-urlsession`, `OpenAPIKit`, `Yams`, `swift-argument-parser`, etc. (all dated May 14). Clear evidence someone started an OpenAPI-generated API client module ("Core") and abandoned it before writing any code. Nothing in the app references it.
- **`Heroku_SpotifyTokenSwap/`** is an **orphaned git submodule**: mode-160000 gitlink with no `.gitmodules` file, so it can't even be initialized — a dangling pointer to a Spotify token-swap backend repo.
- **`IAPManager.swift-old.swift`** sits tracked at the repo root — dead in-app-purchase code kept as a loose file.
- `Photoshop/` and `Paintcode/` folders hold design sources only (per brief; not build inputs).
- `secretdj.xcodeproj/xcshareddata/xcodecloud/manifest.json` shows **Xcode Cloud was configured, for the consumer "Secret DJ" target only**. Shared schemes exist for both apps (`SecretDJ.xcscheme`, `SecretDJKiosk.xcscheme`), each wiring its test bundle into the Test action (Debug config).

### Formatting / lint conventions (developer tooling, not build-enforced)

- **`.swiftformat`** — the style authority: `--swiftversion 5.10`, deny-all then ~90 explicitly enabled rules; **tabs, width 4**, max line 120, K&R braces, `before-first` argument wrapping, `--self init-only`, testable-last import grouping.
- **`.swiftlint`** (note: named `.swiftlint`, not `.swiftlint.yml` — SwiftLint won't auto-discover it unless invoked with `--config`) — escalates many rules to error (`force_unwrapping`, `force_cast`, `force_try`, `private_outlet`, `private_action`, `overridden_super_call`…), disables `line_length`/`identifier_name`/`todo`, caps type bodies at 300/400 and files at 400/600 lines.
- **`.swift-format`** — Apple swift-format mirror of the same style (tabs, 120 cols) for Xcode's built-in formatter, including `NeverForceUnwrap`/`NeverUseForceTry` rules.
- **`.editorconfig`** — LF, UTF-8, tabs (width 4), trailing-whitespace trim, final newline.

### Config-level tech debt NOT to carry forward

1. Build-phase auto-increment of `CFBundleVersion` into tracked plists (constant repo churn; the "copy" plists still say "Build version set by build phase").
2. Broken Crashlytics upload build phases + manual dSYM scripts as the workaround.
3. ATS fully disabled in both apps.
4. `-all_load` + hand-listed framework linker flags; `VALID_ARCHS`/`armv7` required-capability relics; `LastUpgradeCheck = 1220` (Xcode 12-era project hygiene).
5. Three inconsistent bundle ids / dev teams for the kiosk across configs (`com.secretdj.kiosk` vs `com.c-burn.kiosk`; teams L7S67T9D8T / 64422L3U8R / 45JT2WA84K).
6. Wildcard keychain access group shared via a single entitlements file for both apps.
7. Unreferenced plists (2 "copy" backups + `secretdjv3/SecretDJ-Info.plist`), dead Fabric keys, `IAPManager.swift-old.swift`, orphaned Heroku submodule, empty untracked `Modules/` OpenAPI skeleton.
8. Single shared module for two apps with `#if SECRET_DJ_KIOSK` / `KIOSK=1` sprinkled in — the rewrite's per-feature package structure supersedes this.
9. Test fixture code (`FixtureAccess.swift`) compiled into the shipping consumer app.

## Consumer app: features and flows

### Overview

The consumer app is a **server-driven UI** client. Almost every screen is a `FeedViewController` (a `UICollectionView` host) rendering a `SectionList` of `Section`s and `Item`s parsed from backend JSON; the *server* decides what cell templates appear, what tapping them does (via `Action` payloads), and what nearly every user-visible message says (toasts come back in API responses). The client's own logic is mostly navigation plumbing, purchase handling, and a handful of hard-coded rules called out below. Understanding the feed engine first makes every feature legible.

### Launch and root navigation

- `secretdjv3/AppDelegate.swift` — `@UIApplicationMain` for the phone target (the kiosk boots differently via `secretdjv3/main.swift`). At launch it: initialises the Facebook SDK, configures Firebase/Crashlytics, activates an `AVAudioSession` (`.playback`, 0.2s IO buffer) for song previews, installs a 64MB/256MB `URLCache`, seeds `UserManager` with an iTunes affiliate search URL and TradeDoubler click-wrap prefix/suffix (`http://itunes.apple.com/search?...partnerId=2003`, `http://clkuk.tradedoubler.com/click?p=23708...` — hard-coded, HTTP), and calls `TopUpManager.shared.onStartup()` to start observing the StoreKit payment queue. `applicationWillTerminate` stops observing.
- `secretdjv3/SceneDelegate.swift` — builds the window: a `UINavigationController` wrapping a single `CustomTabBarViewController`; forwards incoming URLs to the Facebook SDK (Spotify auth uses `ASWebAuthenticationSession` internally); on foreground it refreshes `URLSchemeHandler` (which apps — fb/twitter/instagram/uber — are installed) and applies the user's auto-lock preference (`isIdleTimerDisabled`).
- `secretdjv3/CustomTabBarViewController.swift` — the root. Owns a `UIPageViewController` plus a custom top tab bar (`CustomTabBar`). On `viewDidLoad`: starts screen-time analytics (`PageViewReportingManager`, method-swizzles `viewDidAppear` — `secretdjv3/PageViewReportingManager.swift`), and runs launch gates in order: (1) if the user previously requested account deletion (`UserManager.deleteAccountRequested`) it shows a blocking alert and `exit(0)`s; (2) if `UserManager.requiresLogin()` (no cached user id or empty keychain password) it presents the login flow in a **separate overlay `UIWindow`** (`LoginFlowController`). Tabs are only configured after a user exists. On every `viewDidAppear` it re-submits pending IAP top-ups (`TopUpManager.resubmitPendingTopUps()` — this pattern is repeated across many screens).
- `secretdjv3/TabBarConfigurationProvider.swift` — builds the tabs: **Places Nearby**, **Activity feed**, **Profile**. A News tab (`NewsFeedDataProvider`, endpoint `newsfeed`) is constructed but *not returned* — dead code, and the `Tab` enum in `CustomTabBarViewController.swift` (`placesNearby=0, rabbitFeed=1, news=2, profile=3`) no longer matches the 3 actual tab indices (only `.rabbitFeed` is ever used with `show(tab:)`, which happens to be correct).

### The feed engine (backbone of every screen)

- `secretdjv3/FeedViewController.swift` + `secretdjv3/FeedInteractor.swift` + `secretdjv3/FeedDataProvider.swift`. A VIP-lite pattern: VC → `FeedInteractorInput` → `FeedDataProvider` (per-screen fetch strategy) → `*APIAccess` classes; results come back as `SectionList`.
- **Model vocabulary** (`secretdjv3/SectionList.swift`, `secretdjv3/Section.swift`, `secretdjv3/Item.swift`, `secretdjv3/ItemImage.swift`): sections carry an `ItemType` (song/artist/venue/person/jukebox/topUp/event/news/…) and a `Template` id (`secretdjv3/AppConfiguration.swift`) that selects the XIB cell (`secretdjv3/FeedCellConfigurator.swift` maps Template→nib; cells are populated generically by splitting `item.text` on `\n` into tagged labels — server controls the copy of every cell line). "Hidden" sections (templates `hiddenVenueDetails=101`, `hiddenJukeboxList=602`, `hiddenProfile`, etc.) carry data that never renders but drives behaviour. Nested `container` sections (template 9999) render horizontally scrolling sub-collections (`secretdjv3/ContainerCollectionViewCell.swift`).
- **Actions**: each item (and the section list itself) can carry `Action`s (`secretdjv3/Action.swift`): `showTopup=1`, `launchUberApp=100/101`, `launchSearch=200`, `jukeboxGotoItem=300`, `jukeboxChangeAtmosphere=400`, `jukeboxSkipSong=401`, `jukeboxBlacklistSong=402`, `jukeboxRequestSong=403`, `gotoURL=500`. `secretdjv3/FeedActionProvider.swift` converts a tap (item or nav-bar action button) into navigation: song → TuneIn screen; artist with 1 song → TuneIn, with >1 → songs-for-artist list; venue → venue feed; person → their profile feed; news → in-app web view; promotion → deep-link into the Facebook/Instagram/Twitter app when installed (converting web profile URLs to `instagram://user?username=…` / `twitter://user?screen_name=…`), else external/in-app browser, else (no URL, internal) it just pings the `promote` endpoint (`promotionEngaged`). Top-bar action buttons (`secretdjv3/ActionBarButtonProvider.swift`) are likewise server-driven (insert-coin, hail-Uber, search icons).
- **Refresh rules** (`FeedViewController`): pull-to-refresh everywhere; auto-refresh only where the provider opts in (places/activity/venue/now-playing/music digest) on a 20s timer, tightened to **3s until the first GPS fix is ~12s old** (bug #181 workaround; `UserManager.gotFirstFixLocation`). Infinite scroll triggers `fetchNextFeedPage` within 2000pt of the bottom. Every feed fetch first requests a fresh location (`LocationManager.requestLocation`) — location is appended to *all* API calls by the networking layer (`secretdjv3/NetworkingParameterProvider.swift`).
- **Change detection**: paged feeds (music selection/digest/mood) carry a server `hash`; if the hash changes mid-pagination the interactor surfaces "jukebox changed" — toast `kJukeboxUpdatedText` + `notificationJukeboxChange`, which makes `JukeboxMenuViewController` pop back and reload.
- **Extra content ticker** (`secretdjv3/ExtraContentManager.swift`): places-nearby and venue screens fetch `extracontent` (screenid 1/2) and bounce up a bottom banner rotating every 10s between "Now playing…" songs and people; it shows while scrolling down, hides while scrolling up. Tapping a song opens the venue's Now Playing screen; tapping a person jumps to the activity tab (`FeedInteractor.userTappedExtraContent`).

### Login, sign-up, onboarding

- `secretdjv3/LoginFlowController.swift` orchestrates a storyboard flow ("RewriteLogin") in the overlay window; `secretdjv3/LoginViewController.swift` is the entry screen with three routes:
  - **Native**: screen name + password (sign-in button enables at ≥5 password chars); password is **SHA-1 hashed client-side** and stored in the keychain (`secretdjv3/SDJLoginManager.swift`, `secretdjv3/LoginAPIAccess.swift` — endpoint `signin`); the hash also feeds request signing.
  - **Facebook**: gated on ATT tracking permission (`secretdjv3/AppTrackingTransparency.swift`) — the button is disabled if tracking was rejected; a 1s delay works around an FB SDK bug on first ATT grant. Server endpoint `facebooksignin`; `LoginDetails.created` distinguishes sign-in vs new account.
  - **Sign in with Apple** (`applesignin`): first-auth name/email are cached in the keychain (`secretdjv3/KeychainAppleUserInfo.swift`) because Apple only supplies them once.
  - New-account onboarding steps differ by route (`nextStepOfSignUpFlow` / `…Facebook…` / `…Apple…`): native → gender → photo → details (first/last/email/screenname/password, validated by `secretdjv3/ProfileDetailsValidator.swift`: names `[a-zA-Z][a-zA-Z0-9-']{0,29}`, screen name 5–30 chars, password ≥5, server-matching email regex); Facebook → username → photo; Apple → username → gender → photo. Photo upload (`secretdjv3/UploadProfilePicture.swift` → `newavatar`) completes login.
- Persistence: `secretdjv3/UserManager.swift` — current user + last venue stored in UserDefaults (Codable JSON on this branch, with one-time migration from NSKeyedArchiver blobs), password in keychain, plus flags (keepSignedIn, disableAutoLock, deleteAccountRequested). First-run wipes stale Sign-in-with-Apple keychain data.
- The kiosk's `AttractViewController` (`secretdjv3/AttractViewController.swift`) is **kiosk-only** (only referenced from `secretdjv3/KioskNowPlayingViewController.swift`); the consumer app has no attract mode.

### Tab 1 — Places Nearby

- `secretdjv3/PlacesNearbyFeedViewController.swift` + `PlacesNearbyFeedDataProvider` (endpoint `placesnearby`; returns venues near the user's location). If location permission is denied a full-screen `LocationPermissionDeniedView` overlays with a deep link to Settings. Optional map bar button (`MapConfig.showMap`) opens `secretdjv3/VenueMapViewController.swift`: pins for all nearby venues (special pin for venues whose `properties` bitmask has `vpHasJukebox`), tap → that venue's feed.
- Development GPX location fixtures live beside the source: `secretdjv3/Chiswick.gpx`, `North London.gpx`, `Novodington Arms.gpx`, `Sekforde Street.gpx`, `St. Winifreds Road.gpx` (Xcode location-simulation waypoints, e.g. "Brouhaha" at 51.58,-0.10).

### Tab 2 — Activity feed ("rabbit feed")

- `ActivityFeedDataProvider` (endpoint `eventhistory`), plain `FeedViewController`, auto-refreshing. Content is entirely server-driven: check-ins, song requests, awards, people, etc., rendered through the generic template system (`CheckInCollectionViewCell`, `AwardCollectionViewCell`, `FeedItemCollectionViewCell`, …). There is no client-side awards model — awards are just server items with award templates (102, 104–106).

### Tab 3 — Profile

- `secretdjv3/ProfileFeedViewController.swift` + `ProfileFeedDataProvider` (endpoint `persondetails`; used for both "my profile" tab and other users' profiles reached by tapping people). A hidden section carries the `Person`; the header (`ProfileSectionHeaderView`) shows avatar, screen name and interaction stats parsed from section custom data — `placesVisited`, `songRequests`, `peopleWhoLikeUser`, last check-in venue/zone (`secretdjv3/Person.swift`).
- Header buttons: **like** the person (optimistic toggle, rolled back on failure; `secretdjv3/LikeAPIAccess.swift`, like/unlike endpoints with item type person), **change photo**, and (own profile) **edit → Settings**.
- **Settings** (`secretdjv3/SettingsViewController.swift`, storyboard "RewriteSettings"; on this branch replaced by SwiftUI `SettingsScreen` behind `FeatureFlags.swiftUI(.settings)`): change profile picture, gender (`setuserdetails`-family via `secretdjv3/UserDetailsAPIAccess.swift`), details, password, and **Request account deletion** (`secretdjv3/RequestDeleteAccountViewController.swift`): requires re-entering the password (compared as SHA-1 against the stored hash), confirm dialog, calls `requestdeleteaccount` (`secretdjv3/RequestDeleteAccountAPIAccess.swift`), persists a local flag, then **`exit(0)`**; on next launch the app shows a farewell alert and exits again (see CustomTabBarViewController above). The account is presumably deleted server-side asynchronously (inferred).

### Venue screen

- `secretdjv3/VenueFeedViewController.swift` + `VenueFeedDataProvider` (endpoint `venuedetails`), auto-refreshing. Header (`VenueSectionHeaderView`) offers:
  - **Check in** (`secretdjv3/CheckInAPIAccess.swift`, endpoint `checkin`): optimistic UI (button disables), scope is always `.everyone` — the `CheckinVisibility` enum (friends/everyone/incognito) exists but the consumer app never offers a choice. Success toast/rich-toast + optional URL come from the server; failure rolls back.
  - **Like** the venue (same optimistic pattern as person like).
  - **Directions** → `secretdjv3/VenueDirectionsViewController.swift`: MapKit map with venue pin + **walking route** from current location (`secretdjv3/DirectionsProvider.swift`), phone-call button, and pre-filled SMS/email share ("meet me here") via `secretdjv3/DirectionsMessageProvider.swift`.
  - **Jukebox** → the music-choosing stack below. Page title is "Control Music" when `venue.machineControl` is set, else "Choose Music".
- Client-side rule: the venue feed's social-links section (`ItemType.event` promotions) is re-ordered and capped at 3 — Instagram first, then Twitter, website, Facebook only if room (`filterSocials`/`prioritiseSocialItems` in `VenueFeedViewController.swift`).

### Choosing music: digest → jukebox pages → search

- `secretdjv3/JukeboxMenuViewController.swift` (storyboard "Music") hosts a horizontally paged UI: page 0 is the **music digest** (`secretdjv3/MusicDigestFeedViewController.swift`, endpoint `musicdigest`) — now-playing song plus a grid of the venue's jukeboxes/playlists; the hidden `hiddenJukeboxList` section defines the jukeboxes, and each subsequent page is a **music selection** feed for one jukebox (`secretdjv3/MusicSelectionFeedViewController.swift`, endpoint `musicselection`, hash-checked pagination in 50-song batches with server-adjustable batch size). Adjacent pages are pre-fetched. At venues with machine control, the digest polls now-playing every **9 seconds** (endpoint `playhistory`).
- **Search** (nav-bar action `launchSearch`, only ever server-offered with a venue): `secretdjv3/SearchContainerViewController.swift` pages between:
  - **Artist search** (`secretdjv3/ArtistSearchFeedViewController.swift`): downloads the venue's *entire available-artist index* once (endpoint `artistsavailable`), buckets artists client-side into A–D/E–H/… groups with diacritic stripping (`secretdjv3/SearchAPIAccess.swift`, short index for phone / long for kiosk), renders an alphabet fast-scroll index (`secretdjv3/BDKCollectionIndexView.h/.m`, ObjC), and filters locally as you type — deliberately never filtering down to an empty list. Tap artist: 1 song → straight to TuneIn; else songs-for-artist feed (server search `type=artists` with the artist name as query).
  - **Song search** (`secretdjv3/SongSearchFeedViewController.swift` + `SongSearchFeedInteractor.swift`): server round-trip per keystroke (endpoint `musicsearch`, `type=2 songs`, `searchmask=1 computeLikes`), with stale-response suppression by comparing the current search term.
- On this branch, search and mood screens have SwiftUI replacements behind default-on feature flags (`secretdjv3/SwiftUI/Core/FeatureFlags.swift`; factories referenced from `FeedActionProvider`), with the UIKit path retained as kill-switch fallback.

### Song screen and the request flow (TuneIn) — the core of the product

- `secretdjv3/TuneInViewController.swift` (storyboard "Music", id "TuneIn"). Shows artwork (full-bleed if the server flags a full-size image, else small artwork centred over a blurred copy of itself — `secretdjv3/UIImage+ImageEffects.h/.m`), artist/title, like ("buzz") info.
- **Preview**: if `song.previewURL` exists, a 30-second preview player with slider/elapsed/length. The preview file is *downloaded* and fed to `AVAudioPlayer` (not streamed) because the backend serves previews from S3 with a `.pbz` extension and generic content type that `AVPlayer` refuses. Playback hard-stops at 30s.
- **Which buttons show is server-decided** via the song's `actions` array (`checkActions`): `jukeboxRequestSong` → the green "play it on the jukebox" button; `jukeboxSkipSong` / `jukeboxBlacklistSong` (staff-ish controls the server can grant, e.g. at machine-control venues) → skip/never-play buttons replacing it, calling the `machinecontrol` endpoint (action 401/402) with server-worded result toasts.
- **Requesting a song**: button disables, `secretdjv3/SelectSongAPIAccess.swift` calls `requestsong` (user, venue, songid). Responses: `ReturnCode 0` → success toast or rich toast + optional URL (server decides the copy — credit deduction/confirmation is entirely server-side); **`ReturnCode -8` = out of credits** (`WSRX_ERROR_REQUEST_NO_CREDITS`), and the response's `ImageSize` tells the client whether the user has a profile picture:
  - no profile pic → `secretdjv3/ProfilePicForCreditsViewController.swift` dialog: "add a profile picture" **in exchange for free credits** (upload path reuses the login photo screen; reward text arrives in the upload response);
  - has one → push the top-ups screen (context `noCredits`).
  Any other non-zero code → server-provided error toast. **No credit prices, request limits, or cooldowns are encoded client-side — they all live in the backend.** The only client-side song rule: intermission entries (`songId == "0"`) are inert (`FeedActionProvider.handle(songItem:)`, `AppConfiguration.intermissionSongId`).
- **Like**: optimistic heart toggle via like/unlike endpoints; server like-toast (often "X people buzzed this") with optional URL.
- **Listen elsewhere** (`secretdjv3/ListenToSong/ListenToSong.swift`, SwiftUI bottom sheet in `secretdjv3/Components/`): Apple Music (iTunes search + TradeDoubler affiliate wrap — `secretdjv3/ITunesAPIAccess.swift`), YouTube (server `watchonyoutube` returns a video id or search query; deep-links the YouTube app else web), Spotify open (canonical `open.spotify.com` link from the song's `SpotifyId`; usage logged via `spotifyevent`), and **Save to Spotify**: server `spotisave` logs/validates, then the app itself (OAuth via `ASWebAuthenticationSession`, `secretdjv3/SpotifyAuthManager.swift`; client id in `AppConfiguration.SpotifyConfig`) finds-or-creates a playlist named **"Secret DJ"** and adds the track (`secretdjv3/SpotifyAccess.swift`).

### Change mood (machine control)

- At machine-control venues the server offers `jukeboxChangeAtmosphere` control items (coloured mood tiles, `secretdjv3/Control.swift`). `secretdjv3/ChangeMoodFeedViewController.swift` + `MoodFeedDataProvider` (endpoint `styleinfo`) shows the mood's song list; the header (`secretdjv3/MoodSectionHeaderView.swift`) has an hours/minutes slider, and "change mood" posts `machinecontrol` (action 400, `value` = minutes to hold the mood). On success it pops back to the jukebox menu.

### Now Playing / play history

- Reached from the extra-content ticker: `secretdjv3/NowPlayingFeedViewController.swift` + `NowPlayingFeedDataProvider` (endpoint `playhistory`, auto-refresh): current song as a rich header (like + listen-elsewhere actions) over the venue's recent-play list; tapping the header opens TuneIn (with `topupAllowed: false`).

### Credits and top-ups (IAP)

- Entry points: nav-bar insert-coin action (context `insertCoin`) or the out-of-credits flow (context `noCredits`). `secretdjv3/AvailableTopUpsViewController.swift` is a feed of `TopUp` products (endpoint `topupdetails`, parameterised by context and vendor) plus: a **voucher-code redemption** bar (endpoint `redeemjukeboxvoucher`; success toast then pops), **Restore Purchases**, and a T&Cs web link (`secretdj.com/terms-conditions` with a cache-busting timestamp).
- Product reconciliation (`secretdjv3/IAPManager.swift`): server SKUs are matched against `SKProductsRequest`; products missing from the App Store are **removed from the list**, and displayed prices are replaced with the store's localised price (sub-£1 prices reformatted as "Np"). `secretdjv3/TopUp.swift` carries sku/credits/price from the server.
- Purchase pipeline (`secretdjv3/TopUpManager.swift` → `IAPManager` → `secretdjv3/TopUpAPIAccess.swift`): buy via StoreKit (180s timeout; 20s for restore) → on `.purchased`, build a confirmation payload (transactionId, sku, timestamp, bundle id, base64 App Store receipt) → **server-side verification** via `topupnotify` (the server credits the account). Crucially, the confirmation is persisted to `PendingTopUps` (`secretdjv3/PendingTopUps.swift`) *before* verification; every screen appearance retries the oldest pending top-up, verification itself retries up to 3 times, and a pending top-up is only abandoned after **5 resubmissions** (heavily instrumented with `TP_*` analytics events). Server return codes: 0 = credited, 1 = already processed (silently removed from pending), <0 = retryable. A blocking `VerifyTopUpViewController` modal shows progress/outcome (`secretdjv3/VerifyTopUpViewController.swift`). Restore purchases reports "no purchases to restore" together with the server's paid-credit count (`numpaidcredits`). PayPal support exists behind `PAYPAL_SUPPORTED` but `vendor()` is hard-coded to `.appleAppStore` (`secretdjv3/TopUpManager.swift`), so it's dead; `secretdjv3/IAPManager.swift-old.swift` at repo root is an abandoned copy.

### Cross-cutting behaviours

- **Toasts**: `secretdjv3/ToastManager.swift` queues simple and "rich" toasts (server-supplied dictionaries rendered by `RichToastView`, e.g. award-style check-in/request rewards); `secretdjv3/ToastHandler.swift` gives every VC `handleSimpleToast/handleRichToast(_:withURL:)` — if the server response carries a URL, an in-app web view (`secretdjv3/InternalWebViewController.swift`, "Web" storyboard) is pushed *instead of* the toast. This response-shape (Text + optional Data richtoast + optional Url) recurs across check-in, song request, like, and Spotify saves.
- **Analytics**: every feed screen reports named page views with dwell time (feedName strings like "PlacesNearbyFeed"); API accesses report events (`requestSong`, `checkIn`, `musicSearch`, `redeemVoucher`, …) through `secretdjv3/Reporting.swift`; Crashlytics user id is kept in sync (`UserManager.updateCrashlyticsDetails`).
- **Skins**: `secretdjv3/SkinManager.swift` downloads venue-branded assets/colours/strings (`skinresources`) — in practice consumed by the kiosk UI (attract URL, keyboard skins); the consumer app references it only marginally.

### Business rules worth preserving (client-side)

1. Login gate before any tabs exist; account-deletion flag blocks the app permanently until reinstall.
2. Password: SHA-1 client hash, keychain storage, min 5 chars; validation regexes above match server rules.
3. Feed auto-refresh 20s, boosted to 3s until first GPS fix (+12s grace).
4. Hash-based "jukebox changed" detection during paginated music browsing → forced reload + toast.
5. Song request out-of-credits (`-8`) branches on profile-pic presence → pic-for-credits offer vs top-up screen.
6. Intermission songs (id "0") are not tappable/requestable.
7. Server's `actions` array on a song dictates request vs skip vs blacklist affordances.
8. Preview = download-then-play, 30s cap.
9. Top-up resilience: persist-before-verify, retry ×3, resubmit-on-every-screen ×5 then expire; App Store price overrides server price; unavailable SKUs hidden.
10. Venue social links: Instagram-first ordering, max 3.
11. Promotions deep-link to native social apps when installed.
12. Check-ins always sent with `scope=everyone`.
13. Artist search: client-side bucketing/filtering of a downloaded index; song search: per-keystroke server query with stale-result suppression.
14. Spotify saves go to a playlist named "Secret DJ" (found case-insensitively or created).
15. Response URLs supersede toasts (push web view instead).

### Tech debt observed in this lane (candidates to drop)

- Dead News tab + mismatched `Tab` enum (`TabBarConfigurationProvider.swift`).
- Hard-coded HTTP affiliate URLs seeded in `AppDelegate.swift`.
- PayPal machinery behind a never-true flag; `IAPManager.swift-old.swift` at repo root; large blocks of commented-out constraint code throughout (e.g. `LoginViewController.swift`, `AvailableTopUpsViewController.swift`).
- `viewDidAppear` swizzling for page-view analytics (`PageViewReportingManager.swift`).
- Cell population via magic view tags + `\n`-split text (`FeedCellConfigurator.swift`).
- Delegate-set-on-every-viewDidAppear pattern for `TopUpManager.verifyTopUpDelegate` (shared-singleton delegate juggling).
- Legacy sample-app remnants in Sign-in-with-Apple (`showPasswordCredentialAlert` displays a password in an alert — debug-grade code in `LoginViewController.swift`).
- SHA-1 password hashing (weak by modern standards; server contract, so a rewrite must coordinate).

## Kiosk app: the venue iPad

### What the kiosk is

The kiosk target builds "Secret DJ Kiosk" (`PRODUCT_NAME = "Secret DJ Kiosk"`, bundle id `com.secretdj.kiosk`, iPad-only `TARGETED_DEVICE_FAMILY = 2`, landscape-only per `SecretDJKiosk-Info.plist` `UISupportedInterfaceOrientations~ipad`, iOS 15.6 floor while the phone target moved to 17.0 — all in `secretdj.xcodeproj/project.pbxproj`). Its operational model, read straight from the code, is: **a pub employee signs the iPad in once with a venue-bound account, and the device then runs all day as a self-service, walk-up jukebox terminal** — browsing jukeboxes (playlists), searching, previewing, and requesting songs against the shared cloud backend, with an attract screen-saver between users. Despite the "employee controls the music" framing, the kiosk UI itself contains **no queue view, no skip button, and no approve/veto workflow for customer requests** (see "Employee control" below).

It is not a separate codebase: the kiosk target compiles 248 source files vs the phone's 217, and the diff is only ~35 kiosk-only files plus the phone's `AppDelegate.swift`/`SceneDelegate.swift`/`FixtureAccess.swift`/`UIStackView+BgCol.swift` (target-membership diff computed from `secretdj.xcodeproj/project.pbxproj`). Everything else — networking, feed engine, models, IAP, Spotify, Facebook — is shared, with runtime `AppConfiguration.shared.isKiosk` branches (bundle-id sniffing in `secretdjv3/AppConfiguration.swift`) and a compile-time `-DSECRET_DJ_KIOSK` Swift flag plus `KIOSK=1`/`LEGACY=1` GCC defines on the kiosk target (`project.pbxproj`).

### Boot and composition

- `secretdjv3/main.swift` is the kiosk-only entry point: it calls `UIApplicationMain` with **`KioskApplication`** (custom `UIApplication` subclass) and **`KioskAppDelegate`**. The phone target instead uses `@main`-style `AppDelegate.swift`.
- `secretdjv3/KioskApplication.swift` overrides `sendEvent(_:)` and posts a `UserDidTouchScreen` notification (on a background queue) for **every touch anywhere in the app**. This is the global activity detector that feeds the idle/attract timers.
- `secretdjv3/KioskAppDelegate.swift` boots Facebook SDK, Firebase/Crashlytics, an `AVAudioSession` (`.playback`, 0.2 s preferred IO buffer), a 64 MB memory / 256 MB disk shared `URLCache`, and hard-codes iTunes affiliate search/TradeDoubler URL prefixes onto `UserManager` ("TODO: Find some better way of doing this" — the comment is in the file).
- `secretdjv3/KioskSceneDelegate.swift` builds the window: if `UserManager.shared.currentUser?.personId` or `currentVenue?.venueId` is missing it starts `KioskLoginFlowController.beginLoginFlow` (in a **second `UIWindow` layered above the main one**); otherwise it goes straight to the home screen. On `sceneDidBecomeActive` it sets `UIApplication.shared.isIdleTimerDisabled = UserManager.shared.disableAutoLock ?? false`.
- **Screen-always-on / guided access**: the only in-app mechanism is that `DisableAutoLock` toggle, exposed as an iOS Settings switch via `secretdjv3/Settings.bundle/Root.plist` ("Disable Auto-Lock", default false; also "Stay signed-in"/`KeepSignedIn`). There is no Guided Access API usage anywhere in the source (grep for "guided" returns nothing), so physical kiosk lockdown must be assumed to be OS-level Guided Access or MDM — inference; not evidenced in code.
- `SecretDJKiosk-Info.plist` hides the status bar, requires a Facebook URL scheme (`fb144876722233890`), and sets `NSAllowsArbitraryLoads = true` (ATS effectively off). It still names `Login_iPhone` as `UIMainStoryboardFile` even though the scene delegate replaces the root programmatically — vestigial.

### Venue login and the skin system

- `secretdjv3/KioskLoginViewController.swift` is a plain username/password form (no Facebook/Apple sign-in on kiosk). `secretdjv3/KioskLoginFlowController.swift` drives the flow: it calls the same `signin` endpoint as the phone app, but **requires the response to contain a venue**: `LoginAPIAccess.serverLoginDetails` (`secretdjv3/LoginAPIAccess.swift`) reads `Venues.Force` from the response and builds a `Venue` from that forced id; if `loginDetails.venue` is nil, `KioskLoginFlowController.loginSuccess` rejects with `kSignInUnauthorisedProblemText` ("wrong type of signin"). **Business rule worth preserving: kiosk credentials are venue accounts, and the backend pins them to one venue via `Venues.Force`.** The SHA-1-hashed password is stored on `UserManager` for request signing.
- After login the flow downloads the **skin**: `secretdjv3/SkinManager.swift` fetches a manifest from the `skinresources` endpoint and downloads per-venue image assets and text/colour properties, keyed by well-known numeric ids, into `Documents/skin_assets` (progress bar shown by `KioskSigningInViewController` from `KioskLogin.storyboard`). Nearly every pixel of kiosk chrome is server-skinnable: backgrounds, buttons (default+highlight), loading spinner, keyboard keys, tile placeholders, section headers (`SkinAsset` enum), colours (`SkinColor`), and **behavioural settings as text properties**: `attractURL` (1020), `attractTimeoutSeconds` (1021), `idleTimeoutSeconds` (1004), `headerHeight` (1003), search placeholders, and toast background/text/border colours (1010–1013, consumed by `secretdjv3/SimpleToastView.swift`'s `initializeKioskAttributes`, which also doubles toast size on kiosk). Skin-driven `UIButton` subclasses live in `secretdjv3/KioskStandardButton.swift` and its subclasses (`KioskSearchButton`, `KioskRequestSongButton`, `KioskAllJukeboxesButton`, `KioskTuneInCloseButton`, `StandardKeyButton`, `WideKeyButton`, `SearchClearButton`).
- Skin download failure shows a retry-only alert (`Kiosk_SkinDownloadFailed_*` strings in `KioskLoginFlowController.skinResourcesLoadingComplete`) — the kiosk cannot proceed unskinned.
- **Staff reset easter egg**: typing `?RESTART?` into either search tab purges `URLCache`, deletes all skin assets, clears the current user, saves, and calls `exit(0)` so a relaunch forces a fresh sign-in and skin download (`secretdjv3/KioskSearchArtistViewController.swift:84-95` and `secretdjv3/KioskSearchSongViewController.swift:145-155`; reintroduced in commit `8f1ddaa4`). This is the documented field-service reset mechanism and should be preserved (or replaced with something less brutal) in the rewrite.

### Home screen: Now Playing + jukebox wall

`secretdjv3/KioskNowPlayingViewController.swift` (storyboard id `KioskNowPlaying` in `secretdjv3/Kiosk/Storyboards/Kiosk.storyboard`) is the permanent root. It is a header ("now playing" panel with skinnable height) above an embedded `UINavigationController` (`embedNavigationController()`) containing the browsing stack:

- **Now-playing header**: polls the shared `playhistory` endpoint (`FeedAPIAccess.nowPlaying`, `secretdjv3/FeedAPIAccess.swift:59`) every **20 seconds**, updating only when the song id changes. Album art logic: full-size art fills the header; small-only art is centered over a blurred copy of itself; skins provide "no image"/"empty" fallbacks. Cross-fades between a `currentInfoView` and `nextInfoView` pair of label sets. **Intermission rule**: when the reported song id equals `AppConfiguration.intermissionSongId` (`"0"`), the song's title is split on `"\n\n"` into two display lines and artwork is suppressed — the backend uses song id 0 to push arbitrary two-line messages to the kiosk header.
- **Jukebox digest** (root of the embedded nav): `secretdjv3/KioskMusicDigestFeedViewController.swift` shows the venue's jukeboxes as a tile wall via `MusicDigestFeedDataProvider` (`secretdjv3/FeedDataProvider.swift:488`) hitting the `musicdigest` endpoint. On kiosk it always reloads on appearance ("in case jukeboxes change", `shouldReloadOnViewAppearance`), and — unlike the phone — **ignores server hash changes instead of erroring** (`FeedDataProvider.swift:566-577`, commit `43019827` "so we don't get into a nasty state when available jukeboxes change").
- **Jukebox detail**: tapping a jukebox pushes `secretdjv3/KioskMusicSelectionFeedViewController.swift` (song grid for that jukebox via `musicselection` endpoint, paged 50 at a time with a server-controlled `Batch` size and a `hash` that signals the jukebox's content changed — `MusicSelectionFeedDataProvider`, `FeedDataProvider.swift:402`). While in detail, the header switches to showing the selected jukebox's art/title (`updateSelectedJukeboxDetails`, `InfoViewType.currentJukebox`), now-playing polling pauses, and a skinned "All jukeboxes" button appears to pop back.
- A `Jukebox` (`secretdjv3/Jukebox.swift`) is `{itemType, jukeboxId, textColour, subtitle}` parsed from the feed's `Data` dictionary — jukeboxes are server-defined playlists/categories, not devices.

### Attract loop and timers

- `secretdjv3/AttractViewController.swift` is simply a full-screen `WKWebView` loading the skin's `attractURL`, with an invisible full-screen button that dismisses it on any tap. **The attract "screensaver" is a server-hosted web page per venue**, not local media.
- `secretdjv3/KioskTimer.swift` owns two one-shot timers (attract + idle), both restarted by the `UserDidTouchScreen` notification from `KioskApplication` and by `PlaybackStarted`/`PlaybackStopped` notifications; **while a song preview is playing neither timer runs** (`isMusicPlaying` guard), so the attract screen never interrupts a preview.
- `KioskNowPlayingViewController` wires it up (`configureTimer`): timeouts come from skin texts `attractTimeoutSeconds`/`idleTimeoutSeconds` with a 10 s default (`secretdjv3/KioskAppConfig.swift`). On **idle timeout** it dismisses any modal, pops the embedded nav to the jukebox wall, and restores the now-playing header; on **attract timeout** it presents the attract web view (fade transition). A preload trick inserts the attract view invisibly at the back of the hierarchy at `viewDidLoad` so the web content is already rendered when it fades in (`prepareAttractView`). (Note: `secondsUntilAttract` with its ≥10 s clamp at `KioskNowPlayingViewController.swift:77-80` is computed but never used — the actual timer takes the raw skin value; apparent dead code.)

### Search

`secretdjv3/KioskSearchViewController.swift` (pushed from the header's Search button) is a bespoke full-screen search UI designed for a public terminal:

- **Custom on-screen keyboard** (`secretdjv3/KioskSearchKeyboardViewController.swift`, skinned keys, an ABC/123 slide-over swap): the system keyboard is suppressed by giving the text field an empty `inputView` and clearing the input-assistant bar groups. Input is **capped at 10 characters** (`keyTapped` guards `count <= 9`).
- Two tabs in a `UIPageViewController`:
  - **Artists** (default): `secretdjv3/KioskSearchArtistViewController.swift` is a 38 %/62 % split view — left, an A–Z artist list for the whole venue catalogue (`ArtistSearchFeedDataProvider` via `artistsavailable`; filtered client-side as you type by `ArtistSearchFeedInteractor`, with a `BDKCollectionIndexView` ObjC index strip, `secretdjv3/KioskSearchArtistListViewController.swift`); right, the selected artist's songs (`SongsForVariableArtistFeedDataProvider`, `secretdjv3/KioskSearchArtistDetailViewController.swift`).
  - **Songs**: `secretdjv3/KioskSearchSongViewController.swift` server-searches (`SongSearchFeedDataProvider` / `musicsearch`) on every keystroke past 1 character, discarding stale responses by comparing the echoed search term.
- Search results and jukebox grids use kiosk-specific nibs and headers: `Kiosk/Nibs/KioskMatrixSongMediumCollectionViewCell.xib`, `KioskArtistCollectionViewCell.xib`, `KioskSectionHeaderView.xib` (registered by `secretdjv3/KioskSupplementaryViewProvider.swift`).

### Requesting a song (the kiosk's whole write path)

Tapping any song anywhere routes through `secretdjv3/KioskFeedActionProvider.swift`, which intercepts `Song` items (skipping intermission entries) and presents `secretdjv3/KioskTuneInViewController.swift` (`KioskTuneIn` in `Kiosk/Storyboards/KioskMusic.storyboard`) as a pop-in modal:

- **Preview**: downloads the 30-second preview bytes manually (backend serves them from S3 with a bogus extension/content type AVPlayer can't stream — comment in `startAudioPlayer`) and plays via `AVAudioPlayer`, hard-stopping at 30 s. Posts `PlaybackStarted`/`PlaybackStopped` so the attract loop stays away.
- **"Play on jukebox"**: calls the **same `requestsong` endpoint as the consumer app** (`secretdjv3/SelectSongAPIAccess.swift`), with the venue-account user id + venue id. The no-credits error case is explicitly ignored: "In kiosk mode they will never run out of credits" (`KioskTuneInViewController.jukeboxButtonTapped`). **Kiosk requests are unmetered; consumer requests are credit-metered** — a core business rule.
- Success/failure surfaces as a skinned toast (`ToastManager`; kiosk toasts don't keyboard-adjust and use skin colours).
- Oddity: the kiosk search/selection feed VCs still wire `TopUpManager.shared.verifyTopUpDelegate` and call `resubmitPendingTopUps()` on appearance (`KioskMusicSelectionFeedViewController.viewDidAppear`) — credit-purchase plumbing inherited from the shared base class chain that is meaningless on an unmetered kiosk.

### Employee control of the music — what exists and what doesn't

- The kiosk has **no queue management, no skip, no blacklist, and no approve/veto of customer requests** in any kiosk-only file. The moderation feature set — skip track, blacklist track, "change mood" (override the jukebox for N minutes) — lives in shared code: `secretdjv3/MachineControlAPIAccess.swift` (`machinecontrol` endpoint, actions `jukeboxSkipSong` / `jukeboxBlacklistSong` / mood with a minutes value) and is invoked from `secretdjv3/TuneInViewController.swift` (the **phone** app's song screen) and `ChangeMoodFeedViewController`, gated by the per-session `venue.machineControl` privilege flag parsed from venue feed data (`secretdjv3/Venue.swift:77`). The phone app renames its jukebox menu "Control Music" when that flag is set (`secretdjv3/JukeboxMenuViewController.swift:77`). So in the legacy system, **an employee moderates from the consumer phone app signed into a privileged account, not from the kiosk**.
- One indirect path exists on the kiosk: if the venue's digest feed contains `Control` items (`matrixControlLarge` tiles — the kiosk cell map includes `MatrixMachineControlLargeCollectionViewCell`, `secretdjv3/ContainerCellConfigurator.swift:31`), `KioskFeedActionProvider` falls through to the shared provider, which pushes the UIKit `ChangeMoodFeedViewController` (`secretdjv3/FeedActionProvider.swift:188-206`; the SwiftUI variant is compiled out on kiosk via `#if !SECRET_DJ_KIOSK`). So "change mood" tiles *can* appear on a kiosk if the backend serves them for that venue account. Whether any venue's feed actually did is not determinable from code.

### Relationship to the consumer app / backend

Same cloud backend, same account/venue model, no local networking: every kiosk call goes to `https://api4.secretdj.com/` (`secretdjv3/NetworkAccess.swift:62`) using the shared signed-request stack; there is no Bonjour/multipeer/local discovery anywhere in the source. The kiosk distinguishes itself to the server by appending **`appmodel=1`** to every request (`secretdjv3/NetworkingParameterProvider.swift:97-99`) in addition to the shared `appmask` feature mask and optional `coords`. Consumer requests and kiosk requests land on the same `requestsong` endpoint; the shared now-playing/`playhistory` feed is what both apps observe. The jukebox hardware/actual playback engine is entirely server-side — nothing in either app plays the pub's music.

### Shared-feed-engine kiosk branches (the "remove containers" story)

The shared feed engine renders sections either as nested "container" cells (horizontal rails, phone style) or as flat vertical grids. On kiosk: `Section` marks `matrixSongMedium` as **not** horizontal (`secretdjv3/Section.swift:137`), `SectionList` only admits `matrixSongMedium` sections on kiosk (`secretdjv3/SectionList.swift:102`), `ContainerCollectionViewCell` swaps in a plain `UICollectionViewFlowLayout` (`secretdjv3/ContainerCollectionViewCell.swift:29`), and the kiosk VCs re-apply flat flow layouts with `KioskCellConfiguration` insets (`secretdjv3/KioskCellConfiguration.swift`). Cell sizing forks wholesale on `isKiosk` (`secretdjv3/FeedCellSizeCalculator.swift:19` routing to `cellSizeiPad`, with kiosk column counts of 1/2/3/6/8 by template in `secretdjv3/ContainerCellSizeCalculator.swift`), kiosk tile constants live in `KioskSizes` (`secretdjv3/AppConfiguration.swift:51`, "reduced from 297 because was wrapping after 2023 reskin"), corner radii are skipped on kiosk (`secretdjv3/StyleKit2023.swift:78`), and the kiosk xib map substitutes `KioskMatrixJukeboxLargeCollectionViewCell` / `KioskMatrixSongMediumCollectionViewCell` (`secretdjv3/ContainerCellConfigurator.swift:17-31`).

Git history confirms these were deliberate campaigns: `origin/feature/kiosk-remove-containers` (Dec 2017: "updating collectionview layouts to handle matrix cells on ipad", touching the three kiosk feed VCs and `FeedCellSizeCalculator`) **is an ancestor of the current `refactor` branch** (verified with `git merge-base --is-ancestor`). `origin/feature/kiosk-performance` is an older unmerged spike whose commit log ("Adding activity detector", "Implemented 'inactivity timer'", "Fixes for double-vertical scrolling", "Rewired now playing view container", "Change size of jukebox tiles") describes exactly the mechanisms present in today's `KioskTimer.swift`, `KioskApplication.swift`, and `KioskNowPlayingViewController.swift` — its work landed via other branches even though the tip never merged. Performance measures visible in code: the 64/256 MB `URLCache`, in-memory skin image cache (`SkinManager.images`), off-main touch-notification queue, 20 s poll cadence (not push), 50-item feed paging, and blur work dispatched off the fade animations.

### Build/target facts the rewrite must not lose

- Kiosk-only compile flag `-DSECRET_DJ_KIOSK` (Swift) + `KIOSK=1`, `LEGACY=1` (GCC); used to exclude the SwiftUI screens and phone-only toast/profile behavior (`secretdjv3/FeedActionProvider.swift`, `secretdjv3/ToastManager.swift:323`, `secretdjv3/ProfileFeedViewController.swift:113`).
- **The refactor branch's SwiftUI migration is phone-only by design**: "phone path only — the kiosk keeps the UIKit engine" (`secretdjv3/SwiftUI/Feed/FeedViewStateBuilder.swift:14`). A greenfield rewrite is therefore the kiosk's *first* SwiftUI pass; there is no partial kiosk SwiftUI work to reuse.
- Per-target Firebase configs: `secretdjv3/Firebase/kiosk/GoogleService-Info.plist` vs `.../phone/...` (commit `565920c6`), plus a manual dSYM upload script `upload-kiosk-dsyms-to-firebase-crashlytics` at repo root.
- Live kiosk UI files: `secretdjv3/Kiosk/Storyboards/{Kiosk,KioskLogin,KioskMusic}.storyboard`, `secretdjv3/Kiosk/Nibs/*.xib`, `secretdjv3/Kiosk.xcassets` (one gradient image). `Kiosk_iPad.storyboard` is dead per `docs/storyboard-audit.md` but still ships in the kiosk Resources phase. `KioskLogin.storyboard` still contains an unused full sign-up flow (Gender/UserName/Avatar/Details/ForgotPassword scenes) inherited from the phone login.
- The kiosk tests target is an empty placeholder (`SecretDJKioskTests/SecretDJKioskTests.swift` has one no-op `testExample`); the kiosk has effectively zero test coverage.

### Tech debt NOT worth carrying forward

1. **Whole-consumer-app-in-the-kiosk-binary**: the kiosk compiles the entire phone codebase (IAP/`TopUpManager`, PayPal remnants, Spotify auth, Facebook login, profile editing, maps) even though its UI can never reach most of it; behavior differences hang off runtime `isKiosk` checks scattered across 20+ shared files. The rewrite should make the kiosk a thin app over shared domain packages instead.
2. **Bundle-id-sniffing `isKiosk`** with `fatalError` on unknown ids (`secretdjv3/AppConfiguration.swift:121-132`): it recognises only `com.c-burn.secretdj` and `com.secretdj.kiosk`, yet the kiosk's Ad Hoc configuration sets `PRODUCT_BUNDLE_IDENTIFIER = com.c-burn.kiosk` (`project.pbxproj`) — by code-reading, an Ad Hoc kiosk build crashes at first `isKiosk` access (inferred, not run).
3. **`exit(0)` as a control-flow tool** in the `?RESTART?` reset (see above) — keep the capability, not the mechanism.
4. **Skin assets addressed by magic numeric ids** written as loose files (`00001@2x`, `01004.txt`) in Documents (`SkinManager.filePath(forRemoteURL:)` even slices the last 5 characters of the URL filename to derive the id) — fragile contract; the rewrite should get a typed skin manifest.
5. **Polling + notification spaghetti**: 20 s now-playing polling, `NotificationCenter` names as strings on `AppConfiguration`, and a `UIApplication.sendEvent` override for activity detection; modern equivalents (async streams, `UIGestureRecognizer` on the window, or scene-level event handling) are cleaner.
6. The "Cannot override with a stored property" workaround duplicated verbatim in four kiosk feed VCs (`KioskMusicSelectionFeedViewController`, `KioskSearchSongViewController`, `KioskSearchArtistListViewController`, `KioskSearchArtistDetailViewController` — each carrying the same "ChatGPT suggests this workaround" comment block) — a symptom of subclass-based feed VC design.
7. Dead weight: unused `secondsUntilAttract` clamp, vestigial `UIMainStoryboardFile`, dead `Kiosk_iPad.storyboard` in Resources, sign-up scenes in `KioskLogin.storyboard`, kiosk top-up resubmission, `Fabric` keys still in `SecretDJKiosk-Info.plist`, and `NSAllowsArbitraryLoads = true`.

## Backend API and Spotify integration

### Overview

Both apps talk to a single proprietary backend ("the Secret DJ API") through a small hand-rolled networking stack, plus a set of third-party services: Spotify (OAuth + Web API), the iTunes Search API (via a Tradedoubler affiliate wrapper), YouTube (deep links only), Facebook (login + Graph), Apple (Sign in with Apple, StoreKit IAP), and Firebase (Analytics/Crashlytics). There is **no environment switching anywhere** — one hardcoded production base URL, no staging/dev configuration (`secretdjv3/NetworkAccess.swift:62` is the only definition; a repo-wide grep finds no `api3`/staging variants).

### 1. The core networking stack

Four files implement the entire transport layer; every `*APIAccess` class composes them:

| File | Role |
|---|---|
| `secretdjv3/NetworkAccess.swift` | URLSession wrapper; builds/signs requests, one retry, token rotation |
| `secretdjv3/NetworkRequestConfiguration.swift` | Value type: endpoint enum + `[String: String]` params + completion (+ optional `UIImage` for uploads) |
| `secretdjv3/NetworkingParameterProvider.swift` | Endpoint path enum, implicit query params, custom URL-encoding |
| `secretdjv3/NetworkResponseParser.swift` | JSON envelope parsing (`Success` / `Message` / `Token`) |
| `secretdjv3/PostRequestProvider.swift` | Multipart form bodies for the two POST endpoints |

**Base URL:** `https://api4.secretdj.com/` (`secretdjv3/NetworkAccess.swift:62`). Endpoint = base URL + raw value of `NetworkRequestType` (e.g. `https://api4.secretdj.com/signin`). Almost everything is a **GET with query parameters**, including sign-in (the SHA-1-hashed password travels in the query string). Only two endpoints POST (multipart/form-data): `newavatar` (avatar JPEG upload) and `topupnotify` (IAP receipt verification) — see `NetworkAccess.generateRequest` (`secretdjv3/NetworkAccess.swift:164-172`) and `secretdjv3/PostRequestProvider.swift`.

**Session config** (`secretdjv3/NetworkAccess.swift:71-86`): 30 s timeout (`AppConfiguration.shared.networkTimeout`), headers `Accept: application/json`, `Accept-Language: en`, `Accept-Encoding: gzip`, and a **structured User-Agent the server appears to rely on**: `"secret dj <identifierForVendor>:<screenWidthPx>:<appVersionWithoutDots>"`. This is effectively a device-identification side channel — treat it as part of the API contract until proven otherwise.

**Implicit query parameters** added to every request (`secretdjv3/NetworkingParameterProvider.swift:81-102`):
- `appmask` — bitmask of companion apps installed on the device, detected by URL-scheme probing: facebook=1, twitter=2, uber=4, instagram=8 (`secretdjv3/URLSchemeHandler.swift`). The server uses it to decide which action buttons to send back (inferred from `ActionType.launchUberApp` etc. in `secretdjv3/Action.swift:40-52`).
- `coords` — `"%.6f,%.6f"` lat,lng when a location fix exists.
- `appmodel=1` — kiosk builds only (`AppConfiguration.isKiosk` keys off bundle id: `com.c-burn.secretdj` = phone, `com.secretdj.kiosk` = kiosk, `secretdjv3/AppConfiguration.swift:121-132`).

**Custom URL encoding:** the server needs more percent-escaping than Apple's default; `customEncodedURL` re-encodes query values with an AFNetworking-compatible character set (escaping `:#[]@!$&'()*+,;=`) (`secretdjv3/NetworkingParameterProvider.swift:54-113`).

#### Auth scheme: rotating token + HMAC signature

This is the most important contract to preserve:

1. **Credential = SHA-1 of the password**, produced client-side (`password.sha1()` in `secretdjv3/LoginAPIAccess.swift:128,167`; `secretdjv3/String+Crypto.swift`). For Facebook/Apple sign-in the server *returns* the credential in the `Param` field of the response, and the client stores it as the "password" (`secretdjv3/LoginAPIAccess.swift:251,281`). The credential is stored in the **Keychain** (`UserManager.password` → `KeychainPasswordItem`, `secretdjv3/UserManager.swift:145-163`).
2. **Token**: every API response may carry a `Token` field; when present and non-empty the client overwrites its stored token (`secretdjv3/NetworkAccess.swift:140-142`). The token is stored in **UserDefaults** with a hardcoded bootstrap default `"oPizteXKUJQfSLuqxRtzihMbYYo="` (`UserManager.cryptographicNonce` / `initDefaults`, `secretdjv3/UserManager.swift:49,61`).
3. **Signature**: every request except `signin`, `createuser`, `facebooksignin`, `applesignin`, `resetpassword` gets a `sig` query param = `base64(HMAC-SHA1(base64decode(token), key: password))` (`secretdjv3/SignatureProvider.swift:38-48`, HMAC in `secretdjv3/Hmac.swift`; the exclusion list is at `secretdjv3/NetworkAccess.swift:209`). The signature is memoised per token+password pair.

So this is a challenge–response scheme: server rotates the token; the client proves possession of the password hash by signing the latest token. There are no HTTP auth headers, no cookies, no OAuth for the first-party API.

#### Response envelope and retry

All Secret DJ responses are JSON dictionaries with PascalCase keys: top level `Success` (Bool), `Message` (String), optional `Token`, and either `Sections` (feed payloads parsed by `secretdjv3/SectionList.swift`) or `Response` (action payloads with `Text`, `Url`, `Data` (rich toast), `ReturnCode`) (`secretdjv3/NetworkResponseParser.swift`, and the parsers in each `*APIAccess`). On `Success == false` the request is retried **once** with the (possibly rotated) token before failing with `NetworkError.serverError(Message)` (`secretdjv3/NetworkAccess.swift:144-160`, `maxRetryCount = 1`). `NetworkError` cases live at `secretdjv3/NetworkAccess.swift:11-42`. Two NotificationCenter notifications (`NetworkTaskCreated`/`NetworkTaskCompleted`) drive a global activity indicator (`secretdjv3/AppConfiguration.swift:110-113`, `secretdjv3/NetworkActivityManager.swift`).

### 2. Endpoint catalog

All paths from `NetworkRequestType` (`secretdjv3/NetworkingParameterProvider.swift:11-48`), with the caller that defines the request/response shape:

| Path | Caller | Request params (besides implicit + `sig`) | Response notes |
|---|---|---|---|
| `signin` | `secretdjv3/LoginAPIAccess.swift` | `screenname`, `password` (sha1) | `User` (id); optional `Venues.Force` = venue id to force-join |
| `createuser` | LoginAPIAccess | `firstname`,`lastname`,`gender`,`email`,`screenname`,`password` (sha1) | `User` id |
| `facebooksignin` | LoginAPIAccess | `fbid`, `state` (FB access token), `gender`,`firstname`,`lastname`,`email`, `auth` | `User`, `Param` (server-issued credential), `ScreenName`, `Created` |
| `applesignin` | LoginAPIAccess | `appuid`, `auth`, optional name/email on first sign-in | same as facebook |
| `resetpassword` | `secretdjv3/PasswordAPIAccess.swift` | `screenname` **or** `email` | `ReturnCode` == 0 + `Message` |
| `userdetails` | `secretdjv3/UserDetailsAPIAccess.swift` | `user` | SectionList with hidden `hiddenUserDetails` section → `Person` |
| `setuserdetails` | UserDetailsAPIAccess | `user` + any of `firstname`,`lastname`,`screenname`,`email`,`gender`,`password` | `ReturnCode` == 0 |
| `checkunique` | *defined but no Swift caller found* | — | screen-name uniqueness check; likely dead or pre-dates the Swift port |
| `newavatar` (POST multipart) | `secretdjv3/AvatarAPIAccess.swift` | `user` + JPEG part `avatarfile`/`avatar.jpg` (0.9 quality, max 1024²) | `Response.Text` toast |
| `requestdeleteaccount` | `secretdjv3/RequestDeleteAccountAPIAccess.swift` | `user` | `Success` + `Message` |
| `placesnearby`, `eventhistory` (activity), `newsfeed`, `venuedetails`, `persondetails`, `playhistory` (now playing) | `secretdjv3/FeedAPIAccess.swift` | `user`, plus `venue` or `person` as relevant | SectionList feed |
| `extracontent` | FeedAPIAccess | `user`, `screenid` (1=placesNearby, 2=venueDetails), optional `venue` | SectionList |
| `promote` | FeedAPIAccess `promotionEngaged` | `user`,`venue`,`id` | fire-and-forget |
| `checkin` | `secretdjv3/CheckInAPIAccess.swift` | `user`,`venue`,`scope` (0=friends,1=everyone,2=incognito) | `Sections[0].Custom.Response.{Text,Url,Data}` |
| `like` / `unlike` | `secretdjv3/LikeAPIAccess.swift` | `user`,`item`,`type` (bitmask: song=0x2, venue=0x2000_0000, person=0x4000_0000, event=0x8000_0000), optional `venue` | `Response.{Text,Url,LikeInfo.LikedByYou}` |
| `requestsong` | `secretdjv3/SelectSongAPIAccess.swift` | `user`,`venue`,`songid` | `ReturnCode` 0=queued, **-8 = out of credits** (`WSRX_ERROR_REQUEST_NO_CREDITS`); `ImageSize` tells whether the user has an avatar (drives the "free credit for profile pic" upsell) |
| `musicsearch` | `secretdjv3/SearchAPIAccess.swift` | `user`,`venue`,`q`,`type` (2=songs, 8=artists), `searchmask` (1=compute likes) | SectionList |
| `artistsavailable` | SearchAPIAccess | `user`,`venue`, optional `hash` | flat `Artists` array + `TopupAllowed`; client groups A–D/E–H/… locally |
| `musicselection`, `musicdigest` | `secretdjv3/MusicAPIAccess.swift` | `user`,`venue`,`offset`,`numentries`,`item`,`type` (Int64 bitmask), optional `hash` | paged SectionList; last section's `Custom.Hash` is an ETag-style change token |
| `styleinfo` | `secretdjv3/MachineControlAPIAccess.swift` | `user`,`venue`,`offset`,`numentries`,`item`, optional `hash` | jukebox/genre catalogue + `Hash` |
| `machinecontrol` | MachineControlAPIAccess | `user`,`venue`,`action` (400=change atmosphere, 401=skip song, 402=blacklist; see `secretdjv3/Action.swift:40-52`), `item`, `value` (minutes for mood; 0 otherwise) | `Response.ReturnCode`==0 + `Text`. Used by the kiosk *and* the phone's change-mood feature (`secretdjv3/ChangeMoodFeedViewController.swift`, `secretdjv3/TuneInViewController.swift`) |
| `skinresources` | `secretdjv3/SkinAPIAccess.swift` | `user`,`venue` | `Response.Images` + `Response.Properties`; client then bulk-downloads asset URLs with a delegate-based `URLSession` (HEAD requests to size the batch). Note: its error-path delegate is **commented out since 2020** (`secretdjv3/SkinAPIAccess.swift:156-167`) |
| `topupdetails` | `secretdjv3/TopUpAPIAccess.swift` | `user`,`context` (0=insert coin,1=no credits),`vendor`, optional `venue` | SectionList of `TopUp` products (SKU, price, NumCredits — `secretdjv3/TopUp.swift`) |
| `topupnotify` (POST multipart) | TopUpAPIAccess `verifyTransaction` | `user`,`vendor` (2 = Apple App Store),`action` (1=paymentReceived,2=purchaseRestored),`uid`,`info` = **base64 App Store receipt** (`secretdjv3/IAPManager.swift:324-341`) | `ReturnCode`: 0=credited, 1=already processed, <0=retryable |
| `redeemjukeboxvoucher` | TopUpAPIAccess | `user`,`code`, optional `venue` | `ReturnCode`==0 + `Text` |
| `numpaidcredits` | TopUpAPIAccess | `user` | `Response.Text` (count as display string) |
| `spotisave` | `secretdjv3/SpotifyAPIAccess.swift` | `user`,`item` (song id), optional `venue` | `Response.{Text,Url,ReturnCode}`; client verifies `ReturnCode == md5("<userId><songId>spotify")` before proceeding — a home-grown anti-tamper check (`secretdjv3/SpotifyAPIAccess.swift:85-95`) |
| `spotifyevent` | SpotifyAPIAccess `logSpotifyEvent` | `user`,`item`,`type` (1=saveToPlaylist, 2=listenInApp), optional `venue` | fire-and-forget metrics |
| `watchonyoutube` | `secretdjv3/YouTubeApiAccess.swift` | `user`, `item` = **signed song id** `"<songId>_<sha1(songId + (dayOfYear-1) + salt)>"` (salt in `secretdjv3/SongSigGenerator.swift:13`), optional `venue` | `Response.YouTubeId` or title/artist fields to build a search query |

**Day-of-year auth digests:** both social sign-ins and `watchonyoutube` use the same peculiar pattern — `sha1(<id> + (dayInYear − 1) + <hardcoded salt>)`, with salts `a23167ehxwxzf9Fd4` (Facebook) and `a199eb60aad211ea` (Apple) in `secretdjv3/LoginAPIAccess.swift:41-42,303-321`. Note the "DDD" DateFormatter and `ordinality(of:.day)` are timezone-sensitive and will disagree with the server around midnight/DST — a known-fragile contract to renegotiate in the rewrite.

The networking layer has real unit coverage worth mining for contract fixtures: `SecretDJTests/NetworkAccessTests.swift`, `SecretDJTests/SignatureProviderTests.swift`, per-endpoint `*APIAccessTests.swift`, and recorded JSON responses (`SecretDJTests/RequestSong.json`, `ChangeMood.json`, `SecretDJTests/JSON/`).

### 3. Spotify integration

Consumer-app feature: from a song's "listen" bottom sheet (`secretdjv3/ListenToSong/ListenToSong.swift`) the user can open a track in the Spotify app/web, or save it to a "Secret DJ" playlist in their own Spotify account. There is **no Spotify search, no preview streaming, no in-app playback via Spotify** — 30-second previews come from Secret DJ's own S3 (below), and the jukebox audio plays on venue hardware, not the phone.

#### PKCE OAuth (`secretdjv3/SpotifyAuthManager.swift`)

Replaced the vendored `Spotify.framework` (`SPTAuth`/`SPTAuthViewController`) in commit `d7fb6445` because the fat binary had no arm64-simulator slice. Current flow:

- Authorize: `https://accounts.spotify.com/authorize` via `ASWebAuthenticationSession`, `response_type=code`, `code_challenge_method=S256`, random 64-byte verifier, `state` check on callback.
- Client id `1dd5cb9e818542fea53550cbf3029b1d`, redirect `secretdj://spotify-login-callback` (`SpotifyConfig`, `secretdjv3/AppConfiguration.swift:96-99`; the `secretdj` scheme is registered in `SecretDJ-Info.plist:28-32` — the kiosk plist does not register it, so kiosk builds cannot complete this flow).
- Scopes: `playlist-modify-public playlist-modify-private` only.
- Token exchange/refresh: POST `https://accounts.spotify.com/api/token` (form-encoded, no client secret — PKCE). Access token, refresh token, and expiry (with a 60 s safety margin) are stored in the **Keychain** under service `com.secretdj.spotify`.
- `getAccessToken(presentingFrom:)` is the single entry point: cached → silent refresh → interactive login. A 401 from the Web API clears the session so the next attempt re-authenticates (`secretdjv3/SpotifyAccess.swift:63-67`).

#### Web API client (`secretdjv3/SpotifyAPI.swift`)

Minimal URLSession + Codable + async/await client (replaced the Spartan CocoaPod in commit `0fb3d356`, which also removed the last CocoaPods dependency). Base `https://api.spotify.com/v1`, `Authorization: Bearer <token>`. Exactly the endpoints the app uses: `GET /me`, `GET /tracks/{id}`, `GET /me/playlists`, `GET /playlists/{id}/tracks`, `POST /users/{id}/playlists`, `POST /playlists/{id}/tracks`, plus a generic paginator that follows `next` URLs.

#### Save-to-playlist business logic (`secretdjv3/SpotifyAccess.swift:74-116`)

1. First the app calls the **Secret DJ backend** `spotisave` and only proceeds if the md5 check passes (`secretdjv3/ListenToSong/ListenToSong.swift:118-123`).
2. Then, against Spotify: validate the track exists → `getMe` → find a playlist named **"Secret DJ"** (case-insensitive, paginated search of all user playlists) or create it → skip with a "already in playlist" toast if the track URI is present → append. Track ids tolerate both `spotify:track:X` URIs and bare ids (`lastIDComponent`).

"Open in Spotify" builds either `https://open.spotify.com/track/<id>` (app not installed) or a `https://spotify.link/content_linking?...` Branch-style deep link (installed) (`secretdjv3/SpotifyAccess.swift:152-174`).

#### Heroku_SpotifyTokenSwap

`Heroku_SpotifyTokenSwap/` at the repo root is an **empty directory backed by a git submodule gitlink** (mode 160000, commit `a1729015`, added in commit `1cc12672` "Fix for bug: Fixing Save To Spotify", 2024-04-09). There is **no `.gitmodules` file**, so the submodule cannot even be cloned from this repo — its remote URL is lost. It held the server-side token-swap/refresh service that the pre-PKCE `SPTAuth` flow required (a small web service holding the Spotify client secret, deployed at `https://obscure-sea-1305.herokuapp.com/swap` and `/refresh`). The only remaining references are two dead `#define`s — `kSpotifyTokenSwapServiceURL` / `kSpotifyTokenRefreshServiceURL` in `secretdjv3/CommonConstants.h:198-199`, alongside an equally dead old client id `9a5c3f463e9341b9a92f8dbe7c4a6dc0` and callback `sdjspotifycallback://` (`secretdjv3/CommonConstants.h:194-200`) that no Swift/ObjC code consumes. PKCE removed the need for the service entirely; **do not carry any of it forward** (and note Heroku's free dynos were retired — the URL is almost certainly dead anyway; inferred).

### 4. Other third-party integrations

- **iTunes Search / Apple Music** (`secretdjv3/ITunesAPIAccess.swift`): "Listen on Apple Music" queries `http://itunes.apple.com/search?entity=musicTrack&limit=1&country=gb&partnerId=2003&term=<artist>+<title>` and wraps the resulting `trackViewUrl` in a **Tradedoubler affiliate redirect** `http://clkuk.tradedoubler.com/click?p=23708&a=1877127&url=...`. Both URLs are seeded at launch (`secretdjv3/AppDelegate.swift:47-48`, `secretdjv3/KioskAppDelegate.swift:28-29`) but are **server-overridable**: feed sections can carry a `Custom.Store` dictionary (`SearchUrl`, `PageUrlPrefix`, `PageUrlSuffix`) that overwrites the stored values (`secretdjv3/Section.swift:36-43`, `secretdjv3/UserManager.swift:305-312`). Note both are plain `http:` — they work only because ATS is fully disabled.
- **YouTube** (`secretdjv3/ListenToSong/ListenToSong.swift:174-240`): no API calls; opens `youtube://` deep links or `https://www.youtube.com/watch?v=`/`results?search_query=` with the id/query supplied by the backend's `watchonyoutube` endpoint.
- **Facebook**: SPM `facebook-ios-sdk` (`secretdj.xcodeproj/project.pbxproj:4851-4853`); login + `GraphRequest(graphPath: "me", fields: gender, first_name, last_name, email)` (`secretdjv3/FacebookManager.swift:79`), feeding `facebooksignin`. App id `144876722233890` (`secretdjv3/CommonConstants.h:104`, URL scheme `fb144876722233890` in both Info.plists).
- **Firebase** (Analytics + Crashlytics; SPM `firebase-ios-sdk`): separate `GoogleService-Info.plist` per target in `secretdjv3/Firebase/phone/` and `secretdjv3/Firebase/kiosk/`; every `*APIAccess` fires an analytics event through `secretdjv3/Reporting.swift` (covered by the observability section).
- **Apple StoreKit** (`secretdjv3/IAPManager.swift`): consumable credit top-ups; receipt goes to `topupnotify` as base64. `TopUpManager.vendor()` is hardcoded to `.appleAppStore` (`secretdjv3/TopUpManager.swift:55`).
- **PayPal — dead**: `secretdjv3/PayPalManager.swift` (old PayPalMobile SDK) is fenced behind `#if PAYPAL_SUPPORTED` and is **not a member of any target** (zero references in `project.pbxproj`); `Vendor.payPal = 3` is commented out (`secretdjv3/TopUp.swift:15`). Live client ids for prod/sandbox still sit in `secretdjv3/AppConfiguration.swift:101-104` and `secretdjv3/CommonConstants.h:77-79`. Do not carry forward.
- **Twitter — dead**: consumer key/secret pair still hardcoded at `secretdjv3/CommonConstants.h:107-108` with no consuming code found.

### 5. Full host inventory

| Host | Protocol | Purpose | Evidence |
|---|---|---|---|
| `api4.secretdj.com` | HTTPS GET/POST | entire first-party API | `secretdjv3/NetworkAccess.swift:62` |
| `secretdj.s3.amazonaws.com` | HTTPS | all imagery, by convention `<base>/<category>/<file>`: `newsimages/`, `venues/`, `useravatars/`, `promotions/`, `albumcovers/`, `songcovers/`, `jukeboxes/`, `actions/`, `genres/`, `products/` | `secretdjv3/ItemImage.swift:118-141`, `secretdjv3/CommonConstants.h:131-163` |
| `s3.amazonaws.com/secretdj/defaultimages/...` | HTTPS | default social icons | `secretdjv3/CommonConstants.h:183-184` |
| *(S3, via server-supplied absolute URLs)* | HTTPS | 30 s song previews — `Song.previewURL` from the `Preview` field (`secretdjv3/Song.swift:42`); served with a custom `.pbz` extension and generic Content-Type, so the app downloads bytes and decodes with `AVAudioPlayer` (`secretdjv3/TuneInViewController.swift:633-676`) |
| `www.secretdj.com` | HTTP | terms & conditions webview | `secretdjv3/AvailableTopUpsViewController.swift:332` |
| `accounts.spotify.com`, `api.spotify.com`, `open.spotify.com`, `spotify.link` | HTTPS | OAuth, Web API, deep links | `secretdjv3/SpotifyAuthManager.swift:26-27`, `secretdjv3/SpotifyAPI.swift:51`, `secretdjv3/SpotifyAccess.swift:158-166` |
| `itunes.apple.com` | **HTTP** | music-track search | `secretdjv3/AppDelegate.swift:47` |
| `clkuk.tradedoubler.com` | **HTTP** | affiliate click wrapper | `secretdjv3/AppDelegate.swift:48` |
| `www.youtube.com` / `youtube://` | HTTPS/scheme | watch/search deep links | `secretdjv3/ListenToSong/ListenToSong.swift:177-199` |
| `maps.google.com` | HTTP | venue directions link | `secretdjv3/DirectionsMessageProvider.swift:32` |
| Facebook Graph (via SDK), Firebase (via SDK) | HTTPS | login/analytics/crash | `secretdjv3/FacebookManager.swift`, `secretdjv3/Firebase/` |
| `obscure-sea-1305.herokuapp.com` | — | **dead** legacy Spotify token swap | `secretdjv3/CommonConstants.h:198-199` |
| `akamaihd.net` | — | ATS exception in the kiosk plist only; no code references it (inferred: legacy Spotify streaming CDN) | `SecretDJKiosk-Info.plist:67-75` |

### 6. Tech debt NOT to carry forward

- **ATS is globally disabled in both apps** (`NSAllowsArbitraryLoads = true`, `SecretDJ-Info.plist:73-77`, `SecretDJKiosk-Info.plist:63-66`), needed today because iTunes/Tradedoubler/T&C/maps URLs are plain HTTP. The rewrite should use HTTPS everywhere and drop the exception.
- **Credentials in query strings**: sign-in/sign-up send `password` (sha1) as GET query parameters — they end up in server/proxy logs. The whole GET-with-sig scheme deserves a redesign (or at minimum POST bodies + TLS-only).
- **SHA-1/MD5 everywhere**: password hashing (unsalted SHA-1), request signing (HMAC-SHA1), `spotisave` verification (MD5), day-of-year salted digests. All weak; all timezone-fragile where day-of-year is involved.
- **Auth token in UserDefaults** (only the password lives in the Keychain) and a hardcoded bootstrap nonce (`secretdjv3/UserManager.swift:49,61`).
- **Secrets committed to source**: PayPal prod/sandbox client ids, Twitter consumer secret, Facebook app id, Spotify client id, the song-sig and social-login salts (`secretdjv3/AppConfiguration.swift`, `secretdjv3/CommonConstants.h`, `secretdjv3/SongSigGenerator.swift`, `secretdjv3/LoginAPIAccess.swift`).
- **Dead code/config**: PayPalManager (not in any target), Twitter keys, old Spotify constants + orphaned Heroku submodule gitlink, `checkunique` endpoint with no caller, SkinAPIAccess's commented-out error handling ("TODO: put back in… Adam 10/10/20", `secretdjv3/SkinAPIAccess.swift:158-166`), `IAPManager.swift-old.swift` at the repo root.
- **Stringly-typed transport**: every request is `[String: String]`, every response `[AnyHashable: Any]` with hand-parsing per endpoint; the two newest files (`SpotifyAPI.swift`, `SpotifyAuthManager.swift`) show the Codable + async/await style the rewrite should generalise.
- Callback-based `*APIAccess` classes are `NSObject` subclasses with ad-hoc `parseQueue` DispatchQueues and `[weak self]` boilerplate; retry duplicates work rather than replaying idempotently.

## Domain model and persistence

### The one domain abstraction: a server-driven feed of Sections and Items

Almost everything both apps display is a **feed**: the server returns a JSON dictionary that `secretdjv3/SectionList.swift` parses into `Section`s containing `Item`s. There is no client-side domain schema independent of this — the concrete type of every item is chosen by the server via a `Template` id, and most business data rides along inside untyped `[AnyHashable: Any]` dictionaries. The rewrite team should treat this as the real contract:

- `SectionList` (`secretdjv3/SectionList.swift`) — top-level response wrapper: `Success`, `Token` (rotating auth token), `Hash` (feed checksum), `Actions`, and a `Sections` array. Each raw section becomes a `Section` and is routed into **visible** (`sortedSections`, sorted by `Index`, empty sections dropped) or **hidden** (`hiddenSections`) lists based on its template. If no visible section survives, a dummy empty section is fabricated "so that at least the header shows" (`SectionList.swift:127-132`).
- `Section` (`secretdjv3/Section.swift`) — has `itemType` (`ItemType` bitmask), `title`, `index`, a free-form `custom` dictionary, an optional `Store` (iTunes affiliate config: `SearchUrl`/`PageUrlPrefix`/`PageUrlSuffix`), and `items`. `Section.parseItem` is the **template → concrete class dispatch table**: award/check-in/venue templates → `Venue`; song templates → `Song`; person/VIP/profile templates → `Person`; promotion/advert → `Promotion`; `newsItem` → `News`; `topUp` → `TopUp`; jukebox templates → `Jukebox`; `matrixControlLarge` → `Control`; `artist` → `Artist`. Horizontal/matrix templates get wrapped in a nested "container" `Section` so the UIKit feed can render a carousel inside a row.
- `Template` (`secretdjv3/AppConfiguration.swift:11-49`) — ~35 raw-int template ids. Note the `hidden*` templates: **hidden sections are data channels, not UI** — `hiddenUserDetails` carries the signed-in user's full `Person` (email/first/last name, parsed in `secretdjv3/UserDetailsAPIAccess.swift:165-171`), `hiddenVenueDetails` carries the authoritative `Venue` for a venue screen (`secretdjv3/VenueFeedViewController.swift:45-59`), `hiddenJukeboxList` the jukebox menu (`secretdjv3/JukeboxMenuViewController.swift:154`), `hiddenExtraContentSong` the rotating "now playing" banner content (`secretdjv3/ExtraContentManager.swift`).
- `ItemType` (`secretdjv3/ItemImage.swift:36-52`) — server-side type bitmask (`song = 2`, `venue = 0x2000_0000`, `person = 0x4000_0000`, `event = 0x8000_0000`…), used both to pick S3 image buckets and as the `type` parameter for like calls (`secretdjv3/LikeAPIAccess.swift:11-16` re-declares the same masks as `LikeType`).

#### Class hierarchy and the types themselves

The hierarchy is `NSObject` → `ItemImage` → `Item` → concrete types (all classes, all built from dictionaries):

- **`ItemImage`** (`secretdjv3/ItemImage.swift`) — every item's image metadata: `imageURI`, `imageSize`, a `resolutions` OptionSet of available sizes, and `imageItemType` which maps to hard-coded S3 base URLs (`https://secretdj.s3.amazonaws.com/{albumcovers,songcovers,newsimages,venues,useravatars,promotions,jukeboxes,genres,products,actions}/`, `ItemImage.swift:117-144`). Image URL building includes a resolution-fallback chain and per-device logic keyed off literal screen heights (iPhone 4/5/6/6 Plus, `ItemImage.swift:183-234`) — domain-relevant only in that the server offers multiple resolutions per image and the final URL is `{base}/{resolution}/{uri}?{size}`.
- **`Item`** (`secretdjv3/Item.swift`) — adds `text` (pre-formatted, newline-separated display text — the server formats strings, clients split on `\n`), `sortIndex`, a primary `action` plus `actions` array (`secretdjv3/Action.swift`: `ActionType` ids drive navigation — `showTopup = 1`, `launchSearch = 200`, `jukeboxGotoItem = 300`, `jukeboxChangeAtmosphere = 400`, `jukeboxSkipSong = 401`, `jukeboxBlacklistSong = 402`, `jukeboxRequestSong = 403`, `gotoURL = 500`), a weak `parentSection` back-reference, and `base64Dictionary` — the item's **entire raw JSON re-serialized and base64-encoded at parse time**, kept solely as an identity token (see equality below).
- **`Person`** (`secretdjv3/Person.swift`) — `personId`, `screenName` (mutable), `gender` (`secretdjv3/Gender.swift`: unisex/female/male ints), `likedByYou` (mutable), `likeInfo`. `email`/`firstName`/`lastName` are *not* on the item payload — they are pulled from `parentSection.custom`, i.e. only populated when the Person arrived inside a `hiddenUserDetails` section. Profile-header stats (`placesVisited`, `songRequests`, `peopleWhoLikeUser`, `lastVenue`/`lastZone`) are read live from `parentSection.custom["Interactions"]` (`Person.swift:146-174`).
- **`Venue`** (`secretdjv3/Venue.swift`) — `venueId`, `venueName`, `venueAddress`, `telephone`, lat/lng, `zoneName`, `venuePromotionURL`, `likeInfo`, plus three **session-only flags**: `checkedIn`, `likedByYou`, `machineControl` (an `Int > 0` in JSON; gates the kiosk-style controls — change mood / skip / blacklist — in `secretdjv3/TuneInViewController.swift`). `VenueProperties` OptionSet (`reportsPlayHistory`, `vpHasJukebox`) comes from a `Properties` bitmask. **There is no Award class**: award templates (`award`, `horizontalAward`, `matrixAward*`) are parsed as `Venue` objects (`Section.swift:177-184`) and rendered image-first (`secretdjv3/AwardCollectionViewCell.swift` is an empty subclass) — awards are effectively "venue-shaped items with a badge image".
- **`Song`** (`secretdjv3/Song.swift`) — `songId`, `title`, `artist`, `previewURL` (30s preview), `spotifyURI`, `likedByYou`, `likeInfo`. Invariant: **`songId == "0"` means "intermission"** (nothing playing) — `isIntermission` gates request/tune-in actions (`secretdjv3/FeedActionProvider.swift:221`, `secretdjv3/KioskFeedActionProvider.swift:35`, `secretdjv3/KioskNowPlayingViewController.swift:261`; the magic value is also `AppConfiguration.intermissionSongId`).
- **`Artist`** (`secretdjv3/Artist.swift`) — `name`, `artist`, `numSongs`; display text is synthesized client-side (`"\(artist) ..."` when `numSongs > 1`).
- **`Jukebox`** (`secretdjv3/Jukebox.swift`) — `jukeboxId: Int`, its own `itemType` (a jukebox menu entry can be a genre, album, etc.), `textColour` hex, `subtitle`. A "jukebox" here is a browsable music collection within a venue, not the physical player.
- **`TopUp`** (`secretdjv3/TopUp.swift`) — a purchasable credit bundle: `sku`, `numCredits`, `price`/`displayPrice`/`currencyCode`, `url`, `vendorId`. Display rule: server text + display price, but when Apple IAP is active the App Store's localized price replaces the server one (`updateDisplayPrice(storePrice:)`). **Bug worth not carrying**: `data?["VendorId"] as? Vendor` (`TopUp.swift:35`) casts a JSON number to a Swift enum, which always fails, so `vendorId` is always `.unknown`; the app compensates by hard-coding `TopUpManager.vendor() -> .appleAppStore` (`secretdjv3/TopUpManager.swift:55`).
- **`News`**, **`Promotion`**, **`Control`** (`secretdjv3/News.swift`, `secretdjv3/Promotion.swift`, `secretdjv3/Control.swift`) — id + URL payloads; `Promotion` adds `externalBrowser` (open in Safari vs in-app web view) and `promotionHeight` (server-controlled cell height); `Control` is a colored action tile (fg/bg hex colours) whose `actionItemId` feeds the mood/machine-control API.

#### Identity, equality, mutability conventions

- Equality is `NSObject.isEqual` overrides, inconsistent per type: `Song` by `songId`; `News` by `newsItemId`; `Promotion` by `promotionId`; `Venue` by `venueId` **AND** display `text` AND `machineControl` (`Venue.swift:171-181` — deliberately treats a re-rendered venue as "changed"); `Item` (and therefore `Person`, `Artist`, `Jukebox`, `TopUp`, `Control`, which don't override) by byte-equality of `base64Dictionary`, i.e. *any* payload change is a new identity. `FeedUpdater` (`secretdjv3/FeedUpdater.swift`) diffs successive `SectionList`s with these semantics to drive collection-view batch updates, and the new SwiftUI feed engine reuses `base64Dictionary` as its `Identifiable` id (`secretdjv3/SwiftUI/Feed/FeedViewStateBuilder.swift:280-288`, documented in `secretdjv3/SwiftUI/Feed/FeedViewState.swift`). A rewrite needs a deliberate identity story per type; today's is an accident of rendering.
- Mutability: models are mostly `let` with a handful of session-mutable fields (`likedByYou`, `checkedIn`, `Person.screenName`, `Item.text`, `Section.items`). Like toggles mutate the in-memory item after a `LikeAPIAccess` call; nothing is written back to disk.
- `Section` couples the model layer to singletons (`var userManager = UserManager.shared`, `let appConfig = AppConfiguration.shared`, `Section.swift:24-25`) and parsing behavior differs by target (`isKiosk` checks inside `parseItems`/`SectionList`).

### Where state lives

There is **no Core Data / SQLite / SwiftData anywhere**. Client-side persistent state is deliberately thin; the server owns credits, likes, check-ins, play history, and profile data, which arrive fresh with every feed.

#### 1. UserDefaults via `UserManager` (`secretdjv3/UserManager.swift`)

`UserManager` is a singleton facade over `UserDefaults.standard` with an in-memory cache (`internalUser`/`internalVenue`, reset by `flushCachedValues()`). Keys are the `UserDefaultKey` enum (`UserManager.swift:12-38`). Registered launch defaults (`UserManager.swift:51-65`) include `keepSignedIn = true`, `socialMask = .facebook`, and — importantly — **`token` defaults to the hard-coded nonce `"oPizteXKUJQfSLuqxRtzihMbYYo="`** (also exposed as `cryptographicNonce`), which is what signs the very first pre-login requests.

**The Phase 0 Codable persistence (commit `89b96f7f`)** — the state the rewrite must keep reading:

- `currentUser` is a `Person` stored as **Codable JSON** under `currentUserJSON`; `currentVenue` a `Venue` under `currentVenueJSON`. The persisted subset is intentionally partial: Person persists only `{likedByYou, gender, likeInfo, screenName, personId}` (`Person.swift:94-126`); Venue persists identity/location/contact fields and **resets `checkedIn`/`likedByYou`/`machineControl` to false on every decode** — they are session state (`Venue.swift:126-155`).
- **Migration:** the getters first try the JSON key; if absent they unarchive the legacy `NSKeyedArchiver` blob under the old keys (`currentUser`, `currentVenueObject`), mapping the ObjC-era class names `SDJPerson`/`SDJVenue` (`UserManager.swift:77-127`), then re-save through the setter as JSON and delete the legacy blob — a one-shot lazy migration, covered by `SecretDJTests/UserManagerTests.swift:151-193`. `NSCoding` conformance is kept "for one release" per the comment in `Person.swift:88-92`.
- **Decode invariant:** a `Person` with empty `personId` or `screenName` fails to decode/unarchive (`Person.swift:102-108`, `Person.swift:137-139`, test at `UserManagerTests.swift:195-204`). There is also a last-resort recovery: if no stored user but the keychain has a password and a **raw `"userId"` defaults key** exists (written only by pre-Swift releases; no writer in this codebase), a skeleton `Person(screenName: "Unknown")` is fabricated (`UserManager.swift:89-94`).
- **Who persists a venue:** only the kiosk. `KioskLoginFlowController.swift:116` stores the venue the kiosk signed into (kiosk login returns a venue in `LoginDetails`, `secretdjv3/LoginAPIAccess.swift:25-30`, and auto-signs-in on next launch if both user and venue exist, `KioskLoginFlowController.swift:53`, `KioskSceneDelegate.swift:30`). The consumer app passes `Venue` objects around per session and never writes `currentVenue`.
- **Session/auth model:** `requiresLogin()` = no non-empty keychain password OR no stored `personId` (`UserManager.swift:362-369`). The password stored is `password.sha1()` (`secretdjv3/SDJLoginManager.swift:123`); the rotating server `Token` is persisted to defaults on **every** network response (`secretdjv3/NetworkAccess.swift:140-142`) and each request is signed `sig = HMAC-SHA1(base64decode(token), key: sha1Password)` (`secretdjv3/SignatureProvider.swift`). So "logged in" = keychain SHA-1 + defaults token + defaults Person.
- Other live keys: `gotFirstFixLocation` (timestamp of first GPS fix; throttles feed auto-refresh polling from 3s to 20s — `secretdjv3/LocationManager.swift:127-128`, `secretdjv3/FeedViewController.swift:160`, mirrored in `secretdjv3/SwiftUI/Feed/FeedScreenModel.swift:98`), `disableAutoLock` (maps to `isIdleTimerDisabled`, both scene delegates), `shouldReloadAssets` (set by kiosk search screens together with `URLCache.shared.removeAllCachedResponses()` to force skin/asset reload, `KioskSearchSongViewController.swift:146-148`), `searchURL`/`pageURLPrefix`/`pageURLSuffix` (iTunes affiliate config — **overwritten with hard-coded iTunes/TradeDoubler URLs on every launch** in `secretdjv3/AppDelegate.swift:47-48` and `KioskAppDelegate.swift:28-29`, then optionally updated from a feed's `Store` block via `UserManager.updateWith(sectionList:)`), `deleteAccountRequested` (a local kill switch: once the user requests account deletion, `secretdjv3/RequestDeleteAccountViewController.swift:86` sets it and `secretdjv3/CustomTabBarViewController.swift:90` shows a "requested" screen and exits on every launch), and Crashlytics user-id keys.
- **Dead/legacy keys** declared but with no live reader/writer: `scope`, `avatarURL`, `lastRefresh`, `jukeboxHash`, `spotifyUsername`, `spotifyCredential` (Spotify auth moved to its own keychain items — see below), plus the first-run block that writes *literal* keys `".firstRun"` and `".deleteAccountRequested"` (`UserManager.swift:286-295`) — the latter never read anywhere (the real property uses `"DeleteAccountRequested"`), an apparent bug/dead write.
- Kiosk also stores `idleTimeout` under a raw string key, sourced from the downloaded skin (`KioskLoginFlowController.swift:163-166`), read back via `SkinManager` rather than defaults (`KioskNowPlayingViewController.swift:320`).

**Pending IAP queue** (`secretdjv3/PendingTopUps.swift`): unverified in-app-purchase confirmations are a `[PendingTopUp]` (receipt `paymentData`, `topupUID`, `TopUpAction`, `sku`, `numSubmissions`, `timestamp`) **PropertyList-encoded under defaults key `"PendingTopUps"`**. Business rules worth preserving: append is idempotent per `topupUID`; on each startup/retry the *oldest* pending is resubmitted with `numSubmissions` incremented (`secretdjv3/TopUpManager.swift:133-156`); a pending entry is dropped after **5 submissions** (`maxSubmissions`, with an analytics error event on expiry) so one poisoned receipt can't block the queue; server-side "already processed" responses also remove the entry. Verification itself retries up to 3 times per attempt (`maxVerificationRetryAttempts`).

**SwiftUI migration flags** (`secretdjv3/SwiftUI/Core/FeatureFlags.swift`): per-screen kill switches; a defaults key `swiftui.<screen>` overrides the compiled default set (`settings`, `changeMood`, `musicSearch` currently on).

#### 2. Keychain

Three independent keychain stores:

- **Account password** — `secretdjv3/KeychainPasswordItem.swift`: a generic-password item matched **only** by `kSecAttrGeneric = "loginDetails"` (no service/account attributes — fragile query worth fixing in the rewrite). Stores the SHA-1 hash of the user's password (never the plaintext), which doubles as the HMAC signing key for every API call. Exposed as `UserManager.password` with an in-memory cache; note the getter deliberately returns `""` (not nil) when absent "to keep the networking layer consistent" (`UserManager.swift:145-163`).
- **Sign in with Apple** — `secretdjv3/KeychainAppleUserInfo.swift`: `AppleUserInfo` (appleUserId/first/last/email) JSON-encoded under service = bundle id, account `"aUserInfo"`. Deleted on first run after reinstall (`UserManager.swift:294`) so a fresh install re-prompts Apple.
- **Spotify OAuth (PKCE)** — `secretdjv3/SpotifyAuthManager.swift`: access token, refresh token and expiry stored as separate generic-password items under service `"com.secretdj.spotify"` (accounts `access_token`/`refresh_token`/`expires_at`). This replaced the old defaults-based `SpotifyUsername`/`SpotifyCredential` keys.

#### 3. Files on disk

- **Kiosk skins** — `secretdjv3/SkinManager.swift`: the kiosk downloads a per-venue skin (branding images, colours, strings, timeouts) into `Documents/skin_assets/`. Images are named by 5-digit asset id + `@2x` (the id is recovered by taking the **last 5 characters** of the remote filename, `SkinManager.swift:171-177`); text/colour properties are written as `<id>.txt`. `SkinAsset`/`SkinColor`/`SkinText` enums (`SkinManager.swift:14-77`) are the asset-id contract with the server (e.g. `idleTimeoutSeconds = 1004`, `attractURL = 1020`). Reads go through in-memory dictionaries as a cache; `deleteAllSkinAssets()` wipes the folder. Consumer-app sign-in also runs a (no-op-skin) download pass through the same path.

#### 4. Caches

- **HTTP/image cache** — both app delegates replace `URLCache.shared` with a 64 MB memory / 256 MB disk cache (`secretdjv3/AppDelegate.swift:68-71`, `KioskAppDelegate.swift:57-60`). All item images load through `UIImageView.loadImage` (`secretdjv3/UIImageView+LoadImage.swift`) with `.returnCacheDataElseLoad` and a 20 s timeout; cache-hit detection compares `Etag`/`Last-Modified` of response vs cached response purely to decide whether to fade in (fresh loads fade, cache hits don't). The SwiftUI `RemoteImage` (`secretdjv3/SwiftUI/Core/RemoteImage.swift`) deliberately reproduces these exact semantics instead of `AsyncImage`. Kiosk search screens nuke the whole URL cache to force-refresh assets.
- **In-memory only:** `SignatureProvider` memoizes the last (token, password) → signature; `SkinManager` caches images/properties; `UserManager` caches user/venue/password; paged feed providers keep `currentHash` per screen (below). `secretdjv3/Queue.swift` is a generic two-stack FIFO (used for toasts), not persistence.

#### Server-authoritative state and its client-side contracts

Worth restating for the re-model, because none of it is stored locally:

- **Credits** — never cached client-side. The song-request call returns `ReturnCode == -8` for "no credits" (`secretdjv3/SelectSongAPIAccess.swift:34,64-66`), and the same response's `ImageSize > 0` tells the client whether the user has a profile picture; if not, the app offers **profile-pic-for-credits** before showing top-ups (`secretdjv3/TuneInViewController.swift:520-537`). Restore-purchases shows the server's paid-credit count via `numpaidcredits` (`secretdjv3/TopUpAPIAccess.swift:282`). Kiosk users never run out of credits (`secretdjv3/KioskTuneInViewController.swift:192-193`).
- **Jukebox-change detection** — paged music feeds (`MusicSelectionFeedDataProvider`, `MusicDigestFeedDataProvider`, `MoodFeedDataProvider` in `secretdjv3/FeedDataProvider.swift`) carry an opaque per-feed `hash`; if a later page returns a different hash the provider fails with `.jukeboxChanged`, forcing a full reload (the pub changed the jukebox mid-scroll). The kiosk digest deliberately ignores this and just keeps updating (`FeedDataProvider.swift:566-577`).
- **Pagination state** — `currentOffset`/`batchSize` (server can override batch via `custom["Batch"]`) / `totalSongs` (from the last section's `custom["Total"]`), all in-memory per provider.
- **Likes** — optimistic per-item toggles via `LikeAPIAccess` with the `ItemType` bitmask; `likeInfo` display strings come pre-rendered from the server.

### Tech debt in this dimension worth NOT carrying forward

- Dictionary-typed parsing with silent defaulting everywhere (`as? T ?? fallback`), so malformed payloads produce empty-string ids rather than errors; the Codable layer added in Phase 0 shows the intended direction (validate identity, fail decode).
- `base64Dictionary` identity: every parsed item re-serializes its entire JSON payload (`Item.swift:67-72`) just to serve as an equality token — memory-heavy and semantically wrong for `Person` (any cosmetic payload change is a "different" person).
- Awards being `Venue` instances, and `Person` profile data living in `parentSection.custom` — both should become first-class types/fields.
- `TopUp.vendorId` enum-cast bug (always `.unknown`, `TopUp.swift:35`), papered over by hard-coding Apple as vendor.
- Optional-`Bool` properties (`disableAutoLock: Bool?` etc.) that encode tri-state where none exists, and `UserManager.shared` being `static var` (mutable global, `UserManager.swift:68`).
- Device detection by literal screen heights driving image-resolution choice (`ItemImage.swift:97-231`) — stale since the iPhone X era; the resolution ladder itself is the only part worth keeping.
- Dead artifacts: unused defaults keys (`scope`, `avatarURL`, `lastRefresh`, `jukeboxHash`, Spotify defaults keys), the dead first-run write to literal key `".deleteAccountRequested"` (`UserManager.swift:289`), unused `secretdjv3/Base64String.swift` (whose `Data.toBase64()` is mislabeled — it force-unwraps a UTF-8 decode), and `IAPManager.swift-old.swift` sitting at the repo root outside any target.
- Keychain password query keyed only by `kSecAttrGeneric` with global mutable query dictionaries at file scope (`KeychainPasswordItem.swift:11-13`).
- `userDefaults.synchronize()` calls (`saveChanges()`, `PendingTopUps.save`) — obsolete API.

## Audio and playback

### The single most important fact: the pub's music never plays on the device

Neither app streams full tracks. The actual jukebox audio plays on an **external jukebox system that the apps only control via the backend HTTP API**. Everything audible from the iPhone/iPad speaker is a 30-second *preview clip*, used while browsing. The rewrite must preserve this split exactly:

| Concern | Where it happens | Evidence |
|---|---|---|
| Full-track pub playback | Remote (server/jukebox hardware, invisible to the client) | No streaming code exists; the only `AVAudioPlayer`/audio-API usages in the whole app source are the two Tune In screens (`grep` of `secretdjv3/` finds audio playback only in `secretdjv3/TuneInViewController.swift` and `secretdjv3/KioskTuneInViewController.swift`) |
| Queueing a song on the jukebox | Remote, via `requestsong` endpoint | `secretdjv3/SelectSongAPIAccess.swift` |
| Skip / blacklist / mood change | Remote, via `machinecontrol` endpoint | `secretdjv3/MachineControlAPIAccess.swift` |
| "Now playing" display | Remote state, polled via `playhistory` endpoint | `secretdjv3/FeedAPIAccess.swift` (`nowPlaying(userId:venueId:)` uses `.playlist` = `"playhistory"`, `secretdjv3/NetworkingParameterProvider.swift`) |
| 30-second song previews | **On device** (foreground only) | `secretdjv3/TuneInViewController.swift`, `secretdjv3/KioskTuneInViewController.swift` |
| Full-song listening for the customer | Handed off to *other apps* (Spotify / Apple Music / YouTube deep links) | `secretdjv3/ListenToSong/ListenToSong.swift` |

### Remote jukebox control contract

All jukebox commands go through `MachineControlAPIAccess` (`secretdjv3/MachineControlAPIAccess.swift`) posting to the `machinecontrol` request type with parameters `user`, `venue`, `action` (an `ActionType` raw value), `item`, `value`:

- **Skip track**: action `401` (`jukeboxSkipSong`), `item` = songId, `value` = "0" (`skipTrack`, lines 117–131).
- **Blacklist track**: action `402` (`jukeboxBlacklistSong`), same shape (`blackListTrack`, lines 133–147).
- **Change mood/atmosphere**: action `400` (`jukeboxChangeAtmosphere`) with `value` = number of minutes the mood override lasts (`changeMood`, lines 94–115; driven from `secretdjv3/ChangeMoodFeedViewController.swift` and the SwiftUI pilot `secretdjv3/SwiftUI/Screens/ChangeMoodScreen.swift`).
- Response contract: `Response.ReturnCode == 0` is success, `Response.Text` is a user-facing message (`moodResult`, lines 170–181).

The full `ActionType` enum (`secretdjv3/Action.swift`, lines 40–52) contains **no volume, crossfade, pause, or queue-reorder actions** — the client cannot do any of those. Skip/blacklist buttons only appear when the server includes those actions on a song (`checkActions()` in `secretdjv3/TuneInViewController.swift` lines 421–439), i.e. they are server-granted staff/permission features, not client logic.

**Song requests** go through `requestsong` (`secretdjv3/SelectSongAPIAccess.swift`): parameters `user`, `venue`, `songid`. Return code `-8` (`WSRX_ERROR_REQUEST_NO_CREDITS`) means the user is out of credits, and the response's `ImageSize > 0` tells the phone app whether to offer "add a profile pic for credits" vs. top-up (lines 34, 64–66). The kiosk deliberately ignores the no-credits case — "In kiosk mode they will never run out of credits" (`secretdjv3/KioskTuneInViewController.swift` line 193).

**Now-playing state** is poll-only: the kiosk home screen refreshes it every 20 seconds (`beginNowPlayingAutoRefresh`, `secretdjv3/KioskNowPlayingViewController.swift` lines 185–216) and only re-renders when the songId changes. There is no push channel. A special "intermission" pseudo-song exists: `songId == "0"` (`intermissionSongId`, `secretdjv3/AppConfiguration.swift` line 151; `Song.isIntermission`, `secretdjv3/Song.swift` lines 20–22). For intermissions the kiosk splits the song *title* on `"\n\n"` into two display lines and suppresses artwork (`updateNowPlayingDetails`, `secretdjv3/KioskNowPlayingViewController.swift` lines 261–266) — a server-driven message-display hack worth knowing about, probably worth a proper API field in the rewrite.

### On-device preview playback (both apps)

Previews come from `Song.previewURL`, parsed from the feed JSON key `"Preview"` (`secretdjv3/Song.swift` line 42). The two Tune In screens are the **only** consumers of `previewURL` in the codebase. Preview UI is hidden (phone: `updateSongPreviewButtons`, `secretdjv3/TuneInViewController.swift` lines 482–488) or the button disabled (kiosk: `secretdjv3/KioskTuneInViewController.swift` lines 112–114) when `previewURL` is empty.

#### Evolution: StreamingKit → AVPlayer → download + AVAudioPlayer

1. Originally previews streamed via the StreamingKit pod (`STKAudioPlayer`).
2. Commit `d3f6f681` ("Remove StreamingKit, replace with AVFoundation AVPlayer") swapped in `AVPlayer(url:)` and deleted the pod.
3. That broke playback. Commit `49919af7` ("Fix preview playback by downloading data before decoding") explains why: **the backend serves preview audio from S3 with a custom `.pbz` file extension and a generic Content-Type**. `AVPlayer` refuses to decode such URLs (error `-11828`, "Cannot Open") because it trusts extension/MIME; `STKAudioPlayer` had worked only because it ignored both and sniffed the bytes. The fix — still the shipped design — is to download the whole file with `URLSession` and hand the raw bytes to `AVAudioPlayer(data:)`, which likewise parses the container directly. The same commit sets the scrubber bounds up front because AVPlayer never surfaced duration metadata for these files. This constraint is inline-documented in both view controllers (`secretdjv3/TuneInViewController.swift` lines 658–660, `secretdjv3/KioskTuneInViewController.swift` lines 233–235). **Any rewrite that naively uses `AVPlayer(url:)` against the existing backend will silently fail** — either keep the download-then-decode pattern or fix the backend's extension/Content-Type first.

#### Consumer app (`secretdjv3/TuneInViewController.swift`, "AudioPlayback" extension, lines 631–744)

- Tapping the preview control toggles play/stop; "active" means *either* a player exists *or* a download is in flight (`previewContainerTapped`, lines 239–247).
- `startAudioPlayer()` re-activates the audio session, immediately flips the UI into "playing" state and pins the slider to a fixed 0–30 s range with labels `0:00`/`0:30` **before any audio exists**, then downloads via a cancellable `Task` and calls `beginPlayback(with:)` on the main actor.
- `beginPlayback` guards on `previewDownloadTask != nil` so a stop-during-download wins the race (lines 680–685), then creates `AVAudioPlayer(data:)`, plays, and starts a 0.05 s repeating `Timer` driving the slider and elapsed-time label.
- The user can **scrub**: the slider writes `audioPlayer.currentTime` (`audioSliderChanged`, lines 234–237).
- Playback hard-stops at 30 s (`maxAudioPreviewDuration`) or when the player finishes (`updatePreviewProgress`, lines 725–737), and always on `viewWillDisappear` (lines 113–116).

#### Kiosk app (`secretdjv3/KioskTuneInViewController.swift`, lines 200–305)

Same download-then-decode core, with differences:
- No scrubber; a single skinned play/stop button whose *current state is determined by comparing the button's title text to the string "Preview"* (`previewButtonTapped`, lines 202–209).
- Progress timer runs at 0.5 s and exists only to auto-stop at 30 s / end of clip (lines 291–299).
- Start/stop post `NotificationCenter` notifications `"PlaybackStarted"` / `"PlaybackStopped"` (`secretdjv3/AppConfiguration.swift` lines 159–160). `KioskTimer` (`secretdjv3/KioskTimer.swift` lines 100–124) listens and **suppresses both the attract-screen timer and the idle-reset timer while a preview is playing** (`startTimers` only schedules when `!isMusicPlaying`, lines 61–76). This is real domain behavior: the kiosk must never drop into its attract screensaver mid-preview. The rewrite needs an equivalent signal.

### Audio session configuration

- Both app delegates, at launch: category `.playback`, `setActive(true)`, then `setPreferredIOBufferDuration(0.2)` accompanied by the comment "have modernised this but can't remember why required" (`secretdjv3/AppDelegate.swift` lines 50–56, `secretdjv3/KioskAppDelegate.swift` lines 31–37). The buffer tweak is almost certainly a StreamingKit-era relic (inference).
- Both Tune In screens defensively re-set `.playback` + active before every preview because "other audio (e.g. ringtones, route changes) can deactivate it" (`secretdjv3/TuneInViewController.swift` lines 640–647, `secretdjv3/KioskTuneInViewController.swift` lines 220–227).
- Consequence of `.playback`: previews play over the ring/silent switch and interrupt other apps' music (e.g. the customer's own Spotify) — presumably intended for the kiosk, debatable for the phone app. The rewrite should decide deliberately (`.ambient`/`.soloAmbient` vs `.playback` on the phone).
- **No interruption or route-change observers exist anywhere** (no hits for `AVAudioSession.interruptionNotification`/route change in `secretdjv3/`). A phone call kills a preview; the polling timer's `!audioPlayer.isPlaying` check happens to reset the UI afterwards.
- **No background audio**: neither `SecretDJ-Info.plist` nor `SecretDJKiosk-Info.plist` declares `UIBackgroundModes`. Previews are strictly foreground.
- `secretdjv3/TuneInViewController.swift` line 93 calls `UIApplication.shared.beginReceivingRemoteControlEvents()`, but nothing anywhere overrides `remoteControlReceived(with:)` and there is zero `MPNowPlayingInfoCenter`/`MPRemoteCommandCenter` usage — dead code; do not carry it forward.

### Spotify / Apple Music / YouTube: hand-off, not playback

- **No Spotify streaming SDK.** Spotify integration is (a) opening the track externally — `spotify.link` Branch deep link when the Spotify app is installed, `open.spotify.com` URL otherwise (`openAsSpotifyLink`, `secretdjv3/SpotifyAccess.swift` lines 152–174) — and (b) saving the track to a "Secret DJ" playlist in the *user's* Spotify account via a custom Spotify Web API client (`secretdjv3/SpotifyAPI.swift`, orchestrated in `secretdjv3/SpotifyAccess.swift` lines 46–116: find-or-create playlist, dedupe, add). OAuth via `ASWebAuthenticationSession` requests only `playlist-modify-public playlist-modify-private` scopes (`secretdjv3/SpotifyAuthManager.swift` line 32) — no streaming scope exists.
- The empty `Heroku_SpotifyTokenSwap/` directory at the repo root is a leftover from the old Spotify-SDK token-swap-server era (the directory exists but contains nothing on this branch).
- Apple Music = iTunes Search API lookup then `openUrl` hand-off; YouTube = backend-resolved video id or search query opened in the YouTube app/browser (`secretdjv3/ListenToSong/ListenToSong.swift`). The backend is also notified of listen events for metrics (`logSpotifyEvent` → `spotifyevent` endpoint, `watchonyoutube` endpoint; `secretdjv3/NetworkingParameterProvider.swift` lines 34, 47).

### Behavior worth preserving in the rewrite

1. Preview = max 30 s, auto-stop, one at a time, stop on screen exit; UI toggles instantly while download happens in the background; a stop during download cancels cleanly.
2. Preview affordance hidden/disabled when the song has no preview URL.
3. Kiosk attract/idle timers pause while a preview plays.
4. Skip/blacklist availability is entirely server-driven per song via actions 401/402.
5. Song request no-credits flow branches on whether the user has a profile picture.
6. Intermission (`songId == "0"`) rendering rules on the kiosk now-playing screen.
7. The `.pbz`/generic-Content-Type serving quirk — download bytes before decoding (or fix the backend first).

### Tech debt NOT to carry forward

- Kiosk play/stop state machine keyed off the button's *title string* (`"Preview"`), and hardcoded unlocalized strings "Preview"/"Stop"/"End Preview" in both screens (`secretdjv3/KioskTuneInViewController.swift` lines 204, 229, 286; `secretdjv3/TuneInViewController.swift` line 716).
- 0.05 s polling `Timer` for progress instead of observing the player; fixed 0–30 s slider even though `AVAudioPlayer.duration` is available after download.
- Whole-file download before any sound (no progressive playback) — acceptable for 30 s clips, but the "playing" UI state during download is a lie on slow networks; a rewrite could show a distinct buffering state.
- Dead `beginReceivingRemoteControlEvents()` call; cargo-culted `setPreferredIOBufferDuration(0.2)` of admitted-unknown purpose.
- No audio-session interruption/route-change handling.
- Near-duplicate preview implementations in the two Tune In view controllers — an obvious candidate for one shared preview-player component.

## Monetization, identity, analytics, and compliance

### Overview

Secret DJ monetizes through a **server-authoritative credits economy**: customers spend credits to request songs and buy credits via consumable Apple in-app purchases ("top-ups"), voucher codes, or a one-off reward for adding a profile picture. Identity is username/password, Facebook Login, or Sign in with Apple. Analytics and crash reporting are Firebase (Analytics + Crashlytics) in both targets; the ATT prompt exists solely to gate Facebook SDK features. There are **no push notifications** anywhere in the codebase.

### The credits economy

Credits are entirely server-side; the client never holds a credit balance, it only reacts to server return codes.

- **Spending**: requesting a song calls the `requestsong` endpoint (`secretdjv3/SelectSongAPIAccess.swift`). A return code of `-8` (`WSRX_ERROR_REQUEST_NO_CREDITS`) means out of credits; the response's `ImageSize > 0` doubles as "user already has a profile picture".
- **The no-credits funnel** (`secretdjv3/TuneInViewController.swift`, `onUserHasNoCreditsLeft`): if the user has *no* profile picture they are first offered "add a profile pic in return for credits" via a dialog (`secretdjv3/ProfilePicForCreditsViewController.swift`, storyboard id `ProfilePicForCredits` in `Dialogs.storyboard`); declining (or already having one) routes to the top-up purchase screen. The reward amount is server-side — the avatar upload response `Text` is shown as a toast that "may contain a reward" (`secretdjv3/TuneInViewController.swift` `UploadProfilePictureDelegate` extension).
- **Kiosk never spends credits**: the kiosk explicitly ignores the no-credits case — "In kiosk mode they will never run out of credits" (`secretdjv3/KioskTuneInViewController.swift`).
- **Balance display**: a `numpaidcredits` endpoint returns a human-readable string used after "Restore Purchases" finds nothing to restore (`secretdjv3/TopUpAPIAccess.swift` `numPaidCredits`, `secretdjv3/TopUpManager.swift` `onNoPurchasesToRestore`).
- **Top-up catalog is server-driven**: `topupdetails` returns a feed `SectionList` of `TopUp` items (SKU, name, description, price, `NumCredits`, currency) parameterized by user, optional venue, context (`insertCoin` toolbar button vs `noCredits` funnel) and vendor (`secretdjv3/TopUpAPIAccess.swift` `topUpOptions`, `secretdjv3/TopUp.swift`, `secretdjv3/FeedDataProvider.swift` `TopUpFeedDataProvider`).

### In-app purchases (StoreKit 1, consumables, server-verified)

Current implementation is **StoreKit 1** (`SKPaymentQueue`/`SKProductsRequest`) in `secretdjv3/IAPManager.swift` (singleton, delegate-based), orchestrated by `secretdjv3/TopUpManager.swift` (singleton) and surfaced in `secretdjv3/AvailableTopUpsViewController.swift` ("Get more songs" screen: voucher-code field, top-up feed, Restore Purchases, Terms & Conditions link to `http://www.secretdj.com/terms-conditions/`). The `feature/appleInAppPurchase` branch commit `37d79fbd "Apple IAP buy and restore implemented"` is where this landed (previously PayPal — see below).

Purchase pipeline worth preserving in a rewrite:

1. **Catalog reconciliation**: server SKUs are matched against `SKProductsRequest` results; store price replaces server display price (with a GBP-specific "£0.xx → pence" formatting hack), and top-ups missing from App Store Connect are removed from the feed (`secretdjv3/IAPManager.swift` `updateTopupsFromStore`).
2. **Purchase**: `TopUpManager.handleTopup` generates a client-side `topupUID` (`String(format: "%.3f", CACurrentMediaTime())`) used to correlate every analytics event and the server verification. Timeouts: 180 s for buy, 20 s for restore (`secretdjv3/IAPManager.swift`).
3. **Server verification ("consume")**: on `.purchased`, the app builds a JSON confirmation `{transactionId, sku, timestamp, packageName, receipt(base64 app-store receipt)}` and POSTs it to `topupnotify` with `user`, `vendor`, `action` (1 = paymentReceived, 2 = purchaseRestored), `uid`, `info` (`secretdjv3/IAPManager.swift` `verifyCompletedPayment`, `secretdjv3/TopUpAPIAccess.swift` `verifyTransaction`). Server return codes: `0` OK, `1` transaction already processed (treated as benign), negative = retryable, other = hard failure.
4. **Durable retry queue**: unverified confirmations are persisted to `UserDefaults` (`PendingTopUps` key) before verification (`secretdjv3/PendingTopUps.swift`). Verification retries up to 3 times in-session (`maxVerificationRetryAttempts`, `secretdjv3/TopUpManager.swift`); the oldest pending top-up is resubmitted whenever major screens appear (`resubmitPendingTopUps` called from `secretdjv3/TuneInViewController.swift`, `secretdjv3/FeedViewController.swift`, `secretdjv3/CustomTabBarViewController.swift`, `secretdjv3/JukeboxMenuViewController.swift`, `secretdjv3/KioskMusicSelectionFeedViewController.swift`, and the new `secretdjv3/SwiftUI/Feed/FeedScreenModel.swift`); after 5 total submissions a pending top-up is expired and error-reported (`maxSubmissions` in `secretdjv3/PendingTopUps.swift`). Note `finishTransaction` is called *before* server verification succeeds — the pending queue is the only safety net.
5. **Restore**: restores completed transactions, batches them into one `{purchases:[...], receipt}` payload for the same `topupnotify` endpoint (`secretdjv3/IAPManager.swift` `verifyRestoredPurchases`). Products are consumables, so this mainly re-triggers unconsumed server credit.
6. **UI**: a modal `secretdjv3/VerifyTopUpViewController.swift` spinner listens for a `kNotificationTopUpResponse` NotificationCenter broadcast carrying `{title, response, successful}`.

**Vouchers**: `redeemjukeboxvoucher` endpoint with `user`, `code`, optional `venue` (`secretdjv3/TopUpAPIAccess.swift` `redeemCode`); success message comes from the server and pops the screen.

**Affiliate revenue**: "Find on Apple Music" wraps iTunes Search results (`partnerId=2003`) in TradeDoubler click-tracking links (`http://clkuk.tradedoubler.com/click?p=23708&a=1877127&url=...`) hard-coded in both app delegates (`secretdjv3/AppDelegate.swift`, `secretdjv3/KioskAppDelegate.swift`, consumed by `secretdjv3/ITunesAPIAccess.swift`); the server can override these via feed `Store` payloads (`secretdjv3/Section.swift`).

**Dead payment code**: `IAPManager.swift-old.swift` at the repo root is the original Appcoda tutorial sample (not in the app folder). `secretdjv3/PayPalManager.swift` is a complete PayPal SDK integration but is not referenced anywhere in `secretdj.xcodeproj/project.pbxproj` and its call sites in `TopUpManager` are behind an undefined `PAYPAL_SUPPORTED` flag — dead since v5 ("DEPRECATED since move to Apple IAP" comment in `secretdjv3/KioskAppDelegate.swift`). The `Vendor` enum still carries `googlePlayStore` (`secretdjv3/TopUp.swift`), and `TopUpManager.vendor()` hard-codes `.appleAppStore`. Bug worth not copying: `TopUp.init` does `data?["VendorId"] as? Vendor`, which can never succeed on a JSON number, so `vendorId` is always `.unknown` (harmless today only because `vendor()` is hard-coded).

### Identity

Three sign-in paths, all converging on `secretdjv3/SDJLoginManager.swift` → `secretdjv3/LoginAPIAccess.swift`:

- **Username/password**: `signin` with `screenname` + `password.sha1()`. Sign-up (`createuser`) sends first/last name, gender, email, screen name, SHA-1 password.
- **Facebook Login** (`secretdjv3/FacebookManager.swift`, FBSDK ≥ 9.0 via SPM per `secretdj.xcodeproj/project.pbxproj`): permissions `public_profile, email`; Graph `me` request for `gender, first_name, last_name, email`; optional 1000×1000 profile picture fetch used to seed the avatar (`userPictureFromViewController`, used in `secretdjv3/LoginProfilePictureViewController.swift`). Server exchange via `facebooksignin` with fbid, access token, profile fields, and an `auth` digest.
- **Sign in with Apple** (`secretdjv3/LoginViewController.swift`, entitlement in `Secret DJ.entitlements`): first-run name/email are cached in the keychain (`secretdjv3/KeychainAppleUserInfo.swift`) because Apple only provides them once; `applesignin` server exchange with `appuid` + `auth` digest.
- **Server "auth" scheme** (backend contract to know about): for both social flows, `auth = sha1(socialId + (dayOfYear − 1) + hardcodedSecret)` with secrets `facebookPostcode`/`applePostcode` embedded in `secretdjv3/LoginAPIAccess.swift`. On social login the server returns a generated API password (`Param`) which becomes the user's stored password.
- **Session/credentials**: the API password lives in the keychain (`secretdjv3/UserManager.swift` `password` via `secretdjv3/KeychainPasswordItem.swift`); each API request is signed HMAC-SHA1(base64 token, key = password) (`secretdjv3/SignatureProvider.swift`, `secretdjv3/Hmac.swift`).
- **Account deletion**: `requestdeleteaccount` endpoint (`secretdjv3/RequestDeleteAccountAPIAccess.swift`, UI in `secretdjv3/RequestDeleteAccountViewController.swift` and `secretdjv3/SwiftUI/Settings/RequestDeleteAccountScreen.swift`), with a `DeleteAccountRequested` flag in defaults (`secretdjv3/UserManager.swift`).
- **Kiosk identity**: the kiosk signs in with venue credentials only — no Facebook/Apple login (`secretdjv3/KioskLoginViewController.swift` has no social code) — yet `secretdjv3/KioskAppDelegate.swift` still initializes the Facebook SDK.

### Analytics (Firebase Analytics)

- **Configuration**: `FirebaseApp.configure()` in both `secretdjv3/AppDelegate.swift` and `secretdjv3/KioskAppDelegate.swift`; per-target `GoogleService-Info.plist` under `secretdjv3/Firebase/phone/` (bundle `com.c-burn.secretdj`) and `secretdjv3/Firebase/kiosk/` (bundle `com.secretdj.kiosk`), both Firebase project `secret-dj-b1082`. Firebase iOS SDK ≥ 11.15.0 via SPM. Curiously both plists set `IS_ANALYTICS_ENABLED = false` and `IS_ADS_ENABLED = false` (legacy Google-services flags; `Analytics.logEvent` is used regardless).
- **The `Reporting` facade** (`secretdjv3/Reporting.swift`) is the single wrapper over `Analytics.logEvent`. Domain events (`ReportableEvent` enum): Facebook Sign In, Sign Up, Machine control, Reset Password, Change user details, Change full user details, Update avatar, Music search, Log Spotify event, Save to Spotify, Get skin assets, Redeem voucher, Request song, Like/Unlike, Checkin, Find On Apple Music, Top Up, Num Paid Credits, Request Delete Account. Call sites are the `*APIAccess` classes (e.g. `secretdjv3/SelectSongAPIAccess.swift`, `secretdjv3/CheckInAPIAccess.swift`, `secretdjv3/LikeAPIAccess.swift`).
- **User-event envelope**: `reportUserEvent` stamps every custom event with `timestamp`, `userId` (the Secret DJ `personId`), and `packageName` (`secretdjv3/Reporting.swift`).
- **Purchase-funnel telemetry** is unusually rich and uid-correlated — dozens of `TP_*` / `TP_ERR_*` event names across `secretdjv3/IAPManager.swift` (`TP_IAP_beginPurchase`, receipt errors 1–3, timeout), `secretdjv3/TopUpAPIAccess.swift` (`TP_API_beginTopupNotify`, verify errors incl. full confirmation payloads), and `secretdjv3/TopUpManager.swift` (`TP_beginVerifyPurchase`, resubmit, expiry). The rewrite should preserve this funnel observability; it was clearly built to debug lost purchases in production.
- **Screen tracking**: `secretdjv3/PageViewReportingManager.swift` swizzles `UIViewController.viewDidAppear` ("Swizzling is not very nice - I am sorry") and logs an event named after the feed/class with a `timeSpent` parameter on exit. The `pageViewPrefix = "PageView-"` constant is dead — names are logged unprefixed. The new SwiftUI screens under `secretdjv3/SwiftUI/` contain **no analytics at all** (no `Reporting` references), so screen coverage is already regressing on the `refactor` branch.
- **Likely broken event names** (inference — verify in the Firebase console): most `ReportableEvent` raw values contain spaces ("Facebook Sign In", "Request song"), which violate Firebase Analytics' `[a-zA-Z0-9_]` event-name rule; such events are typically rejected by the SDK. The `TP_*` names are valid. If years of Firebase data show only `TP_*` and screen events, that's why — and the rewrite's event taxonomy should be snake_case from day one.
- **PII flows into analytics** (do **not** carry forward): `resetPassword` logs the email/screenname parameter dict (`secretdjv3/PasswordAPIAccess.swift`); `changeFullUserDetails` logs first/last name, screen name, and email (`secretdjv3/UserDetailsAPIAccess.swift`; its sibling `reportChangeUserDetails` filters only `password`); every custom event carries `userId`; purchase-error events embed full receipts/confirmation data (`secretdjv3/TopUpAPIAccess.swift`).

### Crash reporting (Firebase Crashlytics)

Both targets link FirebaseCrashlytics (`secretdj.xcodeproj/project.pbxproj`). `Crashlytics.crashlytics().setUserID(personId)` is set on every launch and refreshed on login/detail changes (`secretdjv3/UserManager.swift` `updateCrashlyticsDetails`, called from both app delegates, `secretdjv3/SDJLoginManager.swift`, `secretdjv3/KioskLoginFlowController.swift`, `secretdjv3/SettingsChangeDetailsViewController.swift`). The user's name and email are still cached in `UserDefaults` under `CrashlyticsUserName`/`CrashlyticsUserEmail` even though the code that sent them to Crashlytics is commented out (legacy Fabric API). Manual dSYM upload scripts live at the repo root (`upload-phone-dsyms-to-firebase-crashlytics`, `upload-kiosk-dsyms-to-firebase-crashlytics`), pointing at the per-target GoogleService plists. The kiosk's Info.plist still embeds a dead **Fabric APIKey** (`SecretDJKiosk-Info.plist`).

### AppTrackingTransparency

`secretdjv3/AppTrackingTransparency.swift` provides free functions `requestTrackingPermission` / `trackingHasBeenRejected`. The prompt is **not** shown at startup — it gates exactly two actions, both Facebook SDK-touching: Facebook sign-in (`secretdjv3/LoginViewController.swift` `signInFromFacebook`) and "use my Facebook photo" (`secretdjv3/LoginProfilePictureViewController.swift`). If tracking is denied, the Facebook buttons are disabled/dimmed. Both call sites carry a 1-second delay workaround for an FBSDK bug that cancels the first login after the ATT dialog (comments dated 27/01/22). Comment history records App Store review friction: a denial dialog and then even a toast were removed at Apple's insistence (comments dated 08/02/22 in `showTrackingNotAllowedMessage`). The phone Info.plist's `NSUserTrackingUsageDescription` states the app itself doesn't track and only Facebook might (`SecretDJ-Info.plist`); it also sets `FacebookAutoLogAppEventsEnabled=false` and `FacebookAdvertiserIDCollectionEnabled=false`. The kiosk plist sets **neither** flag (FB SDK defaults apply) and has no ATT usage description — but also never calls ATT. No `AdSupport`/IDFA APIs exist anywhere in the app source.

### Push notifications

None. No `UNUserNotificationCenter`, `registerForRemoteNotifications`, or `didReceiveRemoteNotification` anywhere in `secretdjv3/`; no `aps-environment` entitlement (`Secret DJ.entitlements` contains only Sign in with Apple + keychain groups; it is the only `.entitlements` file in the repo). The only NotificationCenter traffic is in-process (e.g. the top-up response notification). The rewrite is free to design push from scratch or skip it.

### Privacy-relevant data flows (inventory of what is collected)

- **Location**: when-in-use only (`NSLocationWhenInUseUsageDescription` in both Info.plists, "find your nearest venue"). `secretdjv3/LocationManager.swift` is a singleton wrapping CLLocationManager. Crucially, **the user's coordinates (6-decimal precision, ~10 cm) are appended as `coords` to essentially every Secret DJ API request** via `additionalParameters()` in `secretdjv3/NetworkingParameterProvider.swift` — not just nearby-venue lookups. A rewrite privacy design should decide deliberately whether to keep this. GPX fixtures for test locations sit in the source folder (`secretdjv3/Chiswick.gpx` etc.).
- **Check-in**: `checkin` endpoint with `user`, `venue`, `scope` (`secretdjv3/CheckInAPIAccess.swift`). A three-level `CheckinVisibility` enum exists (friends / everyone / no-one "travelling incognito"), but the only call site hard-codes `.everyone` (`secretdjv3/VenueFeedViewController.swift`); an unused `scope` UserDefaults key hints at a lost setting (`secretdjv3/UserManager.swift`).
- **Camera & photos**: front-camera capture for profile pictures via `secretdjv3/CameraManager.swift` (deprecated `AVCaptureStillImageOutput` API) plus `UIImagePickerController` photo-library path; usage descriptions in `SecretDJ-Info.plist` are profile-picture-scoped. Avatars upload as JPEG (quality 0.9, `secretdjv3/AppConfiguration.swift`) to the `newavatar` endpoint with the user id (`secretdjv3/AvatarAPIAccess.swift`, `secretdjv3/UploadProfilePicture.swift`); the avatar-update analytics event logs only the byte size.
- **Facebook data**: gender, name, email, and profile photo pulled from the Graph API (see Identity above); gender is forwarded to the Secret DJ backend and logged to analytics (`secretdjv3/LoginAPIAccess.swift`).
- **Stored on device**: API password + Apple user info in the keychain; current user/venue JSON, Spotify username/credential keys, and Crashlytics name/email/id copies in `UserDefaults` (`secretdjv3/UserManager.swift`).
- **Transport security**: both Info.plists set `NSAllowsArbitraryLoads = true`, and several hard-coded URLs are plain `http://` (iTunes search, TradeDoubler affiliate links, terms-and-conditions page in `secretdjv3/AvailableTopUpsViewController.swift`).
- **Leftover Apple sample code**: `secretdjv3/LoginViewController.swift` still contains the demo `showPasswordCredentialAlert` that displays a keychain password in a UIAlert if an `ASPasswordCredential` is ever returned — remove, don't port.
- **Settings.bundle** exposes only "Stay signed-in" and "Disable Auto-Lock" toggles (`secretdjv3/Settings.bundle/Root.plist`).

### Tech debt in this dimension NOT to carry forward

1. **StoreKit 1** delegate/notification spaghetti → StoreKit 2 `Product`/`Transaction` with async verification; keep the server-consume contract (`topupnotify` + uid + pending queue semantics) and the funnel telemetry, drop the `CACurrentMediaTime()` uid and `finishTransaction`-before-verify ordering.
2. **Dead payment paths**: `IAPManager.swift-old.swift` (repo root), `secretdjv3/PayPalManager.swift`, `PAYPAL_SUPPORTED` blocks, `Vendor.googlePlayStore`, and the always-`.unknown` `vendorId` parse bug in `secretdjv3/TopUp.swift`.
3. **Method-swizzled screen tracking** (`secretdjv3/PageViewReportingManager.swift`) → explicit screen events; SwiftUI screens currently have zero coverage.
4. **Analytics event names with spaces** (likely never recorded) and **PII in event parameters** (emails, names, userId on every event, receipts in error events) — the rewrite's Observability pipeline should enforce a redaction boundary.
5. **Hard-coded auth secrets** and the SHA-1 day-of-year `auth` digest in `secretdjv3/LoginAPIAccess.swift`, plus SHA-1 password hashing client-side — backend coordination needed, but don't replicate blindly.
6. **Config hygiene**: dead Fabric APIKey in `SecretDJKiosk-Info.plist`, blanket ATS `NSAllowsArbitraryLoads`, `http://` monetization links, kiosk missing the Facebook data-collection opt-out plist flags (or better: drop the FB SDK from the kiosk entirely, since it has no Facebook features).
7. **Crashlytics email/name copies in UserDefaults** that are no longer sent anywhere.

## UI layer, assets, localization, and accessibility

#### How the UI is built (summary)

The UI is UIKit, dark-theme-only, built from a mix of programmatic view controllers, storyboards, and nib-based collection view cells, with a small set of SwiftUI screens recently introduced behind per-screen feature flags (`secretdjv3/SwiftUI/Core/FeatureFlags.swift`: `settings`, `changeMood`, and `musicSearch` ship as SwiftUI by default, each with a UserDefaults kill switch `swiftui.<screen>`). Both apps boot programmatically — no main storyboard is actually used:

- **Consumer app**: `secretdjv3/SceneDelegate.swift` creates a `CustomTabBarViewController` inside a `UINavigationController`, sets the window background to the `BackgroundUniversal` pattern image.
- **Kiosk app**: `secretdjv3/KioskSceneDelegate.swift` either starts `KioskLoginFlowController` (`secretdjv3/KioskLoginFlowController.swift`) or shows the kiosk home screen.

Trap for the unwary: the kiosk's `SecretDJKiosk-Info.plist` still declares `UIMainStoryboardFile = Login_iPhone`, a dead storyboard whose classes no longer exist (see below). It is ignored only because both plists carry a `UIApplicationSceneManifest` with `UISceneDelegateClassName` and no scene storyboard.

#### Storyboard estate (26 storyboards: 10 live, 16 dead)

**Live — consumer app** (all under `secretdjv3/StoryBoards/` plus `secretdjv3/Dialogs.storyboard`; instantiated by name in code, e.g. `secretdjv3/FeedActionProvider.swift`):

| Storyboard | Scenes / classes |
|---|---|
| `StoryBoards/Music.storyboard` | `SearchContainerViewController` ("MusicSearch"), `TuneInViewController` ("TuneIn"), `JukeboxMenuViewController` — song search, song request ("Tune In"), jukebox menu |
| `StoryBoards/RewriteLogin.storyboard` | Full login/onboarding flow: `SDJSplashScreenViewController`, `LoginViewController`, `LoginForgottenPasswordViewController`, `LoginUserNameViewController`, `LoginGenderViewController`, `LoginProfileDetailsViewController`, `LoginProfilePictureViewController` |
| `StoryBoards/RewriteSettings.storyboard` | `SettingsViewController`, `SettingsChangeDetailsViewController`, `SettingsChangePasswordViewController`, `RequestDeleteAccountViewController` (superseded at runtime by the SwiftUI settings flow when its flag is on) |
| `StoryBoards/Directions.storyboard` | `VenueDirectionsViewController` |
| `StoryBoards/Web.storyboard` | `InternalWebViewController` (also used by `secretdjv3/ToastHandler.swift` and `secretdjv3/AvailableTopUpsViewController.swift`) |
| `StoryBoards/LaunchScreen.storyboard` | Launch screen (`UILaunchStoryboardName` in root `SecretDJ-Info.plist`) |
| `Dialogs.storyboard` | A single 153-line dialog: `ProfilePicForCreditsViewController` (identifier "ProfilePicForCredits"), presented from `secretdjv3/TuneInViewController.swift` — the "add a profile picture, earn credits" upsell |

**Live — kiosk app** (`secretdjv3/Kiosk/Storyboards/`):

| Storyboard | Scenes / classes |
|---|---|
| `Kiosk.storyboard` | `KioskNowPlayingViewController` (home), `KioskSearchViewController`, `KioskSearchKeyboardViewController` (a custom on-screen keyboard) |
| `KioskLogin.storyboard` | 4,247 lines, 10 scenes: kiosk splash/sign-in (`KioskSplashScreenViewController`, `KioskLoginViewController`, `KioskSigningInViewController`, `SDJLoadAssetsViewController`, `SDJLoadVenueViewController`) **plus consumer-style signup scenes** (`SDJAvatarViewController`, `SDJDetailsViewController`, `SDJGenderViewController`, `SDJUserNameViewController`, `SDJForgotPasswordViewController`) — customers can register on the kiosk |
| `KioskMusic.storyboard` | `KioskTuneInViewController` plus several scenes whose custom classes (`SDJNowPlayingViewController`, `SDJChangeMoodCollectionViewController`, `SDJMusicSelectionViewController`, …) **no longer exist in source** — only `KioskTuneIn` is instantiated (`secretdjv3/KioskFeedActionProvider.swift`) |

**Dead — 16 legacy storyboards, still bundled into both shipping apps.** These are the pre-rewrite per-idiom pairs: `secretdjv3/Base.lproj/Login_iPhone.storyboard` + `Login_iPad.storyboard` (~4,200 lines each), `Main_iPhone`/`Main_iPad`, `Music_iPhone`/`Music_iPad`, `Venues_iPhone`/`Venues_iPad`, `Settings_iPhone`/`Settings_iPad`, `Directions_iPhone`/`Directions_iPad`, `Web_iPhone`/`Web_iPad`, `PPP_iPhone` (Purchase/PayPal/topup-era), and `Kiosk_iPad.storyboard` (2,290 lines — the previous kiosk UI). Every custom class they reference is `SDJ`-prefixed Objective-C that has been deleted (verified: no `class`/`@interface` declarations exist for `SDJTopLevelViewController`, `SDJMasterLoginViewController`, `SDJVenueViewController`, `SDJKioskNowPlayingViewController`, etc.), and no code instantiates them. Yet `secretdj.xcodeproj/project.pbxproj` Resources phases still copy 24 storyboards/asset-catalogs into the consumer app and 26 into the kiosk — instantiating any of them would crash. Two `.m.trvs` relics of the ObjC→Swift conversion also sit in the tree (`secretdjv3/SDJCustomPushAnimator.m.trvs`, `secretdjv3/SDJPlacesNearbyViewController.m.trvs`). None of this should carry forward.

#### Xib estate (41 xibs)

- **Feed cells** — 27 xibs in `secretdjv3/Cells/`, one Swift class each, registered by string name through `secretdjv3/FeedCellConfigurator.swift` and `secretdjv3/ContainerCellConfigurator.swift`. Two families: the older "flat" cells (`FeedItemCollectionViewCell`, `SongCollectionViewCell`, `PersonCollectionViewCell`, `VenueCollectionViewCell`, `AdvertCollectionViewCell`, `AwardCollectionViewCell`, `CheckInCollectionViewCell`, `NewsItemCollectionViewCell`, `PromotionCollectionViewCell`, `PPPCollectionViewCell`, `Horizontal{Award,Person,Song,VIP}CollectionViewCell`) and the 2023 "Matrix" design-refresh cells sized off `StyleKit2023` tokens (`Matrix{Award,Person,Song}{Small,Medium}…`, `MatrixPromotionMedium…`, `MatrixJukeboxLarge…`, `MatrixMachineControlLarge…`, plus `ContainerCollectionViewCell` which hosts nested horizontal collections). `ContainerCellConfigurator.swift` swaps in `KioskMatrixJukeboxLargeCollectionViewCell` when running as kiosk. `JukeboxCollectionViewCell.xib` has zero code references — dead. `Cells/iPad/MatrixJukeboxLargeCollectionViewCell_ipad.xib` backs `secretdjv3/MatrixJukeboxLargeCollectionViewCell_ipad.swift`.
- **Section headers/footers** — 7 xibs in `secretdjv3/SupplementaryViews/` (`NowPlayingSectionHeaderView`, `VenueSectionHeaderView`, `ProfileSectionHeaderView`, `JukeboxSectionHeaderView`, `MoodSectionHeaderView`, `SectionHeaderView`, `SectionFooterView`), registered via `secretdjv3/SupplementaryViewProvider.swift`.
- **Kiosk nibs** — `secretdjv3/Kiosk/Nibs/`: `KioskArtistCollectionViewCell`, `KioskMatrixSongMediumCollectionViewCell`, `KioskSectionHeaderView`.
- **Other** — `secretdjv3/CustomTabBarViewController.xib` (the root tab container), `secretdjv3/Nibs/ExtraContentView.xib` (animated promo overlay driven by `secretdjv3/ExtraContentManager.swift`), `secretdjv3/Nibs/VerifyTopUpViewController.xib` (top-up verification).

#### Custom UI component library

- **Owner-drawn button family** — `secretdjv3/CustomButton.swift` (base: fill/outline/text colours, darken-by-0.2 when pressed, darken-by-0.5 when disabled, draws a pill via `StyleKit.drawSDJButton` in `draw(_:)`; includes `UIColor.lightenColor/darkenColor` helpers). Subclasses: `BlueButton` (Facebook blue), `GreenButton` (brand teal; hides `titleLabel` with `alpha = 0` and paints the text itself), `GreenOutlineButton`, `GreyButton`, `GreenTabLeftButton`/`GreenTabRightButton` (segmented pair), `SearchClearButton`, `StandardKeyButton`/`WideKeyButton` (kiosk on-screen keyboard keys), `KioskStandardButton`, `KioskPlaySongButton`, `KioskAllJukeboxesButton` (all in `secretdjv3/`).
- **Text fields** — `secretdjv3/CustomTextField.swift` (2024-era: grid-based padding, circular ends, styled placeholder) and the older `secretdjv3/IndentedTextField.swift`.
- **Tab bar** — a fully custom implementation, not `UITabBarController`: `secretdjv3/CustomTabBar.swift` (plain `UIView` of icon-only `UIButton`s), `secretdjv3/CustomTabButton.swift`, `secretdjv3/CustomTabBarViewController.swift`, with tabs defined in `secretdjv3/TabBarConfigurationProvider.swift` (Places Nearby, Activity/"Buzz", News, Profile feeds built per-user).
- **Toasts** — a push-message display system: `secretdjv3/ToastManager.swift` (its own `UIWindow`, a persisted queue, keyboard avoidance), `secretdjv3/SimpleToastView.swift` (kiosk variant is skinnable), `secretdjv3/RichToastView.swift` (tappable, can open a profile or URL), `secretdjv3/ToastHandler.swift`, `secretdjv3/ToastViewController.swift`.
- **Transitions** — three `UIViewControllerAnimatedTransitioning` pairs plus providers: `FadeInAnimator`/`FadeOutAnimator` + `FadeAnimatedTransitionProvider`, `PopInAnimator`/`PopOutAnimator` + `PopInOutAnimatedTransitionProvider`, `SlideLeftAnimator`/`SlideRightAnimator` + `SlideAnimatedTransitionProvider` (all in `secretdjv3/`).
- **Misc** — `secretdjv3/BDKCollectionIndexView.h/.m` (vendored ObjC A–Z index scrubber, used by `ArtistSearchFeedViewController` and `KioskSearchArtistListViewController`; the last ObjC UI in the app), `ScrollIndicator.swift`, `LoadingView.swift`, `LocationPermissionDeniedView.swift`, `MachineControlProgressIndicator.swift`, `ImageResizeView.swift` (pinch/pan avatar cropper), `SectionHeaderLabel.swift`, `secretdjv3/Components/ListenToSongButton.swift` + `ListenToSongBottomSheet.swift` (2024-era bottom sheet for song previews), and category helpers (`UIView+Pin.swift`, `UIView+CornerRadius.swift`, `UIViewController+CustomTitleLabel.swift`, `UIImageView+LoadImage.swift`).
- **SwiftUI islands** — `secretdjv3/SwiftUI/` contains a bridge (`Bridge/HostedScreen.swift`, which forces `overrideUserInterfaceStyle = .dark`; `Bridge/UIKitNavigator.swift`), a theme layer (`Theme/SDJTheme.swift` — colours/spacing/fonts computed from `AppColors`/`StyleKit2023` so UIKit and SwiftUI can't drift; `Theme/SDJButtonStyle.swift` — a `ButtonStyle` replicating the `CustomButton` pill/darken behaviour), a SwiftUI feed engine (`Feed/`), search (`Search/`, `Screens/MusicSearchScreen.swift`), mood (`Screens/ChangeMoodScreen.swift`), and settings (`Settings/`).

#### Design system and assets

- **Design tokens** live in three places that the rewrite should consolidate: `secretdjv3/StyleKit.swift` (2017, PaintCode-style: brand colours as hex — teal `#15BB9F`, dark greys `#282828`/`#393939`, text `#D4D4D4` — plus Core Graphics drawing methods `drawSDJButton`, `drawSDJTabButton`, and a screen-width-based `dynamicFontSize(_:referenceWidth: 393)` hack), `secretdjv3/StyleKit2023.swift` (the 2023 refresh: `gridUnit = 4`, Matrix cell sizes Small/Medium/Large/Massive with insets and corner radii, text field metrics), and `enum AppColors` + `enum FontConfig` in `secretdjv3/AppConfiguration.swift` (colour literals; fonts are system-provided HelveticaNeue variants — no bundled font files, no `UIAppFonts`). `secretdjv3/ThemeManager.swift` does global `UIAppearance` setup and **swizzles `UIViewController.viewDidLoad`** to strip back-button text and force nav tint (its own comment: "Swizzling is not very nice - I am sorry") — do not carry forward.
- **Asset catalogs**: `secretdjv3/SecretDJ.xcassets` is the real catalog — 158 imagesets organised by screen ("Screen - Venue", "Screen - Settings", "Screen - Login", …), 64 icons, 10 tab icons, photo-library and PPP folders, `AppIcon.appiconset`, and a deprecated, unused `LaunchImage.launchimage` (launch uses `LaunchScreen.storyboard`). `secretdjv3/Common.xcassets` is nearly empty (2 web-view button imagesets) and `secretdjv3/Kiosk.xcassets` holds a single imageset (`GradientJukeboxiPad`); both are separate build-phase entries per target in `secretdj.xcodeproj/project.pbxproj`. Zero `.colorset`s — no colours are in catalogs. A few loose PNGs sit outside any catalog at the source root (`secretdjv3/iconTabNearby@2x.png`, `secretdjv3/roundPlaceholderAvatarUnisexBackground.png`).
- **Design sources** (exist; not build inputs): `Paintcode/SDJAssets.pcvd` (single PaintCode document — inferred to be the source of the StyleKit drawing code) and `Photoshop/` (6 PSDs of button states plus sliced `@2x` PNG exports in `ButtonRadio-assets/` and `ButtonStandard-assets/`).
- **Remote venue skinning (kiosk)** — a genuine domain feature to preserve: `secretdjv3/SkinManager.swift` + `secretdjv3/SkinAPIAccess.swift` download per-venue skin bundles into Documents and expose them via three id-keyed enums — `SkinAsset` (35 image slots: backgrounds, every button state, keyboard keys, placeholders), `SkinColor` (11 colour slots), and `SkinText` (12 slots that also smuggle **behavioural config**: `idleTimeoutSeconds`, `attractTimeoutSeconds`, `attractURL`, toast colours/border). The kiosk's idle "attract screen" (`secretdjv3/AttractViewController.swift`) loads the skin-provided `attractURL` into a `WKWebView`. The numeric ids are a server contract.
- **Dark-only theme**: colours are hardcoded dark; neither plist sets `UIUserInterfaceStyle`, and the SwiftUI bridge pins `.dark` per-screen (`secretdjv3/SwiftUI/Bridge/HostedScreen.swift`). There is no light-mode design to migrate.

#### Localization — English only, catalog-migrated, with substantial leakage

- **Only English has ever existed.** `knownRegions` in `secretdj.xcodeproj/project.pbxproj` is `English, en, Base`; no non-`en` lproj for the app's own strings appears anywhere in git history (the only foreign-language `.strings` ever committed were inside the vendored Facebook SDK pod).
- **String Catalog state**: commit `d6dd0a19` converted the old 241-line `secretdjv3/Localizable.strings` to `secretdjv3/Localizable.xcstrings`. Today the catalog has **181 keys, 168 with an `en` value**; the 13 empty entries are auto-extracted junk from SwiftUI literals (`""`, `"%lld"`, `"00"`, `"CHANGE THE MOOD"`, added in commit `4fef6ac9`) — evidence that SwiftUI `Text("…")` literals are being auto-harvested as their own display-text keys alongside the established `Snake_Case` key convention. Key domains: `Validation_*` (13), `RAD_*` (request-account-deletion, 11), `Spotify_*` (11), `Kiosk_*` (8), `ATT_*` (7), `Web_*` (7), `Camera_*`/`Photo_*` (12), `TOPUP_*`/`TopUp_*`/`IAP_*`/`RESTORE_*` (15), `Location_*`, `Login_*`/`SignUp_*`.
- **API usage**: 180 `NSLocalizedString` call sites across 53 Swift files; zero `String(localized:)`. The catalog resolves both, so this works, but the rewrite's `String Catalog` conventions differ.
- **Leakage — strings that bypass localization entirely** (the six-language rewrite must recapture all of these):
  - At least 16 hardcoded `setTitle` calls and ~23 hardcoded `.text =` assignments, e.g. `"REDEEM"`, `"Restore Purchases"`, `"Terms & Conditions"` (`secretdjv3/AvailableTopUpsViewController.swift`), `"CONTROL MUSIC"`/`"JUKEBOX"`, `"My Profile"`, `"PERSON LIKES YOU"` (`secretdjv3/SupplementaryViewProvider.swift`), `"End Preview"`/`"Preview"` (`secretdjv3/KioskTuneInViewController.swift`), `"Requesting..."` (`secretdjv3/TuneInViewController.swift`).
  - **All storyboard/xib text is unlocalized** — no storyboard has a `.strings` companion; `secretdjv3/Base.lproj/` contains only the two dead Login storyboards, and live storyboards (`RewriteLogin`, `RewriteSettings`, `Kiosk`, `KioskLogin`, …) carry their English copy inline.
  - SwiftUI literals such as `"Play for how long?"`, `"CHANGE THE MOOD"`, `"Mins"` (`secretdjv3/SwiftUI/Feed/Headers/MoodSectionHeader.swift`).
  - The four permission strings (camera, location, photo library, tracking) live directly in root `SecretDJ-Info.plist`; `secretdjv3/en.lproj/InfoPlist.strings` exists but is an empty stub, so they cannot be translated as-is.
  - `secretdjv3/Settings.bundle/en.lproj/Root.strings` (UTF-16) localizes the iOS Settings pane in English only.
  - Some kiosk copy comes from the server via `SkinText` (search placeholders) — server-side, outside any catalog.

#### Accessibility — effectively zero; everything is a gap

- **No accessibility API usage anywhere in code**: a repo-wide grep for `accessibilityLabel`, `accessibilityHint`, `accessibilityIdentifier`, `accessibilityValue`, `accessibilityTraits`, `isAccessibilityElement`, `UIAccessibility` (announcements, reduce-motion, VoiceOver-running checks) across all `.swift`/`.m` files returns **0 hits**. In SwiftUI code: also 0.
- **One accessibility label exists in the entire IB estate**, and it is garbage: a base64-encoded label on a jukebox image in `secretdjv3/SupplementaryViews/JukeboxSectionHeaderView.xib` that decodes to a single control character.
- **Consequences worth spelling out for the rewrite**: the root tab bar is four icon-only `UIButton`s with no titles or labels (`secretdjv3/CustomTabBar.swift`, `secretdjv3/TabBarConfigurationProvider.swift`) — unnavigable by VoiceOver; every feed cell is image-led with unlabelled imagery; the kiosk's custom on-screen keyboard (`KioskSearchKeyboardViewController` in `secretdjv3/Kiosk/Storyboards/Kiosk.storyboard`) has no accessibility treatment. Buttons that keep a UIKit title (the `CustomButton` family sets titles even where `GreenButton` hides `titleLabel` and owner-draws the text) likely inherit a default VoiceOver label from the title, but nothing was ever authored deliberately.
- **No Dynamic Type at all**: zero uses of `preferredFont(forTextStyle:)`, `UIFontMetrics`, or `adjustsFontForContentSizeCategory` in code, and zero text styles or autoshrink-for-content-size in any storyboard/xib — every one of the ~190 IB font references and 34+ code font sites is a fixed-point-size HelveticaNeue. The only "scaling" is `StyleKit.dynamicFontSize`, which scales by *screen width* (dampened, reference 393pt), not text settings. On the SwiftUI side, `.font(.system(size:))` and `Font(UIFont)` (`SDJTheme.sectionHeaderFont`) are fixed; only the `Font.custom(_:size:)` calls in `SDJTheme` happen to scale with Dynamic Type as a framework default, unreviewed.
- **No reduced-motion handling** in the six custom transition animators or the `ExtraContentManager` rotation/bounce animations, and no contrast auditing (note `AppColors.darkText` is 50%-alpha grey on dark grey in `secretdjv3/AppConfiguration.swift` — a likely contrast failure).

#### What this means for the rewrite

Worth preserving: the design tokens (4pt grid, Matrix size classes, brand colours, pill buttons with darken-on-press) already consolidated once into `StyleKit2023`/`SDJTheme`; the kiosk skin contract (`SkinAsset`/`SkinColor`/`SkinText` ids); the toast queue behaviour; the screen inventory encoded in the live storyboards. Explicitly not worth carrying: the 16 dead storyboards and dead scenes inside live ones, `LaunchImage.launchimage`, the `viewDidLoad` swizzle, screen-width font scaling, PaintCode runtime drawing (replace with SwiftUI shapes), the three-way split of colour definitions, and the string-leakage patterns above. Localization into six languages starts from a 168-string English catalog that under-counts real UI copy by a wide margin (storyboard text, hardcoded UIKit strings, plist permission strings, Settings.bundle); accessibility starts from zero.

## Architecture and tech debt

### How the codebase is put together

#### One codebase, two apps, branching at runtime

Both targets compile essentially the same ~274 Swift files out of `secretdjv3/`; which app you get is decided **at runtime by bundle identifier**. `AppConfiguration.isKiosk` (`secretdjv3/AppConfiguration.swift`) returns false for `com.c-burn.secretdj`, true for `com.secretdj.kiosk`, and calls `fatalError` for anything else. That one boolean is then consulted all over the codebase — cell nib mapping (`secretdjv3/FeedCellConfigurator.swift`, `secretdjv3/ContainerCellConfigurator.swift`), sizing math (`secretdjv3/FeedCellSizeCalculator.swift`, `secretdjv3/ContainerCellSizeCalculator.swift`), data-provider refresh policy (`secretdjv3/FeedDataProvider.swift` — `MusicDigestFeedDataProvider.shouldReloadOnViewAppearance`), toast behavior (`secretdjv3/AppDelegate.swift`), header sizing (`secretdjv3/SupplementaryViewProvider.swift`). Compile-time separation exists but is minimal: the kiosk target defines `-DSECRET_DJ_KIOSK` (`secretdj.xcodeproj/project.pbxproj` line 4053) and only five `#if SECRET_DJ_KIOSK` / `#if !SECRET_DJ_KIOSK` blocks exist in three files. On top of the runtime flag there is a parallel `Kiosk*`-prefixed class family (36 `Kiosk*.swift` files: `KioskAppDelegate`, `KioskFeedActionProvider`, `KioskTuneInViewController`, `KioskLoginFlowController`, its own search stack, etc.), so kiosk behavior is split across *both* mechanisms — some divergence lives in subclass overrides/parallel classes, some in `isKiosk` if-statements inside shared code. The kiosk even subclasses `UIApplication` (`secretdjv3/KioskApplication.swift`) whose `sendEvent` override posts a `UserDidTouchScreen` notification (for attract/idle mode) — from a background dispatch queue, incidentally — and boots via a manual `main.swift` + `UIApplicationMain` while the phone app uses `@UIApplicationMain` on `secretdjv3/AppDelegate.swift`.

Layers of history are visible: the repo spans 2014–2026 (first commit 2014-06-23); the `secretdjv3/` folder name, `SDJ`-prefixed dead Objective-C (`secretdjv3/SDJCustomPushAnimator.m.trvs`, `secretdjv3/SDJPlacesNearbyViewController.m.trvs` — renamed with a `.trvs` extension to keep them out of the build), a 2023 reskin (`secretdjv3/StyleKit2023.swift` alongside the older `secretdjv3/StyleKit.swift`), a mid-life storyboard rewrite (`RewriteLogin`/`RewriteSettings` storyboards in `secretdjv3/StoryBoards/`), and — on this `refactor` branch — the beginnings of a SwiftUI migration (`secretdjv3/SwiftUI/` with per-screen kill switches in `secretdjv3/SwiftUI/Core/FeatureFlags.swift` and a UIKit navigation bridge in `secretdjv3/SwiftUI/Bridge/UIKitNavigator.swift`; Settings, ChangeMood and MusicSearch already default to SwiftUI). The rewrite team should treat the SwiftUI folder as a useful reference implementation, not as legacy to reproduce.

#### The feed engine (the heart of both apps)

Almost every screen is an instance of one server-driven-UI system:

- **Model**: the server returns section lists as loosely typed dictionaries. `secretdjv3/SectionList.swift` → `secretdjv3/Section.swift` → `secretdjv3/Item.swift` (rooted at `ItemImage: NSObject`, `secretdjv3/ItemImage.swift`). Parsing is hand-rolled `dictionary["Key"] as? T` with typed subclasses (`Song`, `Person`, `Venue`, `Jukebox`, `Artist`, `Promotion`, `News`, `TopUp`, `Control`). Each `Section` carries an `ItemType`, a numeric `Template` (the big enum in `secretdjv3/AppConfiguration.swift`: `.song = 200`, `.matrixJukeboxLarge = 601`, `.container = 9999`…) and an untyped `custom: [AnyHashable: Any]` bag that business logic reads stringly (`custom["Total"]`, `custom["Batch"]`, `custom["TopupAllowed"]`, `custom["Store"]`). Items keep a `parentSection` back-pointer (a `Section` is its own parent), and `Item.isEqual` compares a **base64-encoded JSON re-serialization of the raw dictionary** computed at parse time (`secretdjv3/Item.swift` lines 67–79) — this string is also the basis on which the feed differ works.
- **View controller**: `secretdjv3/FeedViewController.swift` (590 lines) owns a `UICollectionView` with a custom `StickyHeaderLayout`, pull-to-refresh, a repeating refresh `Timer` whose cadence encodes a real business rule (3s until first location fix, then 20s — see `initTimerIfRequired`, referencing bug #181), infinite scroll triggered 2000pt before the end (`scrollViewDidScroll`), and the swipe-up "extra content" banner. Screen variants subclass it (`VenueFeedViewController`, `ProfileFeedViewController`, `NowPlayingFeedViewController`, `ChangeMoodFeedViewController`, `KioskMusicDigestFeedViewController`, …) and override the `update(...)` hook methods.
- **Interactor**: a VIP-lite pattern. `secretdjv3/FeedInteractor.swift` implements `FeedInteractorInput`; the VC constructs it and wires a bidirectional reference (`interactor.viewController = viewController`, held as `weak var viewController: FeedViewControllerInput!`). The interactor orchestrates fetch/pagination/tap flows and calls back through the `FeedViewControllerInput` protocol (`show(sectionList:)`, `showJukeboxChanged()`, …). Only four interactors exist (`FeedInteractor`, `SongSearchFeedInteractor`, `ArtistSearchFeedInteractor`, `MusicDigestInteractor`); everything else is plain MVC.
- **Action provider (router + business rules)**: `secretdjv3/FeedActionProvider.swift` maps a tapped `Item`/`Action` to a `FeedAction` enum (`.viewController(.push/.present)`, `.jukebox`, `.artist`, `.url`). It is simultaneously the app's router and a rules engine — it instantiates destination view controllers itself (storyboard lookups with `as!` force-casts), decides the Facebook/Twitter/Instagram deep-link vs web fallback for promotions, fires a `promotionEngaged` API call as a side effect of *not* navigating, and reads `custom["TopupAllowed"]`. It force-unwraps the session at construction (`var currentUser = UserManager.shared.currentUser!`). The kiosk has a parallel `secretdjv3/KioskFeedActionProvider.swift`.
- **Data providers**: `secretdjv3/FeedDataProvider.swift` (674 lines) declares the `FeedDataProvider` protocol (fetch, next page, extra content, `shouldAutoRefresh`, `shouldReloadOnViewAppearance`) plus **twelve** implementations in the same file, some inheriting from each other (`ActivityFeedDataProvider: NewsFeedDataProvider`). Pagination providers implement the "jukebox changed" rule: every page response carries a hash, and a hash mismatch mid-pagination fails with `.jukeboxChanged`, which surfaces a toast and posts a `JukeboxChanged` notification (`FeedViewController.jukeboxChanged`). This hash-invalidation behavior is a genuine domain rule worth preserving.
- **Cell configurators + size calculators**: `secretdjv3/FeedCellConfigurator.swift` maps `Template` → xib name (two hard-coded dictionaries, phone vs kiosk) and populates cells **by integer view tag**: `CellViewTag` (tags 96–105) is the contract between code and 41 xibs, image views are `viewWithTag(100)`, and label text is delivered as a single server string split on `"\n"` into up to four tag-addressed labels (with a literal `"\n\n\n"` appended as a "trick to always top-align"). `secretdjv3/ContainerCellConfigurator.swift` does the same for nested cells. Sizes are computed in `secretdjv3/FeedCellSizeCalculator.swift` and `secretdjv3/ContainerCellSizeCalculator.swift` — near-duplicate `isKiosk`-forked column math ("perfect number of items" row-fill rounding), with magic numbers and comments like "to match android" and "shouldn't these be the same? Adam 08/12/24".
- **Nested collection views**: horizontal carousels and grids are a `ContainerCollectionViewCell` (`secretdjv3/ContainerCollectionViewCell.swift`) holding its own inner `UICollectionView`, delegating taps back via `ContainerCollectionViewCellDelegate`.
- **Feed diffing**: `secretdjv3/FeedUpdater.swift` computes batch updates between old and new `SectionList`s — but equality is the base64-JSON-string comparison above, and several guard paths just `reloadData()`.
- **Supplementary/extra pieces**: `secretdjv3/SupplementaryViewProvider.swift` (headers/footers, per-template header sizing), `secretdjv3/ExtraContentManager.swift` (a "manager" that builds and animates its own UIView banner, with its rotation timer — and ~80 lines of commented-out constraint code left in place).

The SwiftUI rewrite on this branch already reimplements this engine declaratively (`secretdjv3/SwiftUI/Feed/FeedViewStateBuilder.swift` + section views), which is a good map of what the engine actually does.

#### Dependency access: singletons, with test seams bolted on

There is no composition root and no injection container. Fourteen `static let shared` singletons exist (`grep` evidence): `UserManager` (note: `static var` — replaceable), `AppConfiguration`, `IAPManager`, `TopUpManager`, `SpotifyAuthManager`, `SpotifyAccess`, `SignatureProvider`, `ToastManager` (`sharedInstance`), `NetworkActivityManager`, `PageViewReportingManager`, `SkinManager`, `URLSchemeHandler`, `LocationManager`, `ListenToSong` (`secretdjv3/ListenToSong/ListenToSong.swift`). `FacebookManager` and `ThemeManager` are all-static-function namespaces instead (`secretdjv3/FacebookManager.swift`, `secretdjv3/ThemeManager.swift`). Singletons are reached from anywhere, including from **model objects** — `Section` holds `var userManager = UserManager.shared` and `let appConfig = AppConfiguration.shared` (`secretdjv3/Section.swift`), and singletons construct each other (`TopUpManager.init` wires itself as `IAPManager.shared.appleTopUpDelegate`). Where constructor injection exists it is shallow and ad hoc: `FeedViewController(feedDataProvider:)`, `FeedInteractor(feedActionProvider:)`, `FeedActionProvider(topUpManager:)`. Testability is achieved by `var` properties over small protocols (`SignatureProvision`, `NetworkAccessible`, `Reporter`, `FeedActionProvidable`) that tests overwrite with mocks (`SecretDJTests/SignatureProviderMock.swift`, `SecretDJTests/DummyNetworkAccess.swift`, `SecretDJTests/UserManagerMock.swift`).

`UserManager` (`secretdjv3/UserManager.swift`, 387 lines) is the de facto session god object: current user and venue (with a live NSKeyedArchiver→Codable migration path for both), the keychain password (cached in memory; an empty-string password is deliberately synthesized "to keep the networking layer consistent"), the server token, Spotify username/credentials, affiliate URLs, Crashlytics identity, first-location-fix timestamp, and assorted flags — all backed by `UserDefaults` with a raw-string key enum. Auth is architecturally load-bearing here: every API call signs requests with HMAC-SHA1(token, key: plaintext password) via `SignatureProvider` (`secretdjv3/SignatureProvider.swift`, `secretdjv3/NetworkAccess.swift` `generateGetRequest`), so `UserManager.password` is consulted on effectively every network request.

#### Threading model

Main-thread-by-convention, enforced in exactly one place: `secretdjv3/NetworkAccess.swift` bounces **every** completion back with `DispatchQueue.main.async` (62 `DispatchQueue.main` call sites across the codebase), so all interactors, providers, and VCs assume main-thread delivery and do no synchronization of their own. Deliberate background work is rare: `ToastManager`'s private serial `toastDispatchQueue` (`secretdjv3/ToastManager.swift`), `KioskApplication`'s touch-notification queue (which posts `NotificationCenter` notifications off-main — observers must hop back), and image decode in `secretdjv3/ImageHeader.swift` (`DispatchQueue.global`). Swift concurrency appears only in recent patches (`Task`/`@MainActor` in `secretdjv3/TuneInViewController.swift`, `secretdjv3/KioskTuneInViewController.swift`, `secretdjv3/SpotifyAuthManager.swift`, `secretdjv3/SpotifyAccess.swift`) and throughout `secretdjv3/SwiftUI/`. There is no actor isolation or Sendable discipline anywhere in the legacy code; the rewrite's `@MainActor`-by-default world replaces this whole convention.

#### Communication conventions

Three overlapping mechanisms, roughly by era:

1. **Completion closures** (dominant): all API access classes (`*APIAccess.swift`) and data providers take `@escaping (Result-like enum) -> Void` completions, delivered on main. Weak-self dances use both modern `[weak self]` and older `strongSelf` spellings.
2. **Delegates**: 35 files declare `*Delegate` protocols — cell→VC (`ContainerCollectionViewCellDelegate`), manager→VC (`ExtraContentManagerDelegate`, `VerifyTopUpViewControllerOwnerDelegate`, `PayPalTopUpDelegate`), and flow controllers (`LoginFlowControllerDelegate`). A recurring hazard: `TopUpManager.shared.verifyTopUpDelegate` is a single weak slot reassigned in every `viewDidAppear` (`secretdjv3/FeedViewController.swift`, `secretdjv3/CustomTabBarViewController.swift`).
3. **NotificationCenter**: ~23 post/observe sites. Names are partially centralized as properties on `AppConfiguration` (`notificationJukeboxChange`, `notificationUserDidTouchScreen`, …) but remain raw strings underneath, and `ToastManager` still observes the literal string `"UIKeyboardWillShowNotification"`.

Screen analytics is wired by **method swizzling**: `PageViewReportingManager` swaps `UIViewController.viewDidAppear` at startup (comment: "Swizzling is not very nice - I am sorry", `secretdjv3/PageViewReportingManager.swift`) and derives screen names by string-munging the class description for the `"SecretDJ."` prefix — which silently drops kiosk-module classes.

Navigation is its own convention: a single `UINavigationController` whose root is `CustomTabBarViewController` (`secretdjv3/SceneDelegate.swift`) — a hand-rolled tab bar built from a `UIPageViewController` plus custom buttons (`secretdjv3/CustomTabBar.swift`), with tabs `placesNearby / rabbitFeed / news / profile`. Cross-screen navigation happens via the `FeedAction` enum, via `AppDelegate.mainNavigationController` (a global static), and via "flow controller" NSObjects that own their own `UIWindow`s (`secretdjv3/LoginFlowController.swift`, `secretdjv3/SettingsFlowController.swift`, `secretdjv3/KioskLoginFlowController.swift`). `LoginFlowState`'s raw values are storyboard identifiers — navigation state stringly coupled to Interface Builder.

#### Remaining Objective-C

- `secretdjv3/SecretDJ-Bridging-Header.h` imports three things: `UIImage+ImageEffects.h`, CommonCrypto, and `BDKCollectionIndexView.h`.
- `secretdjv3/BDKCollectionIndexView.h/.m` — a vendored third-party A–Z index strip for collection views, actually used in three places (`secretdjv3/ArtistSearchFeedViewController.swift`, `secretdjv3/KioskSearchArtistListViewController.swift`, and referenced by `secretdjv3/SwiftUI/Search/SearchComponents.swift`). The rewrite needs a SwiftUI replacement for this behavior (fast alphabet scrubbing on artist lists).
- `secretdjv3/UIImage+ImageEffects.h/.m` — Apple's classic blur sample; **zero Swift call sites found**. Dead weight in the bridging header.
- `secretdjv3/CommonConstants.h` — a 2014 `#define` graveyard still compiled via the prefix header (`secretdjv3/secretdj-Prefix.pch`, `GCC_PREFIX_HEADER` still set in `project.pbxproj`). Much of it was already re-transcribed into Swift (`AppConfiguration`, `KioskSizes`, `AppColors`), so values exist **twice**. It also contains live secrets in source: PayPal client IDs (duplicated in `secretdjv3/AppConfiguration.swift` as `PayPalEnvironmentConfig`), a Twitter OAuth consumer key *and secret*, Facebook app id, Spotify client id, and the Heroku token-swap URLs.
- `secretdjv3/SDJCustomPushAnimator.m.trvs`, `secretdjv3/SDJPlacesNearbyViewController.m.trvs` — dead 2014-era ObjC renamed out of the build rather than deleted.

#### Strays and dead things (inventory)

- `IAPManager.swift-old.swift` at the **repo root** — a 281-line Appcoda-tutorial StoreKit manager; the commit history says it was "Renamed out of place file to check was unused. Can be removed" (`git log 64844aed`). The real one is `secretdjv3/IAPManager.swift` (572 lines).
- `SecretDJ copy-Info.plist`, `SecretDJKiosk copy-Info.plist` at the root — stale duplicates of the live Info.plists.
- `Modules/` — an SPM package husk (`Modules/Sources/Core` is empty, no `Package.swift` outside `.build`; only `.swiftpm` user state remains): an abandoned modularization attempt. Vendored checkouts live under `Modules/.build` (ignored per brief). Actual dependencies are two SPM packages: facebook-ios-sdk and firebase-ios-sdk (`secretdj.xcodeproj/project.pbxproj` XCRemoteSwiftPackageReference section).
- `Heroku_SpotifyTokenSwap/` — empty directory, last touched 2024-04-09; the Spotify token-swap service it held is referenced only by URL in `CommonConstants.h`.
- **Three generations of storyboards coexist**: dead `_iPhone`/`_iPad` pairs (Main, Music, Settings, Venues, Directions, Web, Login, PPP, Kiosk_iPad — confirmed never instantiated by the Phase-0 audit in `docs/storyboard-audit.md`), the live "Rewrite" generation (`secretdjv3/StoryBoards/RewriteLogin.storyboard`, `RewriteSettings.storyboard`) plus live Music/Web/Directions/Dialogs and the kiosk set, and the storyboard-free SwiftUI screens. Note both Info.plists still declare `UIMainStoryboardFile: Login_iPhone` (`SecretDJ-Info.plist`, `SecretDJKiosk-Info.plist`) even though `SceneDelegate` builds the window in code and the audit lists Login_iPhone as dead.
- `secretdjv3/MatrixJukeboxLargeCollectionViewCell_ipad.swift` + its xib, whose custom class is still the ObjC-era name `SDJMatrixJukeboxLargeCollectionViewCell_ipad` (`secretdjv3/Cells/iPad/MatrixJukeboxLargeCollectionViewCell_ipad.xib`) — a broken/vestigial pairing.
- Simulated-location `.gpx` fixtures (`Chiswick.gpx`, `Sekforde Street.gpx`, `St. Winifreds Road.gpx`, `North London.gpx`, `Novodington Arms.gpx`) and loose PNGs (`iconTabNearby@2x.png`, `roundPlaceholderAvatarUnisexBackground*.png`) sitting inside the app source folder.
- `secretdjv3/PayPalManager.swift` — only ever instantiated behind `#if PAYPAL_SUPPORTED`, which is defined in **no** build configuration (checked `project.pbxproj`): compiled, shipped, unreachable.
- `FeedInteractor.currentTask` (`secretdjv3/FeedInteractor.swift` line 28) is cancelled but never assigned anywhere — the fetch-cancellation path is a no-op.
- `Photoshop/` and `Paintcode/` (design source files, `SDJAssets.pcvd`) exist at the root; note-and-ignore.
- Mixed project hygiene: `SWIFT_VERSION = 5.0` everywhere, deployment targets inconsistent across configurations (12.0 / 13.0 / 15.6 / 17.0 in different blocks of `project.pbxproj`), `.swiftlint` still excluding a `Pods` directory that no longer exists.

#### Tech-debt inventory — the worst offenders, ranked

What follows is the do-not-carry-forward list, worst first:

1. **`UserManager`** (`secretdjv3/UserManager.swift`) — session god object + plaintext-password-as-signing-key coupling to the network layer; every subsystem reads it, including model objects. The rewrite needs a real session/auth boundary.
2. **Tag-based cell binding and the `"\n"` text protocol** (`secretdjv3/FeedCellConfigurator.swift`, `secretdjv3/ContainerCellConfigurator.swift`, `CellViewTag`) — UI populated via `viewWithTag(101…105)` against 41 xibs, text carried as newline-delimited server strings, alignment hacked with appended `"\n\n\n"`. Completely replaced by typed SwiftUI views; do not port.
3. **`FeedActionProvider` as router-plus-rules-engine** (`secretdjv3/FeedActionProvider.swift`) — builds destination VCs with force-casted storyboard lookups, embeds promotion deep-link business rules and a fire-and-forget analytics API call, force-unwraps `currentUser` at init, and `assertionFailure`s on unexpected server actions. The *routing table* (action type → destination) is domain knowledge to preserve; the shape is not.
4. **Runtime `isKiosk` forking + the parallel `Kiosk*` hierarchy** — two mechanisms for one problem, producing near-duplicate code (compare `secretdjv3/FeedCellSizeCalculator.swift`'s phone/iPad twins and `secretdjv3/TuneInViewController.swift` (835 lines) vs `secretdjv3/KioskTuneInViewController.swift` (306 lines), which duplicate the audio-preview logic). A `fatalError` on unknown bundle ids makes the config untestable by construction.
5. **God view controllers** — `secretdjv3/TuneInViewController.swift` (835 lines: audio preview player, credits/no-credits flow, top-up presentation, skip/blacklist machine-control requests, artist re-query, Spotify hooks) and `secretdjv3/LoginViewController.swift` (763 lines: native + Facebook + Apple sign-in, ASAuthorization plumbing, field validation, keychain). Business logic lives in `@IBAction`s.
6. **The dictionary model layer** (`secretdjv3/Item.swift`, `secretdjv3/Section.swift`, `secretdjv3/SectionList.swift`) — `NSObject` subclasses parsed from `[AnyHashable: Any]`, stringly `custom` bags, `parentSection` back-pointer graph, and `Item.isEqual` via base64-JSON string comparison (which is also what `secretdjv3/FeedUpdater.swift` diffs on). Replace with `Codable` value types and identity-based diffing.
7. **Force-unwrap/force-cast habit** — 53 `as!` casts, ~550 postfix-`!` sites (crude grep), IUO wiring conventions (`weak var viewController: FeedViewControllerInput!`), `UIDevice.current.identifierForVendor!` in `secretdjv3/NetworkAccess.swift`'s init, `window.backgroundColor = UIColor(patternImage: UIImage(named:...)!)` in `secretdjv3/SceneDelegate.swift`. 52 `assert`/`assertionFailure` sites double as the error-handling strategy for unexpected server data.
8. **Swizzled analytics** (`secretdjv3/PageViewReportingManager.swift`) — `viewDidAppear` swizzling plus class-name string parsing for screen names (already misses the kiosk module). The rewrite's Observability pipeline replaces this outright.
9. **`ToastManager`** (`secretdjv3/ToastManager.swift`) — a singleton owning its own always-alive `UIWindow` above alert level, a hand-rolled `Queue<Data>` of pending toasts, keyboard tracking via raw notification-name strings, and commented-out alternative implementations left inline.
10. **Secrets and duplicated constants in source** — `secretdjv3/CommonConstants.h` (Twitter consumer secret, PayPal keys, S3 base URLs) still compiled into both apps via the prefix header, with many values duplicated in Swift; single source of truth exists nowhere.
11. **Deprecated-API pockets** — `secretdjv3/CameraManager.swift` is built on `AVCaptureStillImageOutput` (deprecated since iOS 10) with force-unwrapped CoreGraphics calls; `secretdjv3/AppDelegate.swift` still sets `UIApplication.shared.statusBarStyle`; `UserManager` still round-trips `NSKeyedUnarchiver.unarchiveObject`.
12. **Test asymmetry** — `SecretDJTests/` has genuine coverage (API access classes, models, signature/HMAC, some VCs, JSON fixtures, hand-rolled mocks) but `SecretDJKioskTests/SecretDJKioskTests.swift` is the untouched Xcode template with an empty `testExample` — the kiosk app has effectively zero tests.
13. **Dead code left in place rather than deleted** — `.trvs` files, `IAPManager.swift-old.swift`, `PayPalManager`, dead storyboard generation, unused `UIImage+ImageEffects`, ~80-line commented-out blocks (`secretdjv3/ExtraContentManager.swift`, `secretdjv3/LoginViewController.swift`), 51 `print(` call sites.

#### Worth preserving despite the packaging

Buried inside the debt are behaviors the rewrite must not lose: the location-fix-aware refresh cadence and its race-hazard delay (`FeedViewController.initTimerIfRequired`), the pagination hash → "jukebox changed" invalidation contract (`MusicDigestFeedDataProvider`/`MusicSelectionFeedDataProvider`), top-up resubmission on every screen appearance (`TopUpManager.resubmitPendingTopUps` called from `viewDidAppear`s), the request-signing scheme (HMAC-SHA1 of the server token keyed by password, cached per token/password pair in `SignatureProvider`), the store-config drip-feed where feed responses update affiliate URLs (`UserManager.updateWith(sectionList:)`), the completions-on-main contract, and the kiosk's touch-driven attract-mode reset (`KioskApplication.sendEvent`). The `docs/storyboard-audit.md` liveness table and the SwiftUI `FeatureFlags` bake-in pattern are also directly reusable working practices.

## Tests, tooling, and quality gates

### Overview

The legacy project has one meaningful unit-test bundle (`SecretDJTests/`, 42 Swift files, ~2,370 lines), one empty one (`SecretDJKioskTests/`), aspirational lint/format configs that nothing enforces, **no CI of any kind**, and two manual shell scripts for post-archive dSYM upload. Everything is **XCTest** — there is no Swift Testing, no UI-test target, no snapshot tests, and no code coverage collection (no `codeCoverageEnabled` in either shared scheme under `secretdj.xcodeproj/xcshareddata/xcschemes/`, and no test plans). Both test bundles are app-hosted (`TEST_HOST = .../Secret DJ.app` and `.../Secret DJ Kiosk.app` in `secretdj.xcodeproj/project.pbxproj`), so even pure-logic tests require booting the app in a simulator.

For scale: the app source is ~32,100 lines across 274 Swift files in `secretdjv3/`, with 47 `*ViewController*.swift` files. Exactly one view controller has a test. The tested surface is almost entirely the network/model layer.

### SecretDJTests inventory (42 files: 33 XCTest classes + 9 test doubles, 129 test methods)

#### Test doubles — hand-rolled, synchronous fakes

- `SecretDJTests/DummyNetworkAccess.swift` — the workhorse. Implements the app's `NetworkAccessible` protocol; `resume()` on its `DummyStateControllable` synchronously invokes the request completion with a JSON fixture parsed by `SecretDJTests/FixtureAccess.swift`. Because completion is synchronous, almost no test needs an `XCTestExpectation` (only `SecretDJTests/MoodFeedDataProviderTests.swift` uses one). This is elegant but fragile: assertions inside completion closures would silently never run if the fake ever became async.
- `SecretDJTests/ReportingMock.swift` — captures the last `ReportableEvent` + attributes; used pervasively to assert that each API call fires the right analytics event.
- `SecretDJTests/UserDetailsAPIMock.swift`, `SignatureProviderMock.swift`, `UserManagerMock.swift`, `ControlMock.swift` (subclass-and-override style), `DummySectionProvider.swift`, `ViewControllerTestPreparation.swift` (installs a VC as `keyWindow.rootViewController` and touches `.view` — the deprecated-API "one weird trick" pattern from a 2017 blog post).
- **Fixtures**: 38 real captured server JSON responses — 10 at `SecretDJTests/` root (e.g. `VenueFeed.json`, `ChangeMood.json`, `SkipTrack.json`) and 28 in `SecretDJTests/JSON/` (sign-in, sign-up, top-ups, vouchers, skins, Spotify save, kiosk sign-in, etc.), enumerated in the `Fixture` enum in `FixtureAccess.swift`. Note a latent bug: the enum spells `placesNearby = "PlacesNeaby.json"` while the file on disk is `JSON/PlacesNearby.json`, so that fixture would crash the force-unwrapped bundle lookup if ever used. There is also `SecretDJTests/Location/SecretDJ.gpx`, a simulated central-London location (51.520764, -0.102929) wired into the SecretDJ scheme's LaunchAction (`secretdj.xcodeproj/xcshareddata/xcschemes/SecretDJ.xcscheme`, which also passes `-FIRAnalyticsDebugEnabled`).

#### What the tests cover

1. **API access layer** (the bulk, ~15 classes, fixture-driven): `LoginAPIAccessTests`, `CheckInAPIAccessTests`, `SelectSongAPIAccessTests`, `TopUpAPIAccessTests`, `MachineControlAPIAccessTests`, `SearchAPIAccessTests`, `LikeAPIAccessTests`, `ITunesAPIAccessTests`, `PasswordAPIAccessTests`, `UserDetailsAPIAccessTests`, `AvatarAPIAccessTests`, `SpotifyAPIAccessTests`, `SkinAPIAccessTests` (all under `SecretDJTests/`). Each follows the same two patterns: (a) parse a fixture and assert extracted fields/messages, (b) assert the correct analytics event was reported via `ReportingMock`.
2. **Model parsing from real server JSON**: `ItemTests`, `SongTests`, `PersonTests`, `VenueTests`, `NewsTests`, `SectionListTests` — golden-value assertions of the dictionary-based parsing (image URIs, Spotify URIs, venue lat/lng/properties bitmasks, feed "actions" incl. an Uber-signup deep link in `SectionListTests.swift`).
3. **Persistence**: `SecretDJTests/UserManagerTests.swift` (205 lines, largest file) — round-trips every `UserManager` property (user, venue, password, token, search/page URLs, Spotify credentials, social mask, kiosk auto-lock flag...) and, added on this `refactor` branch (commit `89b96f7f`, "Phase 0"), **NSKeyedArchiver-to-Codable migration tests**: a legacy `SDJPerson`/`SDJVenue` archive blob under the old defaults key must migrate to Codable JSON on first read, retire the old key, and reject empty `personId`/`screenName` on decode. These tests mutate real shared `UserDefaults`/Keychain state (as does `KeychainPasswordItemTests.swift`) rather than injected stores.
4. **Crypto/signing** — the most valuable tiny tests in the repo: `HmacTests.swift`, `SignatureProviderTests.swift`, and the misnamed `LoginViewControllerTests.swift` (it only tests `String.sha1()`) pin known-answer vectors for the server's request-signing scheme (base64-decode token, HMAC-SHA1 keyed with the SHA1-hashed password, base64-encode signature). `NetworkAccessTests.swift` pins the query-encoding contract: `+` and `=` in signature values must percent-encode as `%2B`/`%3D`.
5. **Validation**: `ProfileDetailsValidatorTests.swift` — first/last/user name non-empty and character-set rules, email validity, password minimum 5 chars.
6. **UI-adjacent logic**: `SupplementaryViewConfiguratorTests.swift` (feed header sizing rules: profile-header height multiplier, standard section-header height, zero height for untitled sections), `ColorHexTests.swift` (6- and 8-digit hex parsing), `CameraManagerTests.swift` (aspect-fill sizing), and the single VC test `SettingsChangeDetailsViewControllerTests.swift` (instantiates from the `RewriteSettings` storyboard, taps save, asserts the mock API received the field values).
7. **SwiftUI-rewrite parity spec (new on this branch)**: `SecretDJTests/FeedViewStateBuilderTests.swift` (added in commit `5e19e4e3`, "Phase 2") tests the in-repo SwiftUI feed engine against the same fixtures the UIKit feed parses: hidden sections dropped, `matrixPromotionMedium` containers unwrap to 3-column grids, advert row style, unique/routable item IDs for `ForEach`, unknown-template feeds fall back to a dummy empty section, artist-search sections use a 44pt text-only row style with suppressed headers feeding an A–Z index rail, and the Change Mood slider header replicates UIKit defaults (min 30 / max 60 / initial 60 / granularity 30 when the section carries no custom values). This file is the closest thing the repo has to an executable spec written *for* the rewrite.

#### Dead and hollow tests (do not carry forward)

- `SecretDJTests/MusicAPIAccessTests.swift` — the entire class is commented out; only `import XCTest` compiles.
- `SecretDJTests/TopUpAPIAccessTests.swift` — 4 of 7 tests gutted with bodies commented out ("Commented it out to get it to build. Adam 21/11/23"), including all `topUp()` purchase-verification paths; only voucher redemption and options parsing still assert anything. The IAP verification error contract survives only in comments and fixtures (`JSON/TopUpFail.json`, `TopUpFailRetry.json`, `TopUpSuccess.json`).
- Empty `testExample()` stubs in `MoodFeedDataProviderTests.swift` and the entirety of `SecretDJKioskTests/SecretDJKioskTests.swift`.

### SecretDJKioskTests

`SecretDJKioskTests/SecretDJKioskTests.swift` is the untouched 2017 Xcode template: one empty `testExample()`, nothing else. **The kiosk app has zero real test coverage**; its shared scheme does wire the bundle into the Test action, so `⌘U` runs one vacuous test.

### Reusable spec for the rewrite

The tests worth mining as behavioral documentation, roughly in value order:

1. Signing known-answer vectors (`HmacTests`, `SignatureProviderTests`, `LoginViewControllerTests`) and query-encoding rules (`NetworkAccessTests`) — the exact auth contract with the server, verifiable without a backend.
2. The 38 JSON fixtures — real API response shapes for every endpoint, including exact user-facing server message strings the tests pin verbatim (e.g. voucher expiry and success copy in `TopUpAPIAccessTests`, "no credits" song-request failure in `SelectSongAPIAccessTests`, skip/blacklist/mood confirmations in `MachineControlAPIAccessTests`, kiosk sign-in returning a venue in `LoginAPIAccessTests`).
3. `FeedViewStateBuilderTests` — server-driven-feed rendering semantics (section visibility, container unwrapping, grid columns, mood-slider defaults).
4. `UserManagerTests` migration section — the persisted-state migration contract a rewrite must honor for existing installs.
5. `ProfileDetailsValidatorTests` — form validation rules.
6. The analytics-event-per-endpoint mapping asserted across every `*APIAccessTests` file.

### Lint/format configuration (present, but enforced by nothing)

- `.swiftlint` — **unusual filename**: SwiftLint auto-discovers `.swiftlint.yml`, so this file is inert unless invoked as `swiftlint --config .swiftlint`. Nothing in the repo does: no build phase (`project.pbxproj` has no SwiftLint/SwiftFormat script phases), no git hooks (`.git/hooks/` has only samples), no CI. Content: xcode reporter, excludes `Pods` (which no longer exists — CocoaPods was removed in commit `42caee5d`), disables line-length/naming rules, opts into `force_unwrapping`, `private_outlet`, `private_action`, `weak_delegate` etc., escalates ~40 rules to `error`, caps type bodies at 300/400 and files at 400/600 lines.
- `.swiftformat` — thorough, deliberately curated: `--disable all` then ~90 individually enabled rules with comments; Swift version 5.10, **tabs (width 4)**, max width 120, K&R braces, `--self init-only`, testable-last import grouping. Commit history shows it was applied once as a bulk pass (`ef98a999` "Added config files..." then `a738da5e` "Apply standard formatting to code").
- `.swift-format` — Apple swift-format config mirroring the same style (tabs, 120 cols) for Xcode's built-in formatter, with strict rules (`NeverForceUnwrap`, `NeverUseForceTry`, `AllPublicDeclarationsHaveDocumentation`) that the codebase plainly does not satisfy — aspirational.
- `.editorconfig` — LF, UTF-8, tabs width 4, trim trailing whitespace.

Takeaway for the rewrite: the *style intent* (tabs, 120 cols, no force-unwrap) is documented and worth porting, but treat every config here as never-enforced; the new repo's hook-driven SwiftFormat/SwiftLint setup is a strict upgrade.

### CI, build phases, and release tooling

- **No CI evidence anywhere**: no `.github/`, fastlane, Dangerfile, Makefile, Jenkins/Bitrise/CircleCI files.
- `project.pbxproj` shell-script phases (both app targets): (1) a PlistBuddy build-number auto-increment on every build, and (2) a "Upload symbols to Firebase / Crashlytics [MUST BE LAST]" phase running the firebase-ios-sdk `Crashlytics/run` script from SPM checkouts. The script text reads `"$<BUILD_DIR%/Build/*}/SourcePackages/..."` — that `$<...}` expansion looks corrupted (inference: should be `${BUILD_DIR%/Build/*}`); it is gated to `runOnlyForDeploymentPostprocessing = 1` so it would only bite on archive builds. Verify before trusting.
- **dSYM upload scripts** (repo root): `upload-phone-dsyms-to-firebase-crashlytics` and `upload-kiosk-dsyms-to-firebase-crashlytics` — identical except for the `GoogleService-Info.plist` they point at (`secretdjv3/Firebase/phone/` vs `secretdjv3/Firebase/kiosk/`, confirming two separate Firebase apps). Each locates `upload-symbols` by searching `~/Library/Developer/Xcode/DerivedData` for the SPM firebase-ios-sdk checkout, then uploads a manually supplied xcarchive dSYM path. Entirely manual, machine-specific release hygiene — replace with CI in the rewrite.

### docs/storyboard-audit.md — prior migration planning

`docs/storyboard-audit.md` is a "storyboard liveness audit" dated 2026-06-10, made for the in-repo SwiftUI migration ("Phase 0"). It inventories every `UIStoryboard(name:)` call site and declares a storyboard live iff instantiated or the launch screen. Live: `RewriteLogin`, `RewriteSettings`, `Music`, `Web`, `Directions`, `Dialogs`, `LaunchScreen` (phone) and `Kiosk`, `KioskLogin`, `KioskMusic` (kiosk), each with exact file:line call sites. Dead (bundled but never instantiated, "safe to remove... once one release has shipped"): 15 legacy `_iPhone`/`_iPad` variants (Login, Main, Music, Settings, Venues, Directions, Web, PPP, Kiosk_iPad). It references a phased deletion plan in `/Users/nick/.claude/plans/declarative-splashing-lemur.md`, which is outside the repo. For the greenfield rewrite this doc is the authoritative list of which of the 26 storyboards actually carry behavior worth reading.

### .claude directory

`.claude/` contains only `settings.local.json`: a Claude Code permissions allowlist (grep, `pod install`, `git add/commit`, WebSearch, reading `/tmp/force_unwraps_report.txt`). No skills, no CLAUDE.md, no hooks — evidence the refactor branch was Claude-assisted (a force-unwrap audit apparently happened in a prior session) but nothing reusable.

### Assessment: how much is actually under test

By any measure, thin: ~2,370 test lines against ~32,100 app lines (~7%), 129 test methods, one of 47 view-controller files touched, zero kiosk coverage, zero UI/snapshot tests, no coverage measurement to know better. What *is* tested is the right layer — the server contract (parsing, signing, encoding, error messages, analytics events) via a disciplined fixture+fake pattern that has aged well — and the fixtures themselves may be the single most reusable test asset. The rot is visible at the edges: tests commented out in 2023 to keep the build alive, template stubs never filled, shared-state mutation of real UserDefaults/Keychain, and an entire quality-gate toolchain (SwiftLint/SwiftFormat/swift-format configs) that was written down but never wired to anything. The rewrite should port the *fixtures and pinned contracts*, not the test code or the tooling setup.

## Refactor branch: the in-flight modernization

### Branch topology: what master and refactor each represent

- **`master`** is effectively frozen in April 2024. Its tip, `befaef53 "ios 5.1.3 merge"`, is a *single-parent* commit (not a true merge) that squashed part of the 5.1.3 work onto the v5.1.2 release (`65689c55`) — and it even re-added a stray `…conflicted copy 2024-03-16.pbxproj` file. Master does **not** contain the 5.1.4 release or any modernization.
- **`refactor`** (tip `4fef6ac9`) branched from the same v5.1.2 commit but carries the *full* commit-by-commit history: the real 5.1.3 work, the v5.1.4 phone and kiosk releases (`64556f10`, `eb01c48d`), the last original-developer commit (`0febf4f0 "tidy up"`, June 2025), and then the 2026 modernization campaign. `git diff master...refactor --stat` is 1,465 files, +33.5k/−172.5k lines — the deletions are overwhelmingly vendored Pods and binary frameworks being removed.
- **Conclusion for the rewrite team: `refactor` is the authoritative branch.** Master is only useful as a pre-modernization snapshot; everything of behavioral value on master is also on refactor. The working tree on refactor is clean.

### Pre-phase commits (build hygiene and dependency modernization, Mar–May 2026)

Chronological, all on `refactor`:

| Commit | What it delivered |
|---|---|
| `ef98a999` + `a738da5e` (Mar 2026) | Added `.swiftformat`, `.swiftlint`, `.swift-format`, `.editorconfig`, then a whole-codebase SwiftFormat pass (290 files, ±25k lines). Beware when diffing across it. |
| `13d9ae29` | Swift 5.7 `guard let self` shorthand adoption. |
| `d3f6f681` | **StreamingKit removed**; preview playback in `secretdjv3/TuneInViewController.swift` / `secretdjv3/KioskTuneInViewController.swift` moved to AVFoundation. |
| `49919af7` | Critical follow-up: the backend serves preview audio from S3 with a custom `.pbz` extension and a generic Content-Type, which **AVPlayer refuses to decode (error −11828)**. Fix: `URLSession` download + `AVAudioPlayer(data:)`, which decodes bytes regardless of headers, with slider bounds set up front. This is a **backend contract quirk the rewrite must preserve**. |
| `d7fb6445` | **Spotify auth rewritten**: the vendored fat-binary `Spotify.framework` (no arm64-sim slice, broke Apple Silicon simulator builds) replaced with `ASWebAuthenticationSession` + **PKCE OAuth**, tokens in the Keychain; the server-side token-swap/refresh endpoints became unnecessary. |
| `2809d9c7` | Firebase (Analytics + Crashlytics) moved from CocoaPods to SPM; imports changed to `FirebaseCore`; dSYM upload scripts repointed at `DerivedData/SourcePackages`. |
| `0fb3d356` | **Spartan (Spotify Web API pod) replaced** by a small in-tree URLSession + Codable + async/await client covering the seven endpoints actually used (`secretdjv3/SpotifyAPI.swift`); `SpotifyAccess` flattened from recursive callbacks to async. |
| `42caee5d`, `6059ce15`, `10fffb85` | **CocoaPods fully removed** — Podfile, Pods dir, `[CP]` phases, xcconfig references all gone; kiosk target fixed up. Everything is now SPM or in-tree. |
| `d6dd0a19` | `Localizable.strings` (241 keys) migrated to a **String Catalog**, `secretdjv3/Localizable.xcstrings` (English-only). |
| `570788df` | **UIScene lifecycle adopted for both targets**: new `secretdjv3/SceneDelegate.swift` and `secretdjv3/KioskSceneDelegate.swift`, scene manifests in both Info.plists, window setup moved out of the AppDelegates, login flow controllers updated. Commit message flags it as a checkpoint before the SwiftUI phases. |

### Phase 0 — iOS 17 floor, Codable persistence, build hygiene (`89b96f7f`)

No behavior change, per its own message ("120/120 tests pass"):
- SecretDJ + SecretDJTests deployment target raised to **iOS 17.0** (kiosk deliberately left at **15.6** — confirmed in `secretdj.xcodeproj/project.pbxproj`); armv7 `VALID_ARCHS` and stale `ENABLE_BITCODE` removed.
- `secretdjv3/Person.swift` and `secretdjv3/Venue.swift` gained **Codable alongside NSCoding**; `secretdjv3/UserManager.swift` now persists them as JSON under new UserDefaults keys and **migrates the legacy NSKeyedArchiver blobs exactly once on first read** (tests in `SecretDJTests/UserManagerTests.swift`). The rewrite inherits users whose devices hold either format.
- Dead vendored `Fabric.framework` copies deleted; iOS-15 availability guards dropped in the ListenToSong sheet; two stale assertions fixed in `SecretDJTests/SupplementaryViewConfiguratorTests.swift` (the suite had been unrunnable since the 2023 reskin).
- **`docs/storyboard-audit.md`**: a liveness audit of every `UIStoryboard(name:)` call site — 10 live storyboards (with exact call sites) and 16 dead ones bundled but never instantiated. Valuable map for the rewrite; note it references a deletion plan at `/Users/nick/.claude/plans/declarative-splashing-lemur.md`, which is *not in the repo*.

### Phase 1 — SwiftUI foundation + Settings flow (`4107fb37`)

Introduced `secretdjv3/SwiftUI/` as an Xcode **`PBXFileSystemSynchronizedRootGroup`** (objectVersion 77) listed in `fileSystemSynchronizedGroups` of the **SecretDJ target only** (`secretdj.xcodeproj/project.pbxproj` line ~2818) — so the kiosk target *never compiles any SwiftUI file*, and later phases add files with zero project edits.

Foundation pieces (all still present at tip):
- `secretdjv3/SwiftUI/Theme/SDJTheme.swift` + `SDJButtonStyle.swift` — every colour/font/spacing value is **computed from the existing `AppColors` / `StyleKit2023` / `FontConfig`**, so UIKit and SwiftUI can't drift while both exist (including pressed/disabled pill-button darkening).
- `secretdjv3/SwiftUI/Core/FeatureFlags.swift` — the flag mechanism (see below).
- `secretdjv3/SwiftUI/Core/RemoteImage.swift` — async image view preserving `UIImageView+LoadImage` semantics (`.returnCacheDataElseLoad`, fade-in only on cache miss).
- `secretdjv3/SwiftUI/Bridge/HostedScreen.swift` (`HostedScreenViewController<Content>: UIHostingController`, forces `overrideUserInterfaceStyle = .dark`) + `secretdjv3/SwiftUI/Bridge/UIKitNavigator.swift` (a `FeedNavigating` protocol; SwiftUI screens never touch UIKit navigation directly — they emit the same `FeedAction` routes the UIKit feed engine uses).

Converted flow: `secretdjv3/SwiftUI/Settings/` (SettingsScreen hub, ChangeDetailsScreen, ChangePasswordScreen, RequestDeleteAccountScreen) with explicit behavior parity: `ProfileDetailsValidator` rules, **SHA1 password hashing**, ToastManager errors, and *reuse of the UIKit gender/photo screens* from `RewriteLogin.storyboard` with `SettingsFlowController` as delegate (`secretdjv3/SwiftUI/Settings/SettingsScreen.swift`). Networking untouched — `secretdjv3/SwiftUI/Services/SettingsServices.swift` is thin `withCheckedThrowingContinuation` async wrappers over the existing completion-handler `UserDetailsAPIAccess`/`RequestDeleteAccountAPIAccess` (HMAC signing etc. unchanged), added screen-by-screen by design.

Swap point: the edit button in `secretdjv3/ProfileFeedViewController.swift` (~line 113), guarded by `#if !SECRET_DJ_KIOSK` + `FeatureFlags.swiftUI(.settings)`; the `RewriteSettings.storyboard` path remains as fallback.

### Phase 2 — SwiftUI feed engine + Change Mood pilot (`5e19e4e3`)

The heart of the migration. The legacy app is feed-driven (server-described sections/items rendered by a VIP-ish `FeedViewController` + `FeedInteractor` + `FeedActionProvider` + per-screen `FeedDataProvider`s). Phase 2 rebuilt only the *view* layer:

- `secretdjv3/SwiftUI/Feed/FeedScreenModel.swift` — a `@MainActor @Observable` class that **adopts `FeedViewControllerInput`**, so `FeedInteractor`, `FeedActionProvider` and every `FeedDataProvider` run completely unmodified. It replicates, with commit-documented parity: adaptive polling (3s until 12s after first location fix, then 20s — the "bug #181" rule) as a `.task`-scoped loop that cancels on disappear; pull-to-refresh over the same fetch path via a stored `CheckedContinuation`; pagination armed over the trailing 15 rows (UIKit prefetched at 2000pt ≈ 17 rows); `FeedUpdater.appendTo` merge semantics in `show(nextPage:)` (including the container/inner-section case); `ActionBarButtonProvider` bar buttons applied to the hosting controller's navigation item.
- `secretdjv3/SwiftUI/Feed/FeedViewState.swift` + `FeedViewStateBuilder.swift` — immutable per-cell view-models built once at parse time; **cell identity = `Item.base64Dictionary`, the same identity `FeedUpdater` diffs on**. Server "container" sections are unwrapped (their single child section parsed flat) with no shared-parsing changes. The template→layout table (rows / fixed-height `LazyHStack` carousels / 4-3-2-column `LazyVGrid` grids) was lifted from `FeedCellConfigurator` + `FeedCellSizeCalculator`.
- `secretdjv3/SwiftUI/Feed/FeedView.swift` — one `ScrollView` + outer `LazyVStack(pinnedViews: [.sectionHeaders])`; concrete section body types, deliberately **no `AnyView`**; pinned 64pt header strips matching `StickyHeaderLayout`'s pinning of only the bottom `SectionHeaderHeight` band.
- Pilot screen: `secretdjv3/SwiftUI/Screens/ChangeMoodScreen.swift` + `secretdjv3/SwiftUI/Feed/Headers/MoodSectionHeader.swift` (`MoodHeaderController`, `@Observable`) replicate the mood slider header exactly: slider min/max/default/granularity read from the section's `custom` dict (defaults 30/60/60/30), granularity snapping, Hours/Mins readout quirks, `CHANGE THE MOOD` via the unchanged `MachineControlAPIAccess`, and the pop-back-to-jukebox-menu rule (`UIKitNavigator.popIfPrevious(is:)`).
- Swap point: `secretdjv3/FeedActionProvider.swift` `actionJukeboxMachineControl` (`#if !SECRET_DJ_KIOSK` + `FeatureFlags.swiftUI(.changeMood)`).
- Tests: `SecretDJTests/FeedViewStateBuilderTests.swift` (7 tests over the existing `VenueFeed`/`StyleInfo-Short`/`ControlItem` JSON fixtures). Also added the Xcode Cloud manifest (`secretdj.xcodeproj/project.xcworkspace/xcshareddata/xcodecloud/manifest.json`) and build-number bumps. "127/127 tests pass."

### Phase 3 — Music search stack (`4bb64732`)

Converted the search flow behind `FeatureFlags.swiftUI(.musicSearch)`:
- `secretdjv3/SwiftUI/Screens/MusicSearchScreen.swift` replaces `SearchContainerViewController` (storyboard id `MusicSearch` in `Music.storyboard`): ARTISTS|SONGS half-pill tab pair over a swipeable `TabView(.page)`, matching the `UIPageViewController` behavior.
- `secretdjv3/SwiftUI/Search/ArtistSearchController.swift` (`@Observable`): one-shot A–Z fetch through the shared feed pipeline; **local** filtering via the unchanged `ArtistSearchFeedInteractor` (filtered results bypass the full feed path via `FeedScreenModel.display(sectionList:)`, parity with `show(filteredSectionList:)`); headers suppressed, their titles feeding a SwiftUI `SectionIndexStrip` (replacing the `BDKCollectionIndexView` pod-era A–Z rail) that jumps via `FeedView`'s new `scrollRequest` binding.
- `secretdjv3/SwiftUI/Search/SongSearchController.swift`: remote search through the unchanged `SongSearchFeedInteractor` incl. its stale-result suppression; empty term blanks the list; `FeedScreenModel` conforms to `SongSearchFeedViewControllerInput` for free.
- `SongsForArtistScreen` replaces the bare `FeedViewController` pushed for multi-song artists; **single-song artists and song taps still push the UIKit TuneIn screen** — routes unchanged. `SearchTextField` mirrors `CustomTextField`; keyboard dismissed on scroll (`.scrollDismissesKeyboard(.immediately)`).
- Swap points: `secretdjv3/FeedActionProvider.swift` `actionLaunchSearch` (~line 150) and the multi-song-artist branch (~line 263). MusicSelection/JukeboxMenu were *deliberately deferred* ("Phase 4: the selection screens are pages inside the jukebox digest pager"). "129/129 tests pass."

### The tip commit `4fef6ac9 "some strings"`

Small and slightly unfinished-looking: a build-number bump (5284→5287 in `SecretDJ-Info.plist`) plus **Xcode's automatic string-catalog extraction of the raw English literals the Phase 2/3 SwiftUI code introduced** into `secretdjv3/Localizable.xcstrings`: `"CHANGE THE MOOD"`, `"Hour"`/`"Hours"`, `"Mins"`, `"Play for how long?"`, `"%lld"`, `"00"`, and an empty `""` key — all with auto-generated comments and **no localizations**. It documents a real regression pattern: legacy code uses `NSLocalizedString` keys, but the new SwiftUI views hard-code English literals (see `secretdjv3/SwiftUI/Feed/Headers/MoodSectionHeader.swift` lines 102–160, and titles like `"Change Your Settings"`/`"Search"` in `SettingsScreen.swift`/`MusicSearchScreen.swift`, most of which aren't in the catalog at all). The app was English-only anyway, but the rewrite should not copy this pattern.

### The feature-flag mechanism

`secretdjv3/SwiftUI/Core/FeatureFlags.swift` — deliberately tiny:
- `enum Screen: String { case settings, changeMood, musicSearch }`
- Compiled default: `defaultsOn` currently contains **all three** (SwiftUI ships on by default).
- A `UserDefaults.standard` bool under key `"swiftui.<screen>"` overrides the compiled default — an instant, per-screen kill switch without a rebuild.
- Every check site is additionally wrapped in `#if !SECRET_DJ_KIOSK`, and the SwiftUI folder isn't even compiled into the kiosk target, so the kiosk is doubly insulated.
- This is a *local* flag system — no remote config; flipping a screen off for users in the field would require a release (or the UserDefaults override, which nothing in the UI exposes — inference: it's a debug/`defaults write` affordance).

### Quality and patterns of the SwiftUI code

Honest assessment for the rewrite team:
- **Modern patterns**: `@Observable` (not `ObservableObject` — zero `@Published`/`@StateObject` in `secretdjv3/SwiftUI/`), `@ObservationIgnored` for non-UI state, `@MainActor` models, `@State`-owned models in screen structs, `@Bindable` in child views, `.task`-scoped structured concurrency for polling, `withCheckedContinuation` bridges over legacy callback APIs, no AnyView, immutable view-state built off the view path. The architecture is roughly MV-with-screen-models (screen model adopting the legacy VIP "view" seam) rather than textbook MVVM.
- **Caveat**: the project still compiles in **Swift 5 language mode** (`SWIFT_VERSION = 5.0` throughout `project.pbxproj`), so none of this is checked under Swift 6 strict concurrency; `MainActor.assumeIsolated` is used at the UIKit factory seams (`ChangeMoodScreenFactory`, `MusicSearchScreenFactory`) because `FeedActionProvider` routing is nonisolated-but-main-thread.
- **Migration scaffolding, not rewrite code**: much of it exists to reproduce UIKit quirks bit-for-bit (2000pt prefetch lead, 64pt pinned strips, `Item.base64Dictionary` identity, `show(extraContent:)` left as a stub until the venue/now-playing phase). The *parity notes in the file headers and doc comments are themselves a specification* of legacy behavior — arguably the most valuable artifact on the branch for the greenfield team.
- Tests are **XCTest**, not Swift Testing (`SecretDJTests/FeedViewStateBuilderTests.swift`), and only the state builder is directly covered; screen models rely on the untouched interactor/API tests. `SecretDJKioskTests/` is a single near-empty file.

### How SwiftUI coexists with UIKit

One pattern throughout: UIKit owns navigation. A flag-gated swap point constructs a `HostedScreenViewController` (a `UIHostingController` that wires a `UIKitNavigator` in as `FeedNavigating`) and pushes it on the existing `UINavigationController`; SwiftUI screens navigate by asking the navigator to `perform(_: FeedAction)` — pushing further UIKit *or* hosted-SwiftUI controllers — plus `pop()`/`popIfPrevious(is:)` and tab switches through `CustomTabBarViewController`. Legacy singletons (`UserManager.shared`, `ToastManager.sharedInstance`, `TopUpManager.shared`) are used directly from the models. SwiftUI even pushes legacy storyboard VCs mid-flow (gender/photo screens from `SettingsScreen.swift`).

There was also one **pre-refactor SwiftUI island**: `secretdjv3/ListenToSong/ListenToSong.swift` (Nov 2024, original developer) — a bottom-sheet flow for listening on Apple Music/Spotify/YouTube, hosted from UIKit; the phases generalized its hosting pattern.

### What remains UIKit-only (at refactor tip)

Everything not listed above: login/onboarding (`RewriteLogin.storyboard` + `LoginFlowController`), the tab bar shell (`CustomTabBarViewController`), venue feed / now-playing / profile feeds, TuneIn (the actual song-request screen, `secretdjv3/TuneInViewController.swift`), jukebox menu + music selection digest pager, top-ups/IAP (`AvailableTopUpsViewController`), web views, directions/map, dialogs — and the **entire kiosk target**, which has no SwiftUI at all and still targets iOS 15.6. The codebase still carries 26 storyboards and 41 xibs; per `docs/storyboard-audit.md` 16 storyboards are dead resources. Comments in the code name the intended future phases: Phase 4 (MusicSelection/JukeboxMenu), Phase 6 (login incl. gender/photo screens), Phase 7 (TuneIn) — the plan document itself is outside the repo.

### Tech debt on this branch worth NOT carrying forward

- Hard-coded English literals in SwiftUI views instead of localization keys (see the `4fef6ac9` discussion above).
- Swift 5 language mode with manual `MainActor.assumeIsolated` seams; singletons reached directly from `@Observable` models.
- Dead files still in-tree: `IAPManager.swift-old.swift` at repo root, dead storyboards awaiting the audit's deletion plan, `docs/storyboard-audit.md`'s reference to a machine-local plan path.
- Dual persistence (Codable + legacy NSCoding migration path in `UserManager.swift`) — the rewrite needs the *migration*, not the NSCoding half.
- The feed engine's pixel-parity constraints (2000pt prefetch ≈ 15-row arming, 64pt pinned strips, base64-dictionary identity) are UIKit-era artifacts; the rewrite should preserve the *behaviors* (adaptive 3s/20s polling, pagination-append semantics, container unwrapping) but not the magic numbers' provenance.

## Gaps and cross-checks

The ten sections are substantially complete; a file-by-file sweep of `secretdjv3/` against them found no missed *major* feature, but several smaller features, cross-cutting absences worth stating as facts, and five previously open questions that the code does answer.

#### Features and files the sections missed

**The venue map screen.** The consumer app's first tab is Places Nearby (`secretdjv3/PlacesNearbyFeedViewController.swift`), and it carries a map bar button (gated by `MapConfig.showMap = true`, `secretdjv3/AppConfiguration.swift:115-117`) that pushes a real `MKMapView` screen: `secretdjv3/VenueMapViewController.swift` fetches the `placesNearby` feed, drops `VenueAnnotation` pins (`secretdjv3/VenueAnnotation.swift`), shows the user's location, and zooms to fit. The tab also overlays a full-screen `LocationPermissionDeniedView` (with an open-Settings deep link) whenever location is denied, re-checking on every foreground (`PlacesNearbyFeedViewController.updateViewForLocationPermission`). No section mentioned the map or the permission-denied overlay; both are user-visible behavior to preserve. (Note: `secretdjv3/JukeboxMap.swift`, despite the name, is not geographic — it is a jukebox↔view-controller bidirectional lookup for the jukebox pager.)

**An iOS Settings-app pane (`Settings.bundle`).** `secretdjv3/Settings.bundle/Root.plist` publishes two toggles in the system Settings app: "Stay signed-in" (`KeepSignedIn`, default on) and "Disable Auto-Lock" (`DisableAutoLock`, default off). Investigated status:
- `DisableAutoLock` is live in **both** apps: `secretdjv3/SceneDelegate.swift:62` and `secretdjv3/KioskSceneDelegate.swift:71` each set `UIApplication.shared.isIdleTimerDisabled` from it on activation. Operationally important for the kiosk: the default is *false*, so a pub iPad will auto-lock unless staff flip this switch in the iOS Settings app — this is the only screen-lock control in the codebase.
- `KeepSignedIn` is **dead**: `UserManager.keepSignedIn` (`secretdjv3/UserManager.swift:249-257`) has no consumer anywhere — the toggle does nothing. Do not carry it forward.

**The server-driven Uber/taxi loop.** Two halves that individual sections each touched but never joined: `URLSchemeHandler` (`secretdjv3/URLSchemeHandler.swift`) computes a `FeatureBitMask` of installed apps (facebook=1, twitter=2, uber=4, instagram=8) that is sent to the server as the implicit `appmask` parameter on every request (`secretdjv3/NetworkingParameterProvider.swift:82-86`); the server can then respond with `ActionType.launchUberApp = 100` / `.launchUberSignup = 101` actions carrying a server-supplied URL that the client just opens (`secretdjv3/FeedActionProvider.swift:54-61`), and with a `hailTaxi = 200` toolbar button (`ActionButton`, `secretdjv3/Action.swift:33-38`) rendered with the `iconTaxi` asset (`secretdjv3/ActionBarButtonItem.swift:32-33`). So "which ride-hail app is installed" is a client→server signal, and "offer a taxi home" is a server→client feature. The rewrite must keep `appmask` in the API contract or knowingly drop this.

**The two vendored Objective-C components, identified.** The "couple of ObjC files" are: `secretdjv3/BDKCollectionIndexView.h/.m` — a third-party A–Z index strip used by artist search in both apps (`secretdjv3/ArtistSearchFeedViewController.swift:17`, `secretdjv3/KioskSearchArtistListViewController.swift:18`), already given a SwiftUI parity replacement (`SectionIndexStrip` in `secretdjv3/SwiftUI/Search/SearchComponents.swift`) — and `secretdjv3/UIImage+ImageEffects.h/.m` (Apple's blur sample code).

**Deprecated network-activity spinner plumbing.** `secretdjv3/NetworkAccess` posts `NetworkTaskCreated`/`NetworkTaskCompleted` notifications (`secretdjv3/AppConfiguration.swift:109-112`) consumed by `secretdjv3/NetworkActivityManager.swift`, instantiated in both app delegates (`secretdjv3/AppDelegate.swift:66`, `secretdjv3/KioskAppDelegate.swift:55`), which toggles `UIApplication.isNetworkActivityIndicatorVisible` — a no-op since iOS 13. Pure debris; do not carry forward.

**GPX location fixtures ship inside both app bundles.** Five GPX waypoint files at `secretdjv3/` root (`Chiswick.gpx`, `North London.gpx`, `Novodington Arms.gpx`, `Sekforde Street.gpx`, `St. Winifreds Road.gpx` — each a named pub waypoint, e.g. "Brouhaha" in `secretdjv3/Chiswick.gpx`) plus `SecretDJTests/Location/SecretDJ.gpx` are in the **Resources build phases of both app targets** (`secretdj.xcodeproj/project.pbxproj` lines 40-43, 57-63, 95). They are Xcode location-simulation fixtures that have been shipping to the App Store inside the .app for years. Debris; don't port.

#### Cross-cutting absences, now confirmed as facts (repo-wide greps of `secretdjv3/`)

- **No inbound deep links or universal links.** The consumer app registers the `secretdj` URL scheme (`SecretDJ-Info.plist` CFBundleURLSchemes) but its only use is as the Spotify OAuth callback constant (`secretdjv3/AppConfiguration.swift:98`, consumed inside `ASWebAuthenticationSession`); both scene delegates forward every incoming URL verbatim to the Facebook SDK and route nothing themselves (`secretdjv3/SceneDelegate.swift:44-46,67-75`, `secretdjv3/KioskSceneDelegate.swift:53-55`). No associated-domains entitlement exists (`Secret DJ.entitlements` contains only Sign in with Apple and keychain groups), and no `NSUserActivity`/`continue userActivity` handler exists.
- **No reachability monitoring** — zero hits for `NWPathMonitor`/`SCNetworkReachability`/`Reachability`; offline handling is purely per-request error paths.
- **No App Store review prompting** — zero hits for `SKStoreReviewController`/`requestReview`.
- (Corroborating the monetization section: zero hits for `UNUserNotificationCenter`/`registerForRemoteNotifications` — genuinely no push.)

#### Open questions from other sections, answered from the code

1. **Sign in with Apple on the kiosk: entitled but unreachable.** All six build configurations of both app targets point at the same `CODE_SIGN_ENTITLEMENTS = "Secret DJ.entitlements"` (`secretdj.xcodeproj/project.pbxproj` lines 3868, 3970, 4075, 4179, 4402, 4504), so the kiosk ships the applesignin entitlement and the `com.c-burn.secretdj` keychain group. But the only `ASAuthorization` code in the codebase is in `secretdjv3/LoginViewController.swift` (consumer login screen); the kiosk flow (`KioskLoginFlowController` → `KioskLoginViewController`/`KioskSigningInViewController`) contains no Apple-sign-in reference. The entitlement is vestigial on the kiosk — an artifact of sharing one entitlements file.
2. **`checkunique` is dead.** The only occurrence in the entire repo (including the retired `.trvs` Objective-C) is the enum case itself, `case screenNameCheck = "checkunique"` at `secretdjv3/NetworkingParameterProvider.swift:28`. No caller exists.
3. **`MatrixJukeboxLargeCollectionViewCell_ipad` is dead code**, independent of its xib class-name mismatch: `secretdjv3/ContainerCellConfigurator.swift` maps `.matrixJukeboxLarge` to `"KioskMatrixJukeboxLargeCollectionViewCell"` on kiosk (line 31) and `"MatrixJukeboxLargeCollectionViewCell"` on phone (line 48); nothing anywhere registers or dequeues the `_ipad` variant (`secretdjv3/MatrixJukeboxLargeCollectionViewCell_ipad.swift`, `secretdjv3/Cells/iPad/MatrixJukeboxLargeCollectionViewCell_ipad.xib`).
4. **The first-run `".deleteAccountRequested"` write is a typo — and the typo is load-bearing.** `UserManager.init` writes `true` to the *literal* string keys `".firstRun"` and `".deleteAccountRequested"` on first run (`secretdjv3/UserManager.swift:286-290`), while the real property reads/writes the enum key `"DeleteAccountRequested"` (`secretdjv3/UserManager.swift:37, 271-280`). Crucially, if that first-run write ever hit the real key, `CustomTabBarViewController` would see `deleteAccountRequested == true` on every fresh install and show the blocking alert + `exit(0)` (`secretdjv3/CustomTabBarViewController.swift:36, 90`) — bricking the app for all new users. The rewrite must simply not port this write; do not "fix" it by unifying the keys.
5. **The legacy `"userId"` UserDefaults key has no writer anywhere in this repo**, including the `.trvs` Objective-C remnants (repo-wide grep). `Person`'s `"userId"` usages (`secretdjv3/Person.swift:85, 133`) are NSCoding keys *inside* archived blobs, not UserDefaults keys. The recovery path at `secretdjv3/UserManager.swift:90` can therefore only ever fire for installs whose defaults were written by a pre-2017 release — confirming it as a migration path that a greenfield app can drop.
6. **The News tab's retirement mechanism is visible**: `TabBarConfigurationProvider.allTabs` still fully constructs four `TabConfiguration`s — Places Nearby, Activity ("Buzz" icons), News, Profile — and then returns only three, silently discarding the News one (`secretdjv3/TabBarConfigurationProvider.swift:18-63`). The definitive shipped consumer tab set is: **Places Nearby, Activity, Profile**. (Whether News is meant to return remains a product question, but "built and deliberately excluded from the return array" is the code's answer.)

#### Minor clarifications

- `PPPCollectionViewCell` (`secretdjv3/PPPCollectionViewCell.swift`) is the feed cell for the `.topUp` template in **both** apps' nib maps (`secretdjv3/FeedCellConfigurator.swift:53, 70`) — i.e., the top-up purchase rows; the "PPP" name (and `PPP_iPhone.storyboard`, dead) is legacy naming ("pay-per-play", inferred) that the monetization section's readers should be able to connect to the top-up UI.
- `secretdjv3/Queue.swift`, the hand-rolled two-stack FIFO, has exactly one consumer: the toast queue (`secretdjv3/ToastManager.swift:25`).
- `secretdjv3/en.lproj/InfoPlist.strings` exists but is empty of entries — no localized Info.plist values to migrate.

## Open questions

Things the code alone could not answer, by analysis area — worth resolving
with the product owner before the corresponding rewrite work starts.

**Project and build configuration**

- Whether the Ad Hoc kiosk bundle id com.c-burn.kiosk (team 64422L3U8R) is still a live distribution channel or a dead config — nothing in the repo says which is actually deployed to pubs.
- Whether Sign in with Apple (declared in the shared entitlements) is actually exercised by the kiosk app, or only by the consumer app.
- Why the kiosk uses UIMainStoryboardFile = Login_iPhone despite being iPad-only — could be a harmless leftover since a scene delegate is also declared, but runtime behavior wasn't verified.
- Whether Xcode Cloud CI (manifest for the 'Secret DJ' target) is still active — the manifest proves configuration, not current use.
- The intended contents of the empty Modules/Sources/Core package (no Package.swift survives), and where its OpenAPI spec would have come from.
- Which rule ignores/collapses the Modules/ folder in git status (found Modules/.build in .git/info/exclude; the rest of Modules/ is simply untracked, apparently intentionally).

**Consumer app: features and flows**

- Actual credit pricing, per-user request limits, and cooldowns are entirely server-side; the client only sees return codes (e.g. -8 = no credits) and server-worded toasts, so the rewrite needs the backend contract to document them.
- Whether the News tab (NewsFeedDataProvider, endpoint 'newsfeed') was intentionally retired or is meant to return; it is built but never added to the tab bar.
- The exact reward granted for adding a profile picture (comes back as free-text in the newavatar response; amount unknown from the client).
- Whether skip/blacklist actions on TuneIn are ever granted to ordinary consumers or only in machine-control/staff contexts — the server decides by attaching actions 401/402 to songs.
- CheckinVisibility 'friends'/'noone' scopes exist in the enum but no consumer UI sets them; unclear if any server behaviour still depends on them.
- SkinManager (venue-branded skin downloads) appears kiosk-focused; whether the consumer app is ever expected to re-skin was not determinable from code paths read.

**Kiosk app: the venue iPad**

- Whether any venue's digest feed actually served matrixControlLarge (change-mood) tiles to kiosks in production — the code path exists but its real-world use can't be determined from the client.
- What the attract-URL web pages contain (video loops, promos?) — they are server-hosted per venue and not in the repo.
- The exact semantics of the `appmodel=1` parameter server-side (only its presence on kiosk requests is visible).
- Whether pub deployments relied on iOS Guided Access / MDM for lockdown — no Guided Access API usage exists in code, so this is operational practice outside the repo.
- Why the audio session needs the 0.2 s preferred IO buffer at kiosk launch — the comment in KioskAppDelegate says the original reason is forgotten.
- Whether the kiosk Ad Hoc configuration (bundle id com.c-burn.kiosk, which would hit AppConfiguration's fatalError) was ever actually used, or is abandoned.

**Backend API and Spotify integration**

- Whether the server actually parses the structured User-Agent ("secret dj <deviceId>:<screenWidth>:<version>") — the format is clearly deliberate, but only the server code could confirm it is load-bearing.
- The semantics of the `item` and `type` (Int64 bitmask) parameters on musicselection/musicdigest/styleinfo beyond the LikeType values reused there — server-side docs would be needed for the full bitmask vocabulary.
- Whether the `checkunique` endpoint is still live server-side; it is defined in NetworkRequestType but has no Swift caller (possibly reached only by the retired ObjC code, e.g. the .trvs remnants).
- The remote URL of the Heroku_SpotifyTokenSwap submodule (no .gitmodules exists), and whether the Heroku service at obscure-sea-1305.herokuapp.com is formally decommissioned.
- Whether the day-of-year auth digests (Facebook/Apple sign-in, watchonyoutube song sig) are computed by the server in UTC or another timezone — the client uses local time, so there is a window where they disagree.
- Whether any backend besides api4.secretdj.com exists (staging/sandbox); nothing in the client suggests one.
- What the kiosk's akamaihd.net ATS exception was for — no code references it; presumed legacy Spotify audio-streaming CDN.

**Domain model and persistence**

- The legacy raw defaults key "userId" that UserManager's recovery path reads (UserManager.swift:90) has no writer in this codebase — presumably written by pre-Swift/ObjC releases; whether any live installs still depend on that recovery path cannot be determined from the code.
- Dead UserDefaultKey cases (scope, avatarURL, lastRefresh, jukeboxHash, spotifyUsername, spotifyCredential) have no readers/writers; whether old installs hold values that a rewrite should clean up (or must preserve for some server flow) is unknowable from the client alone.
- The first-run write to literal key ".deleteAccountRequested" (UserManager.swift:289) is never read — cannot tell whether it was a typo for the "DeleteAccountRequested" key or an abandoned experiment.
- Whether the server ever sends VendorId values other than Apple (the enum cast bug in TopUp.swift:35 makes it unobservable client-side), and whether the googlePlayStore case is truly dead.
- The exact server semantics of the feed "Hash"/token rotation contract (e.g. token lifetime, hash granularity per jukebox vs per venue) are only observable as client behavior; server documentation would be needed to confirm invariants.
- Venue.isEqual comparing display text and machineControl in addition to venueId looks deliberate (forces cell refresh on text change) but the original intent is undocumented.

**Audio and playback**

- What the external jukebox actually is (hardware player at the venue, a server-side Spotify/streaming account, or a third-party system) — the client only ever talks to the backend's machinecontrol/requestsong/playhistory endpoints, so the playback backend is invisible from this codebase.
- The real container/codec inside the .pbz preview files served from S3 (AVAudioPlayer sniffs it at runtime; likely MP3 or AAC, but nothing in the client confirms it).
- Why setPreferredIOBufferDuration(0.2) was originally needed — the in-code comment says the author no longer remembers; it predates the StreamingKit removal.
- Whether the backend team can/will fix the preview Content-Type and extension, which would let the rewrite use plain AVPlayer streaming instead of download-then-decode.
- Whether any richer machine-control actions (volume, pause, queue reorder) exist server-side but are simply never granted to these clients — the ActionType enum caps out at skip/blacklist/request/atmosphere.

**Monetization, identity, analytics, and compliance**

- Server-side credits ledger semantics: how many credits the profile-picture reward grants, voucher denominations, per-venue vs global credit balances, and whether unconsumed Apple transactions are reconciled server-side — none of this is visible from the client.
- Whether Firebase Analytics ever actually recorded the ReportableEvent events whose names contain spaces (e.g. "Facebook Sign In", "Request song") — Firebase's event-name rules suggest they are rejected by the SDK; verify against the Firebase console before assuming historical data exists.
- The live App Store Connect product list (SKUs/prices) for top-ups — SKUs are entirely server-driven (topupdetails response) and no product IDs appear in the repo.
- Whether the Facebook app (ID 144876722233890) is still active/configured in Meta's developer console, and whether Facebook Login is still functional with FBSDK >= 9 against current Graph API requirements (the Graph `gender` field now requires special permissions; the code requests it without app review evidence).
- Why the GoogleService-Info plists set IS_ANALYTICS_ENABLED=false while the app logs events via FirebaseAnalytics — whether this reflects a deliberate console-side configuration or is vestigial.
- Whether any server-driven feed content constitutes paid advertising (AdvertCollectionViewCell / Promotion item types exist but are empty shells client-side), which would affect the rewrite's privacy-nutrition-label answers.

**UI layer, assets, localization, and accessibility**

- Whether Paintcode/SDJAssets.pcvd is actually the generator source for StyleKit.swift's drawing code (StyleKit.swift is hand-attributed to a developer in 2017; the .pcvd was last touched May 2025) — opening the PaintCode document would confirm.
- Whether the SkinAsset/SkinColor/SkinText numeric ids (1001–1385) are documented server-side; the app treats them as a fixed contract but no spec exists in the repo.
- Whether any App Store build still relies on the legacy *_iPhone/*_iPad storyboards via a distribution branch other than 'refactor' — on this branch they are unreachable, but they remain in both targets' Resources phases.
- The intended fate of the auto-extracted SwiftUI display-text keys ("", "%lld", "CHANGE THE MOOD") in Localizable.xcstrings — they look like accidental extraction noise rather than deliberate keys, but only the team can confirm the convention going forward.

**Architecture and tech debt**

- Whether the stale `UIMainStoryboardFile: Login_iPhone` entries in both Info.plists have any effect at launch on current iOS (SceneDelegate builds the window in code and docs/storyboard-audit.md lists Login_iPhone as dead) — needs a runtime check, not just static reading.
- The intent behind the empty Modules/ SPM package (Modules/Sources/Core has no Package.swift or sources outside .build) — abandoned modularization, or scaffolding for the refactor branch?
- Whether PAYPAL_SUPPORTED was ever defined in a shipped configuration (no trace in the current project.pbxproj; PayPal keys remain in CommonConstants.h and AppConfiguration.swift), i.e. whether any live users ever transacted via PayPal.
- Why NetworkError's Equatable deliberately returns false for (.internalNetworkError, .internalNetworkError) (secretdjv3/NetworkAccess.swift lines 36-37) — intentional semantics or a latent bug in retry/error-dedup logic.
- Whether the xib/class-name mismatch for MatrixJukeboxLargeCollectionViewCell_ipad (xib customClass SDJMatrixJukeboxLargeCollectionViewCell_ipad vs Swift class without the SDJ prefix) means that cell path has been broken/unused since the ObjC era — no code site registers that xib that I could find, but I did not exhaustively trace kiosk nib registration at runtime.

**Tests, tooling, and quality gates**

- Whether the SecretDJTests suite currently builds and passes on the refactor branch — I did not run it (app-hosted tests need a simulator boot); the 2023-era commented-out tests suggest compile breakage was historically resolved by deletion rather than repair.
- Whether SwiftLint/SwiftFormat were ever run manually with the oddly named .swiftlint config after the one-time bulk-format commit (a738da5e); no invocation exists anywhere in the repo.
- The Crashlytics build-phase script text `"$<BUILD_DIR%/Build/*}/..."` in project.pbxproj looks like a corrupted shell expansion; whether archive-time symbol upload actually works (or was always done via the manual dSYM scripts instead) can't be determined from the repo.
- The phased storyboard-deletion plan referenced by docs/storyboard-audit.md lives at /Users/nick/.claude/plans/declarative-splashing-lemur.md, outside the repository — its contents were not available to this analysis.
- Whether the 2017-era JSON fixtures still match today's api4.secretdj.com responses — the fixtures pin the contract as of capture time, not necessarily the current server behavior.

**Refactor branch: the in-flight modernization**

- The phased migration plan referenced by docs/storyboard-audit.md lives at /Users/nick/.claude/plans/declarative-splashing-lemur.md — outside the repo — so the exact scope of Phases 4–7 is only inferable from code comments (Phase 4: MusicSelection/JukeboxMenu digest pager, Phase 6: login gender/photo screens, Phase 7: TuneIn); Phase 5's subject is unknown.
- Whether any build from the refactor branch (build 5287 at tip) actually shipped to the App Store with the three SwiftUI flags on — the branch shows verification-build bumps and an Xcode Cloud manifest, but no release tag past v5.1.4.
- Whether the UserDefaults flag overrides (keys "swiftui.settings" / "swiftui.changeMood" / "swiftui.musicSearch") were ever surfaced in any debug UI, or only via `defaults write` (no UI references them in the code).
- Why the tip commit's auto-extracted catalog entries were left without localizations / whether a localization pass was planned next (the commit message "some strings" suggests interrupted work).

**Gaps and cross-checks**

- Whether the server still emits hailTaxi buttons / Uber actions (100/101) in production feeds — the client paths are live, but only backend data confirms current use.
- What the 'PPP' acronym actually stood for (pay-per-play is an inference from context; no expansion exists in the repo).
- Whether any pub operations documentation tells staff to enable the Settings-app 'Disable Auto-Lock' toggle on kiosk iPads — the code makes it necessary, but the practice is outside the repo.
- Runtime behavior of the stale UIMainStoryboardFile entries remains unverified (would need to launch the apps; static reading still suggests the scene manifest wins).

