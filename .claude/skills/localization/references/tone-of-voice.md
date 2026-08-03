# Tone of voice — master guide (source language)

The personality is defined once, here, in the source language. Target
languages adapt it through their sheets in
[language-adaptations.md](language-adaptations.md) — we deliberately do not
maintain six parallel voice documents.

## Who is speaking

The app speaks as **"we"** — a small, friendly team, not a faceless
system. The user is **"you"**, addressed directly and informally. Think of
a knowledgeable mate: relaxed, helpful, cheeky when the moment allows,
never robotic, never gushing.

## Personality in five words

**Friendly · Honest · Reassuring · Cheeky · Brief**

## Core rules

1. **Warm, informal, conversational.** Contractions everywhere: *you've,
   won't, don't, we'll, can't*. Never "do not" / "cannot" in body text.
   - ✅ "Shouldn't take long..."
   - ❌ "This operation may take several moments."

2. **Apologise when something goes wrong — once, sincerely, up front.**
   "Sorry, ..." opens most error messages; then straight to what happened
   and what to do. Don't grovel or over-apologise.

3. **Own the problem; never blame the user.** Errors are things that
   *happened*, not things the user did wrong.
   - ✅ "Uh-oh! There was a hiccup with your transaction... Don't worry,
     we're on it and we'll email you soon."
   - ❌ "You entered invalid data."

4. **Reassure on anything involving money.** Always state the safe outcome
   explicitly. The phrase **"No payment was taken."** is standard — reuse
   it verbatim (per-language renderings are fixed in the adaptation
   sheets).

5. **Always give a next step.** Every error tells the user what to do:
   try again, check your connection, open Settings, or email us —
   "Please drop us an email at <support address> quoting error #<n> and
   we'll sort it out."

6. **Cheek is a feature — in the right places.** Playful refusals and
   self-aware asides give the app its personality: a decline button that
   winks ("NEVER YOU MIND"), a gentle cancel ("Not today", "MAYBE LATER"),
   self-deprecation about form-filling ("Lastly... the boring bit"), an
   energetic cultural nod on a final call-to-action ("Hey! Ho! Let's
   Go!!!"). Playfulness never appears in serious contexts: account
   deletion bodies, incorrect passwords, and permission denials stay
   plain and clear.

7. **Soften the ask.** Questions and optional steps are invitations, not
   demands: "Add A Profile Picture?", "Got a voucher code?" — with polite
   acceptances ("Yes, Please").

8. **Brevity.** Titles 1–4 words; bodies 1–3 short sentences; no
   paragraphs. Deliberate exception: irreversible-consequence text (e.g.
   account deletion), which is intentionally full and unambiguous.

9. **British English** in the source: *top-up, unauthorised, apologise,
   Cancelled, Travelling*.

## Formatting conventions

| Element | Convention | Examples |
|---|---|---|
| Alert titles | Title Case, 1–4 words | "Restore failed", "Allow Tracking?" |
| Alert bodies | Sentence case; `\n\n` separates headline from detail | "Failed to Sign In\n\nIncorrect username or password." |
| Standard buttons | Title Case | "Cancel", "Open Settings", "Retry", "OK" (never "Ok") |
| Emphatic/onboarding buttons & field labels | ALL CAPS | "SIGN IN", "CONTINUE", "MAYBE LATER" |
| Progress states | ALL CAPS or Title Case + "..." | "SIGNING IN...", "Loading..." |
| Settings paths | Arrow chain, no spaces | "Settings-><App Name>->Camera" |
| Screen titles | Title Case, short | "Now Playing", "Places Nearby" |
| Field placeholders | Sentence case, personal | "Your first name", "Pick a password" |
| Error references | "#" + number, quoted in the email instruction | "quoting error #113" |
| Ellipsis | Three dots `...` for in-progress or trailing off | "Finally...", "Shouldn't take long..." |
| Fallback values | "Unknown" + noun | "Unknown Artist", "Unknown Venue" |

## Recurring formulas (reuse verbatim in English)

- **Connection errors:** "<Thing that failed>\n\nPlease check that you
  have a good connection to your cellular data or WiFi network."
- **Generic retry:** "<Thing that failed>\n\nPlease retry later"
- **Payment safety:** "No payment was taken." / "You weren't charged."
- **Support escalation:** "Please drop us an email at <address> quoting
  error #<n> and we'll sort it out."
- **Permission denied:** "You haven't allowed us to <access X>.\n\nIf
  you'd like to <use X> please go to Settings-><App Name>-><X> and enable
  <x> access."

## Words we use / avoid

| Use | Avoid |
|---|---|
| sign in / sign up | log in / login (as a verb), register |
| picture, pic (casual) | photograph, image |
| Sorry, ... | Error:, Oops! ("Uh-oh!" instead, sparingly) |
| problem, hiccup | failure, fault, exception |
| top-up | in-app purchase, IAP |

Domain nouns (what to call the app's core concepts) live in the glossary
in [language-adaptations.md](language-adaptations.md) — one term per
concept, used consistently.

## Context-sensitivity dial

| Context | Tone |
|---|---|
| Onboarding, profile | Most playful |
| Core feature use | Friendly and energetic |
| Errors (recoverable) | Warm, apologetic, solution-first |
| Money | Calm, explicit, reassuring — always state payment status |
| Account deletion, passwords, privacy | Plain, sober, unambiguous; no jokes |
| Permission prompts | Honest and plain-spoken: say exactly why — "We use your location to find your nearest venue." |
| iOS Settings pane | Neutral, system-like |
