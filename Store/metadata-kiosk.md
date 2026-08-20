# App Store metadata — kiosk app (Secret DJ Kiosk)

> Draft — product owner review required.

Same conventions as `metadata-consumer.md`: English is the source
(written first per the localization skill's "fix the source before
translating" rule), es/fr/de/nl are draft translations in
**needs_review** state, and the app name is never translated
(localization skill glossary rule). Field limits: **Name ≤30
characters, Subtitle ≤30 characters, Keywords ≤100 characters**
(comma-separated, no spaces after commas); Promotional text (≤170) and
Description (≤4000) also kept under Apple's caps as good practice.

This is a venue-operated iPad terminal, not a consumer download (S7's
"pub employee signs the iPad in once... runs all day as a self-service
jukebox terminal" — PLAN.md S7 goal, LEGACY.md "Kiosk app: the venue
iPad"). The audience for this listing is venue staff/owners installing
it on venue hardware, not end users browsing the Store, so the tone is
plainer and more operational than the consumer app's — per the
localization skill's tone-of-voice context dial, which puts
"iOS Settings pane" style copy at "neutral, system-like"; this listing
sits closer to that end than to onboarding's cheekiest register.

Ships to `com.secretdj.kiosk` per D14 (PLAN.md) — same bundle id, same
listing, shipped as an update.

---

## English (en, source)

**Name** (15/30): `Secret DJ Kiosk`

**Subtitle** (24/30): `Run your venue's jukebox`

**Promotional text** (≤170 chars, 108 used):
> All-new Secret DJ Kiosk. Same self-service jukebox for your
> customers, rebuilt for reliability — sign in once, runs all day.

**Keywords** (64/100): `kiosk,jukebox,venue,pub,bar,staff,ipad,music,attract screen,skin`

**Description**:
> Secret DJ Kiosk turns an iPad into a self-service jukebox for your
> venue. Sign in once with your venue account and it runs all day —
> customers browse, search, and request songs against your Secret DJ
> jukebox without any staff involvement.
>
> **What it does**
> - Runs landscape, all day, with an attract screen between customers.
> - Shows what's playing and lets customers browse or search for a
>   song to request.
> - Reflects your venue's own look via server-managed skinning — no
>   separate setup on the device.
> - Recovers on its own from network drops and returns to the attract
>   screen automatically.
>
> **For staff**
> - One sign-in per iPad, bound to your venue.
> - A built-in staff reset clears the session and cached venue skin
>   without restarting the device — handy at shift changes or when
>   handing the iPad to someone new.
> - No customer account needed on the kiosk itself — Secret DJ Kiosk
>   only ever signs in as your venue.
>
> This is a full rebuild of the venue terminal: redesigned for
> reliability during a long service day, with the same self-service
> jukebox your customers already know from the venue floor.

**What's new (this version)**:
> Secret DJ Kiosk has been rebuilt from the ground up for reliability:
> steadier all-day operation, a redesigned staff reset, and smoother
> recovery from network drops. Your venue's sign-in and skin work
> exactly as before.

---

## Spanish (es) — needs_review

**Subtitle** (22/30): `El jukebox de tu local`

**Promotional text**:
> Secret DJ Kiosk, renovado. El mismo jukebox de autoservicio para tus
> clientes, reconstruido para ser más fiable — inicia sesión una vez y
> funciona todo el día.

**Keywords** (63/100): `kiosco,jukebox,local,pub,bar,personal,ipad,musica,pantalla,skin`

**Description**:
> Secret DJ Kiosk convierte un iPad en un jukebox de autoservicio para
> tu local. Inicia sesión una vez con la cuenta de tu local y funciona
> todo el día — los clientes exploran, buscan y piden canciones en tu
> jukebox de Secret DJ sin que el personal tenga que intervenir.
>
> **Qué hace**
> - Funciona en horizontal, todo el día, con una pantalla de reclamo
>   entre clientes.
> - Muestra qué está sonando y permite explorar o buscar una canción
>   para pedirla.
> - Refleja el estilo de tu local mediante skins gestionadas desde el
>   servidor — sin configuración aparte en el dispositivo.
> - Se recupera solo de las caídas de red y vuelve automáticamente a
>   la pantalla de reclamo.
>
> **Para el personal**
> - Un inicio de sesión por iPad, vinculado a tu local.
> - Un reinicio de personal integrado borra la sesión y el skin del
>   local en caché sin reiniciar el dispositivo — útil en los cambios
>   de turno o al entregar el iPad a otra persona.
> - No hace falta una cuenta de cliente en el kiosco — Secret DJ Kiosk
>   solo inicia sesión como tu local.
>
> Esta es una reconstrucción completa del terminal de local: rediseñado
> para ser fiable durante un servicio largo, con el mismo jukebox de
> autoservicio que tus clientes ya conocen.

**What's new (this version)**:
> Secret DJ Kiosk se ha reconstruido por completo para ser más fiable:
> funcionamiento más estable durante todo el día, un reinicio de
> personal rediseñado y una recuperación más fluida ante caídas de
> red. El inicio de sesión y el skin de tu local funcionan exactamente
> igual que antes.

---

## French (fr) — needs_review

**Subtitle** (21/30): `Le jukebox de ton bar`

**Promotional text**:
> Secret DJ Kiosk fait peau neuve. Le même jukebox en libre-service
> pour tes clients, reconstruit pour être plus fiable — connecte-toi
> une fois, il tourne toute la journée.

**Keywords** (60/100): `borne,jukebox,bar,pub,personnel,ipad,musique,ecran,habillage`

**Description**:
> Secret DJ Kiosk transforme un iPad en jukebox en libre-service pour
> ton établissement. Connecte-toi une fois avec le compte de ton
> établissement et il tourne toute la journée — les clients
> parcourent, cherchent et demandent des chansons sur ton jukebox
> Secret DJ sans intervention du personnel.
>
> **Ce qu'il fait**
> - Fonctionne en mode paysage, toute la journée, avec un écran
>   d'accroche entre chaque client.
> - Affiche ce qui joue et permet de parcourir ou chercher une chanson
>   à demander.
> - Reprend le look de ton établissement grâce à un habillage géré par
>   le serveur — aucune configuration séparée sur l'appareil.
> - Se remet automatiquement des coupures réseau et revient seul à
>   l'écran d'accroche.
>
> **Pour le personnel**
> - Une seule connexion par iPad, liée à ton établissement.
> - Une réinitialisation intégrée efface la session et l'habillage en
>   cache sans redémarrer l'appareil — pratique aux changements
>   d'équipe ou quand on passe l'iPad à quelqu'un d'autre.
> - Pas besoin de compte client sur la borne — Secret DJ Kiosk se
>   connecte uniquement en tant que ton établissement.
>
> C'est une reconstruction complète du terminal d'établissement :
> repensé pour la fiabilité sur un long service, avec le même jukebox
> en libre-service que tes clients connaissent déjà.

**What's new (this version)**:
> Secret DJ Kiosk a été entièrement reconstruit pour plus de fiabilité :
> un fonctionnement plus stable toute la journée, une réinitialisation
> du personnel repensée, et une meilleure récupération après une
> coupure réseau. La connexion et l'habillage de ton établissement
> fonctionnent exactement comme avant.

---

## German (de) — needs_review

**Subtitle** (26/30): `Die Jukebox für dein Lokal`

**Promotional text**:
> Secret DJ Kiosk ganz neu. Die gleiche Self-Service-Jukebox für deine
> Gäste, neu gebaut für mehr Zuverlässigkeit — einmal anmelden, läuft
> den ganzen Tag.

**Keywords** (55/100): `kiosk,jukebox,lokal,kneipe,bar,personal,ipad,musik,skin`

**Description**:
> Secret DJ Kiosk macht aus einem iPad eine Self-Service-Jukebox für
> dein Lokal. Einmal mit deinem Lokal-Account anmelden, und es läuft
> den ganzen Tag — Gäste stöbern, suchen und wünschen sich Songs auf
> deiner Secret-DJ-Jukebox, ganz ohne Personal.
>
> **Was es macht**
> - Läuft im Querformat, den ganzen Tag, mit einem Anlockbildschirm
>   zwischen den Gästen.
> - Zeigt, was gerade läuft, und lässt Gäste stöbern oder einen Song
>   zum Wünschen suchen.
> - Übernimmt den Look deines Lokals über serverseitiges Skinning —
>   keine separate Einrichtung am Gerät nötig.
> - Erholt sich selbstständig von Netzwerkausfällen und kehrt
>   automatisch zum Anlockbildschirm zurück.
>
> **Für dein Personal**
> - Eine Anmeldung pro iPad, gebunden an dein Lokal.
> - Ein eingebauter Personal-Reset löscht Sitzung und
>   zwischengespeichertes Skin, ohne das Gerät neu zu starten —
>   praktisch beim Schichtwechsel oder wenn das iPad an jemand
>   anderen weitergegeben wird.
> - Kein Kunden-Account am Kiosk nötig — Secret DJ Kiosk meldet sich
>   ausschließlich als dein Lokal an.
>
> Das ist ein kompletter Neuaufbau des Lokal-Terminals: neu gestaltet
> für Zuverlässigkeit über einen langen Servicetag, mit der gleichen
> Self-Service-Jukebox, die deine Gäste schon kennen.

**What's new (this version)**:
> Secret DJ Kiosk wurde komplett neu gebaut für mehr Zuverlässigkeit:
> stabilerer Betrieb über den ganzen Tag, ein neu gestalteter
> Personal-Reset und eine flüssigere Erholung nach Netzwerkausfällen.
> Anmeldung und Skin deines Lokals funktionieren genau wie zuvor.

---

## Dutch (nl) — needs_review

**Subtitle** (24/30): `De jukebox van jouw zaak`

**Promotional text**:
> Secret DJ Kiosk helemaal vernieuwd. Dezelfde self-service jukebox
> voor je gasten, opnieuw gebouwd voor meer betrouwbaarheid — één keer
> inloggen, draait de hele dag.

**Keywords** (62/100): `kiosk,jukebox,zaak,kroeg,bar,personeel,ipad,muziek,scherm,skin`

**Description**:
> Secret DJ Kiosk maakt van een iPad een self-service jukebox voor je
> zaak. Log één keer in met je zaak-account en hij draait de hele dag
> — gasten bladeren, zoeken en vragen nummers aan op je Secret
> DJ-jukebox, zonder tussenkomst van personeel.
>
> **Wat het doet**
> - Draait liggend, de hele dag, met een lokscherm tussen gasten door.
> - Toont wat er speelt en laat gasten bladeren of zoeken naar een
>   nummer om aan te vragen.
> - Neemt de look van jouw zaak over via server-beheerde skins — geen
>   aparte instelling op het toestel nodig.
> - Herstelt zelfstandig van netwerkstoringen en keert automatisch
>   terug naar het lokscherm.
>
> **Voor je personeel**
> - Eén keer inloggen per iPad, gekoppeld aan jouw zaak.
> - Een ingebouwde personeelsreset wist de sessie en de gecachte skin
>   zonder het toestel opnieuw op te starten — handig bij
>   ploegwissels of wanneer de iPad aan iemand anders wordt
>   doorgegeven.
> - Geen klantaccount nodig op de kiosk zelf — Secret DJ Kiosk logt
>   alleen in als jouw zaak.
>
> Dit is een complete herbouw van de zaak-terminal: opnieuw ontworpen
> voor betrouwbaarheid tijdens een lange dienst, met dezelfde
> self-service jukebox die je gasten al kennen.

**What's new (this version)**:
> Secret DJ Kiosk is helemaal opnieuw gebouwd voor meer
> betrouwbaarheid: stabieler de hele dag door, een vernieuwde
> personeelsreset, en soepeler herstel na netwerkstoringen. Inloggen
> en de skin van jouw zaak werken precies zoals voorheen.

---

## Notes and tensions for the product owner

- **Distribution channel is unconfirmed.** This draft assumes a public
  App Store listing (same as the consumer app, per D14's "ship as
  updates" resolution and the kept bundle id `com.secretdj.kiosk`).
  LEGACY.md flags real uncertainty here: an abandoned-looking Ad Hoc
  configuration (`com.c-burn.kiosk`, a different team) exists
  alongside the public one, and LEGACY.md's own open questions list
  asks "whether the Ad Hoc kiosk bundle id... is still a live
  distribution channel" (LEGACY.md, "Gaps and cross-checks"). If the
  kiosk is actually installed via Apple Business Manager / a private
  channel rather than public App Store search, this metadata (and
  especially the keyword-optimization framing) may not apply the same
  way — worth confirming before treating this draft as final.
- **App name unchanged from legacy** — `PRODUCT_NAME = "Secret DJ
  Kiosk"` per LEGACY.md's build-settings table; kept as the safe
  default here too.
- **Tone is intentionally flatter than the consumer app's.** The
  kiosk's audience is venue staff configuring hardware, not a
  consumer scrolling the Store for fun — no cheeky asides, per the
  localization skill's context dial putting operational/system-style
  copy at the plain end of the register.
- **Field-limit tension:** none blocking. All languages' Subtitle and
  Keywords fit within Apple's hard caps (counts given inline); German
  again needed deliberate abbreviation to stay under 30 characters for
  the subtitle, consistent with the consumer app's draft.
