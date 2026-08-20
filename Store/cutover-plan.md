# Cutover plan (S9.4)

> Draft — product owner review required.

How the rewrites replace the legacy apps in production. Shipping model:
**updates to the existing App Store listings** (decision D14) — consumer
`com.c-burn.secretdj`, kiosk `com.secretdj.kiosk` — at marketing version
6.0.0, build 10300 (clears both legacy build-number floors: consumer
5287, kiosk 10226; see S9.1).

## Account continuity

- The backend is unchanged: the rewrite speaks the legacy wire contract
  (signing, envelope, endpoints — verified against production during
  S1/S4, including a live sign-in through the app's own stack).
  Existing accounts simply work.
- **Sessions do not migrate from legacy installs** (decision D6): the
  legacy app stored its session under different keys and formats, and
  the rewrite deliberately reads none of them. A user updating from the
  legacy app is signed out once and signs back in with their existing
  screen name and password (or Apple/Facebook once those flows are
  device-verified). This is safe because the account lives entirely
  server-side; nothing but the cached session is local.
- Why this is the right trade: migrating legacy keychain/UserDefaults
  state would mean re-implementing the legacy storage quirks LEGACY.md
  documents (including the load-bearing first-run typo) for a one-time
  transition. One sign-in is cheaper and safer than carrying that
  surface forever.

## What a legacy user experiences on update

1. App updates in place (same icon position, same listing).
2. First launch lands on the new sign-in screen (one-time).
3. After sign-in: same account, credits, and venues — new interface.
4. Credits and purchase history are server-side and unaffected.
   Unfinished StoreKit transactions from the legacy app, if any exist,
   are Apple-side and will surface to the new transaction listener,
   which submits them through `topupnotify` exactly as legacy's resubmit
   loop would have.

## Rollback story

- **Consumer**: use App Store **phased release** (see below). If a
  release-blocking defect appears, pause the phased rollout in App
  Store Connect. True rollback (re-shipping the legacy build) is
  effectively unavailable on iOS — the legacy build numbers are below
  10300 and Apple does not re-publish old binaries — so the real
  rollback lever is: pause rollout, fix forward, expedite review.
  Mitigation for stranded updated users during an incident: the app is
  server-driven — many defects can be mitigated from the backend
  (templates, actions, copy) without a client release.
- **Kiosk**: venue iPads are updated deliberately (see fleet rollout),
  so "rollback" is simply not updating further venues and restoring
  any affected iPad from its still-installed legacy build via MDM or
  manual reinstall while a fix ships.

## Phased release recommendation

- Consumer: 7-day phased release ON, with the pause lever pre-agreed.
  Watch: crash-free rate (Sentry, once vendor destinations are
  confirmed), sign-in success (the one-time re-auth spike is expected —
  monitor failure rate, not volume), requestsong success rate.
- Kiosk: do NOT rely on App Store phasing — venue devices should be
  updated venue-by-venue (below), independent of the store rollout.

## Kiosk fleet rollout

Per-venue, in this order:

1. Verify the venue's iPad runs iOS 26 (decision D3 — confirmed as
   policy; verify per device at update time).
2. Update the app; launch; sign in with the venue account.
3. The skin downloads (blocking screen with progress; retry-only on
   failure — check connectivity before leaving).
4. Sanity pass: now-playing header live, digest loads, a mood tile
   changes atmosphere, a test search works, attract mode appears after
   the configured timeout and dismisses on touch.
5. Re-enable **Guided Access** (or the venue's MDM kiosk mode) and the
   Settings-app auto-lock policy (risk R1: the app's in-app auto-lock
   toggle controls `isIdleTimerDisabled`, but device auto-lock and
   physical security are operational concerns outside the app).
6. Staff briefing: the reset gesture is now five taps in the top-left
   corner within three seconds, then a confirmation — replacing the old
   `?RESTART?` search incantation.

## Launch-gate checklist

Every item must be closed before the phased release starts:

- [ ] **D11 backend localization deployed** — production currently
      returns English for all `Accept-Language` values (S8.1 finding).
      Re-run the S8.1 per-language capture to verify.
- [ ] On-device sign-in smokes: Apple (S4.3) and Facebook (S4.4, needs
      the client token from the Meta dashboard first).
- [ ] StoreKit sandbox purchase/restore pass (S6.7).
- [ ] Native-speaker pass over the `needs_review` queue — at minimum
      the ~35 high-risk entries (money, deletion, permissions).
- [ ] Vendor telemetry confirmed (Sentry DSN / TelemetryDeck app ID are
      the intended destinations; kiosk vendor adapters linked).
- [ ] Manual VoiceOver walk of the 13 audited screens; the two
      element-scoped contrast items checked with Accessibility
      Inspector (S8.2's human half).
- [ ] S8.4 on hardware: Instruments passes (feed scroll both apps,
      launch time) and the kiosk soak on a venue-class iPad.
- [ ] Real app icons and screenshots (five languages) in App Store
      Connect; metadata drafts in `Store/` reviewed and entered.
- [ ] Privacy labels entered per `Store/privacy-labels.md` after
      product review.
- [ ] TestFlight internal builds of both apps; at least one venue pilot
      for the kiosk (S9.3).
