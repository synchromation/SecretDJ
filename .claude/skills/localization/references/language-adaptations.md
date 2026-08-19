# Per-language adaptation sheets

One short sheet per target language: register, idiom, grammar-driven
rules. The voice itself is defined once in
[tone-of-voice.md](tone-of-voice.md).

## Global rules (all languages)

- **Register: informal "you" everywhere.** Formal address breaks the
  voice. This is deliberate even where app copy conventionally skews
  formal (French).
- **Do not translate:** the app name, platform and product names
  (Spotify, Apple Music, Sign in with Apple, Facebook, WiFi), error
  numbers (#113), email addresses. Translate "Settings" to the iOS system
  term per language; keep the `->` arrows.
- **Transcreate, don't calque.** Exclamations and cheeky refusals must
  land as natural idiom, never word-for-word. English-language cultural
  references (e.g. a punk-rock "Hey! Ho! Let's Go!!!") stay in English
  where the reference is international; substitute an equally energetic
  local exclamation if it reads as noise — never translate literally.
- **ALL-CAPS** is fine for buttons/labels in all five languages; never
  all-caps body text.
- **Keep the `\n\n` structure** and `%@`/format placeholders exactly as in
  the source.
- **Length:** buttons and titles within ~130% of English; German and
  Dutch abbreviate rather than shrink fonts. Check the tightest ALL-CAPS
  buttons early.
- **Load-bearing payment phrase** appears explicitly in every language's
  payment errors (fixed renderings below) — never soften or drop it.
- **Plural & gender** use the catalog's variation feature, never
  word-order tricks.

## Spanish (es)

- Address: *tú* (not *usted*); Latin-American-neutral vocabulary.
- "Sorry, ..." → *"Lo sentimos, ..."*; lighter "Uh-oh!" moments → *"Vaya..."*.
- "No payment was taken." → **"No se ha realizado ningún cargo."**
- Cheeky refusals keep the wink, not the harshness: *"Eso es cosa mía"* /
  *"Prefiero no decirlo"* territory — translator's call.
- No Title Case: only first word + proper nouns ("Abrir ajustes").
- iOS term: Settings = *Ajustes*.

## German (de)

- Address: *du* (lowercase *du/dein*). Never *Sie*.
- Runs ~30% longer — layout-check ALL-CAPS buttons ("VIELLEICHT SPÄTER").
- "Sorry, ..." stays *"Sorry, ..."* in informal app copy; *"Leider ..."*
  in sober contexts (account deletion).
- "Uh-oh! ... hiccup" → *"Ups! Da ist etwas schiefgelaufen..."*
- "No payment was taken." → **"Es wurde keine Zahlung abgebucht."**
- German noun capitalization applies; no imitation of English Title Case.
- iOS term: Settings = *Einstellungen*.

## French (fr)

- Address: *tu*, consistently — a deliberate brand choice against the
  formal default of French app copy. Never mix *tu* and *vous*.
- "Sorry, ..." → *"Désolé, ..."*; playful cases → *"Oups..."*.
- "Uh-oh! ... hiccup" → *"Oups ! Petit couac avec ta transaction..."*
- "No payment was taken." → **"Aucun paiement n'a été effectué."**
- French typography: non-breaking space before `!` `?` `:`.
- Sentence-style capitalization ("Ouvrir les réglages").
- iOS term: Settings = *Réglages*.

## Dutch (nl)

- Address: *je/jij* (never *u*) — the consumer-app norm.
- The playful English tone translates almost one-to-one; "Uh-oh!" →
  *"Oeps!"*; "Sorry, ..." stays *"Sorry, ..."*.
- "No payment was taken." → **"Er is geen betaling afgeschreven."**
- Sentence-style capitalization ("Instellingen openen").
- iOS term: Settings = *Instellingen*.

## Glossary

One term per concept per language, used consistently everywhere. Grow
this table as concepts appear; never let two synonyms for one concept
coexist in one language.

| English (source) | Notes for translators |
|---|---|
| <app name> | Never translate, in any context. |
| sign in / sign up | Use each platform's conventional informal pairing; never "log in" as a verb in English source. |
| top-up | Pick one target-language term and use it for every purchase-related string. |
| restore purchases | Use Apple's own localized StoreKit terminology per language. |
| screen name | es *nombre de usuario*, fr *nom d'utilisateur*, de *Benutzername*, nl *gebruikersnaam* — the account handle (distinct from a person's real first/last name). |
| check in (venue) | es *Registrarse* / *Registrado*, fr *S'enregistrer* / *Enregistré*, de *Einchecken* / *Eingecheckt*, nl *Inchecken* / *Ingecheckt* — action/state pair for the venue check-in button. |
| directions | es *Cómo llegar*, fr *Itinéraire*, de *Route*, nl *Route* — matches each language's own Maps app convention rather than a literal translation. |

When the assistant drafts a glossary term or any non-trivial translation,
it enters the catalog as `needs_review` until a native speaker confirms.
