# App Store privacy nutrition labels — draft answers

> Draft — product owner review required.

Draft answers to Apple's App Privacy questionnaire (App Store Connect →
App Privacy) for both apps, derived from reading the actual code as of
build 10300 / MARKETING_VERSION 6.0.0 (`SecretDJ.xcodeproj/project.pbxproj`).
Every row cites the file that justifies it. Where the code doesn't
resolve a question, it's listed under **Open items** rather than guessed.

This is PLAN.md S9.2's privacy-label half; it draws on the S8.3
observability/redaction audit (NOTES.md, 2026-08-20) rather than
repeating that work.

## How to read this

Apple's questionnaire asks, per data type: **collected?**, if so
**linked to identity?** (tied to the user's account/device rather than
anonymous), and **used to track?** (ATT-gated cross-app/cross-site
tracking). "Not collected" data types are omitted from Apple's
published label entirely, so this draft only lists types with a "Yes."

---

## Consumer app (`com.c-burn.secretdj`)

| Data type | Collected | Linked to identity | Used to track | Citing file |
|---|---|---|---|---|
| **Contact Info — Name** | Yes (first/last name on native sign-up and Sign in with Apple/Facebook's first-auth payload) | Yes | No | `Packages/SecretDJAPI/Sources/SecretDJAPI/APIClient+Auth.swift` (`createUser`, `appleSignIn`, `facebookSignIn` all accept `firstName`/`lastName`) |
| **Contact Info — Email Address** | Yes | Yes | No | same file — `email` parameter on `createUser`/`appleSignIn`/`facebookSignIn`; also `resetpassword`'s screenname-or-email input (`APIClient+Auth.swift`) |
| **User Content — Photos or Videos** | Yes (profile picture) | Yes | No | `Packages/SecretDJAPI/Sources/SecretDJAPI/APIClient+User.swift` — `newavatar` multipart JPEG upload; captured/picked in `SecretDJ/Features/Onboarding/PhotoStepView.swift` and `SecretDJ/Features/Profile/AvatarChangeSheet.swift`; camera permission string at `SecretDJ.xcodeproj/project.pbxproj` (`INFOPLIST_KEY_NSCameraUsageDescription`) |
| **Identifiers — User ID** | Yes (screen name / person id) | Yes | No | `Packages/SecretDJAPI/Sources/SecretDJAPI/SessionStore.swift` (`SessionUser.personId`/`screenName`, persisted via `UserDefaultsSessionSnapshotStore`) |
| **Identifiers — Device ID** | Yes (`identifierForVendor`) | Yes (sent with every signed-in request) | No | `SecretDJ/App/SecretDJApp.swift` — `APIClientConfiguration.live.deviceIdentifier`; also embedded in the User-Agent string per LEGACY.md's wire format |
| **Location — Precise Location** | Yes, when-in-use only | Yes (appended to authenticated requests) | No | `SecretDJ/Features/Location/CLLocationManagerLocationProviding.swift` (no `desiredAccuracy` override → Core Location default, full precision; `requestWhenInUseAuthorization()` only, no Always); usage string at `project.pbxproj` `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription`; wired into every request via `SecretDJ/App/DeviceImplicitParameterProvider.swift` → `coordinateBox.current` |
| **Purchases — Purchase History** | Yes (credit top-ups) | Yes | No | `SecretDJ/Features/TopUps/StoreKitProductPurchasing.swift` (StoreKit 2) + `topupnotify` submission (`Packages/SecretDJAPI/Sources/SecretDJAPI/APIClient+Credits.swift`) carrying transaction id/sku/receipt/uid per PLAN.md S6.7 |
| **Diagnostics — Crash Data** | Yes (release builds only) | See open item below | No (not used for tracking; crash reporting only) | `SecretDJ/App/SecretDJApp.swift` `ObservabilityPipeline.live` appends `SentryDestination` under `#if !DEBUG`; DSN in `SecretDJ/App/SentryConfiguration.swift` |
| **Diagnostics — Other Diagnostic Data** | Yes (non-fatal errors + breadcrumbs, release builds only) | No — redacted at the emission site | No | Same Sentry wiring; redaction mechanism is `Packages/Observability/Sources/Observability/Redacted.swift` per the observability skill; S8.3's audit (NOTES.md 2026-08-20) found and fixed one leak (`APIError` embedding signed URLs with sign-in credentials) and found no other identifying emissions across ~162 sites |
| **Usage Data — Product Interaction** | Yes (release builds only) | No — named events only, no free-text parameters | No | `SecretDJ/App/SecretDJApp.swift` appends `TelemetryDeckDestination` under `#if !DEBUG`; app id in `SecretDJ/App/TelemetryDeckConfiguration.swift`. Every feature's `*Event` enum (e.g. `SecretDJ/Features/Login/LoginEvent.swift`, `SecretDJ/Features/TopUps/TopUpsEvent.swift`) is a bare case name — `AnalyticsEvent.parameters` defaults to `[:]` (`Packages/Observability/Sources/Observability/AnalyticsEvent.swift`) and no feature overrides it, so no event carries free-text or identifying values |

### Data NOT collected (consumer)

- **Contacts** — no `Contacts` framework import anywhere in the target.
- **Search/Browsing History** outside the app — the in-app track/artist
  search (`Packages/SharedFeatures/Sources/SharedFeatures/MusicSearch/`)
  stays server-side query traffic, not a locally- or vendor-persisted
  history; its analytics event (`MusicSearchEvent`) is a bare case name
  like the others.
- **Financial Info** beyond the StoreKit purchase flow itself — no card
  numbers or bank details touch the app; Apple handles payment directly.
- **Health & Fitness, Sensitive Info** — no APIs for either exist in the
  target.

### Tracking (ATT)

**No tracking today.** `FacebookConfiguration.isConfigured` is `false`
(`SecretDJ/App/FacebookConfiguration.swift`) because `clientToken` is
still the literal placeholder `"MISSING-SEE-META-DASHBOARD"` — this
gates the Facebook button off (it doesn't render) and the Facebook SDK
is never initialized (S4.4's doc comment). The ATT prompt itself only
fires from two Facebook-touching call sites — Facebook sign-in and
"use my Facebook photo" — both behind the same unconfigured SDK
(`SecretDJ/Features/Login/ATTrackingManagerTrackingAuthorizing.swift`,
`FacebookSignInModel.swift`). So in the shipped build, the ATT prompt
never appears and no tracking-category data is collected.

**This flips the moment the product owner supplies a real Facebook
Client Token** (PLAN.md S4.4's open ask). Once `isConfigured` is true,
Facebook's SDK initializes on Facebook sign-in / "use my Facebook
photo," and Meta's own SDK behavior (device signals shared with
Facebook for the login flow) very likely counts as "Data Used to Track
You" under Apple's definition — the nutrition label's tracking answer
and the "Data Types Used to Track You" section need re-filing at that
point, not before. **Flag this as a launch-blocking dependency between
D1 (Facebook, resolved: keep) and S9.2.**

---

## Kiosk app (`com.secretdj.kiosk`)

The kiosk is a venue-operated terminal, not a consumer download, but
still ships through the App Store and needs its own label.

| Data type | Collected | Linked to identity | Used to track | Citing file |
|---|---|---|---|---|
| **Identifiers — User ID** | Yes (venue staff account: person id / screen name, forced venue id) | Yes | No | `SecretDJKiosk/Features/KioskLogin/SessionStore+KioskAuthenticatedSession.swift` — `signIn(from: KioskAuthenticatedSession, passwordHash:)` |
| **Identifiers — Device ID** | Yes (`identifierForVendor`) | Yes | No | `SecretDJKiosk/App/SecretDJKioskApp.swift` — `APIClientConfiguration.live.deviceIdentifier`, same pattern as the consumer app |
| **Diagnostics** | **Console-only today — nothing leaves the device** | n/a | No | `SecretDJKiosk/App/SecretDJKioskApp.swift` — `ObservabilityPipeline.live` for the kiosk is `ConsoleDestination()` only; no `ObservabilitySentry`/`ObservabilityTelemetryDeck` import anywhere in `SecretDJKiosk/` (confirmed by grep) |
| **Usage Data** | **Not collected** — same reason | n/a | No | same file/reason |

### Data NOT collected (kiosk) — corrects an assumption

The kiosk does **not** currently collect location, despite that being
a reasonable-sounding assumption for a venue terminal. Checked directly:

- `SecretDJKiosk/App/KioskDeviceImplicitParameterProvider.swift`'s
  `location` property is a hard-coded `nil` with a doc comment
  explaining CoreLocation was deliberately never wired up for the kiosk
  shell (no location feature exists under `SecretDJKiosk/Features/`).
- `SecretDJ.xcodeproj/project.pbxproj`'s kiosk target configs carry
  **no** `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription` (grepped
  against both app targets — only the consumer target has it), so the
  kiosk couldn't prompt for location even if it tried.
- No `NSCameraUsageDescription`/`NSPhotoLibraryUsageDescription`/
  `NSUserTrackingUsageDescription` keys exist for the kiosk target
  either — no camera, photo library, or ATT surface at all.

So the kiosk's actual collected-data surface is narrower than "venue
creds + location": it's **venue staff sign-in credentials and the
device identifier only**. No purchases (no StoreKit import under
`SecretDJKiosk/`), no ATT, no Facebook, no photos, no analytics.

**If the kiosk is meant to report location** (arguably useful for a
fixed venue terminal, e.g. for the places-nearby-style feeds it shares
with the consumer app via `SharedFeatures`), that's unbuilt scope, not
a doc gap — flagging for the product owner to decide whether it belongs
in S7 follow-up work before this label is finalized.

---

## Open items for the product owner

1. **Vendor confirmation (blocks the Diagnostics/Crash Data linked-identity
   answer).** S8.3's audit (NOTES.md, 2026-08-20) found the consumer app's
   Sentry DSN and TelemetryDeck app ID are the ones inherited from the
   example project this codebase started from — confirm they're the
   intended production destinations before this label ships. Separately:
   neither vendor SDK is told the signed-in user id (no `SentrySDK.setUser`
   call exists in `SentryDestination.swift`, no user id passed to
   TelemetryDeck's config in `TelemetryDeckDestination.swift`), but both
   SDKs collect some standard device/session metadata by default as part
   of normal crash/analytics SDK operation (device model, OS version,
   approximate IP-derived region) — that's vendor-SDK behavior outside
   this app's control and should be checked against Sentry's and
   TelemetryDeck's own privacy documentation before answering "linked to
   identity" definitively for Diagnostics and Usage Data.
2. **Facebook Client Token (blocks the Tracking answer).** See "Tracking
   (ATT)" above — the whole tracking section of this label is contingent
   on S4.4's outstanding ask for a real Meta Client Token. File this label
   with tracking = No now; re-file when the token lands and Facebook
   sign-in goes live.
3. **Kiosk vendor linkage (blocks nothing today, but is a stated gap).**
   PLAN.md S8.3 records "the kiosk still needs the vendor adapters linked
   (console-only today)" — if/when Sentry/TelemetryDeck are added to the
   kiosk target, this label's Diagnostics/Usage Data rows for the kiosk
   need to be re-drafted to match the consumer app's.
4. **Kiosk location scope.** Confirm whether the kiosk is meant to collect
   location at all (see above) — affects only future work, not this
   label as the code stands today.
