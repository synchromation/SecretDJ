---
name: localization
description: All user-facing copy — modern Xcode localization via String Catalogs into English (source), Spanish, German, Portuguese, French, and Dutch, with a defined tone of voice. Use whenever writing, changing, or translating any user-visible string (UI text, alerts, buttons, accessibility labels, permission prompts), or reviewing copy quality or tone.
---

# Localization

Six languages: **English (en, source — British English)**, Spanish (es),
German (de), Portuguese (pt — one catalog using Brazilian conventions with
*você*; a recorded decision), French (fr), Dutch (nl). The golden example
is the live `Localizable.xcstrings` in the app folder (bundled copy:
[references/Localizable.xcstrings](references/Localizable.xcstrings)).

## Mechanism

- **String Catalogs only** (the project sets
  `LOCALIZATION_PREFERS_STRING_CATALOGS` and
  `STRING_CATALOG_GENERATE_SYMBOLS`). User-facing strings are literals
  inside SwiftUI text APIs, auto-extracted at build; outside SwiftUI use
  `String(localized:comment:)`. Never `NSLocalizedString`, never ad-hoc
  `.strings` files.
- Every key carries a **translator comment**: where the string appears and
  what it does (see the golden example).
- **Plural and gender via catalog variation**, never `if`/`switch` on
  grammar in code — English's rules are nobody else's. Keep `%@`-style
  placeholders and the `\n\n` headline/detail structure identical across
  languages. Never assemble sentences by concatenation (word order
  differs); numbers, currency, and dates go through formatters.
- **Every user-facing surface is localizable from day one**: UI text,
  alerts, accessibility labels, `NS*UsageDescription` prompts (InfoPlist
  string catalog), any Settings bundle. Server-supplied display text must
  arrive localized (API takes a locale) or as codes mapped to catalog
  keys — never rendered as verbatim English.
- **Never key logic off a visible string** (comparing a button's title to
  its English text silently breaks in five languages) — drive UI state
  from model state.
- Not user-facing → not localized: log messages, analytics names, keys.

## Voice

Defined **once**, in the source language — full guide:
[references/tone-of-voice.md](references/tone-of-voice.md). In five words:
**friendly · honest · reassuring · cheeky · brief**. Non-negotiables:

- The app speaks as "we" to an informal "you"; contractions everywhere.
- Errors: one sincere "Sorry, …" up front, own the problem (never blame
  the user), and always end with a next step.
- Money: state the safe outcome explicitly — "No payment was taken." is
  load-bearing, reused verbatim, with fixed renderings per language.
- Cheek lives in onboarding and playful contexts only; money, account
  deletion, passwords, and permissions stay plain and unambiguous.

## Translating

Each language has a short adaptation sheet —
[references/language-adaptations.md](references/language-adaptations.md) —
covering register (informal address in all six), idiom transcreation
(never calque), capitalization norms (English Title Case is not exported),
length budgets (~130%, German and Dutch abbreviate), and the fixed
load-bearing phrases. The glossary lives there too: one term per concept
per language, grown as concepts appear. Assistant-drafted translations of
anything non-trivial are entered with state `needs_review` for a native
speaker; trivial vocabulary may be `translated` directly.

## Definition of done for any copy change

1. Key in the catalog with a translator comment; the source string follows
   the voice.
2. All five translations present, conforming to the adaptation sheets.
3. Source-language flaws fixed *before* translating — a flawed source
   multiplies its flaws by six.
4. `Scripts/verify.sh` passes (the build compiles the catalog).
