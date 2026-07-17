# 42 – Watch design-implementációs terv (F4B → F4-design → F5 → F6)

Státusz: **terv, 2026-07-17 — még semmi nem indult el belőle.**
Kapcsolódó dokumentumok:
- [40-watch-app-plan.md](40-watch-app-plan.md) — az implementációs terv; az F4B design-adósság kód ellen ellenőrzött listája a **12. fejezetében** (B1–B15) — ez a doc arra hivatkozik, nem ismétli meg
- [41-watch-design-prompt.md](41-watch-design-prompt.md) — a design-prompt (brand-tokenek, típusskála, F5/F6 koncepció-specifikáció)
- `docs/watch/design/Lifey Watch Design.dc.html` — a leszállított design canvas (F4-scope: Apple Watch 01–07, Wear OS 01–06, dynamic sizing, telefon A–C)

**A sorrend elve** (a felhasználói döntés szerint): előbb az F4B **funkciók** lefejlesztése (a design frame-jei enélkül nem építhetők meg), utána a design-styling ráhúzása az immár teljes F4-scope-ra; F5 és F6 esetén fordított a helyzet — ott **előbb a design** készül el (a canvas ma nem tartalmaz F5/F6 frame-et), és csak utána az implementáció.

```
D0 (döntések) → D1 (F4B fejlesztés) → D2 (F4 design-rendszer + styling) → D3 (F5 design → dev) → D4 (F6 design → dev)
```

A watchOS- és Wear OS-lépések végig külön oszlopban/szekcióban futnak, ahogy a canvasban is külön sorban vannak — a két platform UI-kódja nem közös, csak a viselkedési specifikáció.

---

## D0 — Design-döntések implementáció előtt

Ezek a 40-es doc 12.5-ben azonosított canvas-hiányok/ellentmondások; mindet érdemes az F4B-kódolás **előtt** lezárni, mert képernyő-struktúrát érintenek:

| # | Döntés | Javaslat |
|---|---|---|
| D0.1 | **Eltelt idő színe**: prompt §2.6 szerint `onSurface` (neutrális), canvas szerint primary olive | Canvas követése (primary olive) — a canvas a frissebb, vizuálisan ellenőrzött állapot; a prompt §2.6 csak „suggested mapping” volt |
| D0.2 | **„GO”-pillanat** (prompt §3.4): kell-e dedikált vizuális állapot, és milyen? A canvas csak „snaps back to metrics”-et ír | Minimál-verzió: 1–1,5 mp `primary`-fill pulse a metrika-képernyőre visszaváltáskor — nem külön képernyő, csak átmenet; frame-et utólag pótolni a canvasba |
| D0.3 | **Ambient/always-on variáns** (prompt §6 kérte, canvas nem tartalmazza): F4-design-scope vagy későbbi? | F4-design-scope-ban tervezendő meg (1 frame), de az implementációja külön tétel — watchOS-en az `.luminanceToDisplay` / TimelineView-alapú dimmelés, Wear-en az `AmbientLifecycleObserver` külön munka |
| D0.4 | **⌚ badge adatforrása** (B15): kell-e új mező, vagy elég a meglévő? | **✅ Eldőlt (2026-07-17): nem kell új mező** — a manuális Health-import megszűnt (40-es doc 7.5.8), gazdagítás csak watch-summaryból jöhet; a meglévő flag/getter átnevezése (`fromAppleHealth` → pl. `enrichedFromWatch`) + badge-csere elég |

---

## D1 — F4B: a hiányzó funkciók lefejlesztése (design előtt)

A tételek a 40-es doc 12. fejezetének B-számaira hivatkoznak. Styling itt még **nincs** — minden stock-widgettel készül, hogy a D2 styling-fázis tiszta, tisztán vizuális diff legyen.

### D1.1 Közös előfeltétel: fázismodell-bővítés

Mindkét platform mai 2-fázisú állapotgépe (`IDLE`/`ACTIVE`) kevés a design képernyőihez. Új, közös fázismodell (a két platformon tükör-implementációval):

```
IDLE → ACTIVE → ENDING (End megnyomva, telefonra várunk — AW 05)
             → SUMMARY (end visszaért, összegzés látszik, auto-dismiss → IDLE — AW 06)
IDLE/ACTIVE → ERROR(startRejected | healthDenied) (AW 07, Wear 05)
```

- iOS: `WorkoutManager.phase` bővítése + `ContentView` switch-e.
- Wear: `SessionStateHolder.SessionPhase` bővítése + `MainActivity` when-je.
- A `SUMMARY` fázishoz a watch-oldalon meg kell őrizni a záró összegzést (idő/kcal/átlag-HR) a summary-küldés után is, az auto-dismiss timerrel (~6 s).

### D1.2 watchOS-sáv (LifeyWatch)

| Tétel | F4B-hivatkozás | Tartalom |
|---|---|---|
| W1 | B7 | `ActiveWorkoutView` kettébontása `TabView`-ra: 1. metrika-lap, 2. controls-lap (End + Pause), Apple Workout-lapozási minta, page-dots |
| W2 | B3 | Pause/Resume: `HKWorkoutSession.pause()`/`.resume()` a controls-lapról — csak a szenzor-session, a telefon-időzítést nem érinti; pauzált állapot jelzése a metrika-lapon |
| W3 | B8 | `ENDING` fázis + „Finish on your iPhone” képernyő: `requestEnd()` után átváltás; a szenzorok tovább mérnek, amíg a valódi `end` be nem ér (a meglévő 8.2/1b viselkedés változatlan) |
| W4 | B9 | `SUMMARY` fázis + „Workout saved” képernyő (idő, átlag bpm, kcal, „Saved to Health”), ~6 s auto-dismiss → `IDLE` |
| W5 | B10 | `ERROR(healthDenied)` képernyő „Review access” akcióval (watchOS-en a Settings-deeplink korlátozott — minimum: instrukció + dismiss → `IDLE`) |
| W6 | B1 | Rest-hero állapot a metrika-lapon: a rest átveszi a hero-pozíciót, „of &lt;teljes idő&gt;” + „Next · …” sor; **a teljes rest-hossz** ehhez kell a state-payloadban (ma csak `restEndsAtEpochMs` megy — kis Dart-oldali bővítés: `restTotalSeconds` kulcs a `WorkoutSessionState`-ben, mindkét platform hídján át) |
| W7 | B2, D0.2 | GO-pillanat: a rest-lejáratkor a haptika mellé vizuális pulse-átmenet |

### D1.3 Wear OS-sáv (wear-modul)

| Tétel | F4B-hivatkozás | Tartalom |
|---|---|---|
| A1 | B11 | `ActiveWorkoutScreen` átépítése `ScalingLazyColumn`-ra: metrikák felül, controls-szekció (End workout + Pause) lejjebb görgetve, `PositionIndicator` |
| A2 | B3 | Pause/Resume: `ExerciseClient.pauseExercise()`/`.resumeExercise()` az `ExerciseService`-en át; pauzált jelzés a UI-n |
| A3 | B12 | `ERROR(startRejected)` fázis + „Workout already running” képernyő OK gombbal (a telefon-oldali snackbar marad, ez az óra-oldali párja) |
| A4 | B13 | Degradált HR-állapot: engedély-hiány esetén „––” placeholder + „Heart rate off — allow sensors” chip, tap → a `MainActivity` meglévő engedélykérő flow-ja |
| A5 | B8/B9 Wear-megfelelője | `ENDING`/`SUMMARY` fázisok a Wear-oldalon is (a canvas Wear-sora nem rajzolta meg őket — a D2 design-fázisban 2 új Wear-frame kell hozzá, lásd D2.4; addig az iOS 05/06 frame viselkedési specifikációja az irányadó) |
| A6 | B1, B2 | Rest-hero + GO-pillanat, a W6/W7-tel azonos viselkedés (bezel-ring a progress-indikátor, canvas Wear 04 szerint) |

### D1.4 Telefon-sáv (Flutter)

| Tétel | F4B-hivatkozás | Tartalom |
|---|---|---|
| P1 | B14 | „Measuring” ⌚-pill a log-képernyő fejlécében: a `startedOnWatch` eseményre jelenik meg, session-végén / reachability-vesztésnél tűnik el |
| P2 | B15, D0.4 | ⌚ „Watch” badge a session-kártyán a „Health” badge helyett; flag/getter-átnevezés megfontolása |
| P3 | W6-hoz | `WorkoutSessionState` bővítése `restTotalSeconds`-szel (Dart + mindkét natív híd + watch-oldali dekódolás — apró, de 4 kódhelyet érint) |

### D1.5 F4B tesztelés

A 40-es doc §9 mátrixa kiegészül: End→ENDING→end-visszaút→SUMMARY→auto-dismiss kör; pause alatt érkező state-frissítés; startRejected az óra-képernyőn; HR-megtagadás „––”-úton; **és ez a kör legyen az az alkalom, amikor a 11.5-ben hátralévő watchOS-szimulátoros manuális teszt is lefut** (az F4 + F4B egyben tesztelhető).

---

## D2 — F4 design-styling (az F4B után, arra épülve)

### D2.1 Közös design-rendszer alap (egyszeri munka, platformonként)

| Tétel | watchOS | Wear OS |
|---|---|---|
| Szín-tokenek (prompt §2 teljes palettája) | `LifeyWatch/Theme/LifeyColors.swift` — `Color`-konstansok (`bg`, `surface`…, `heart`, `calories`, `error`-család) | `wear/.../ui/theme/LifeyColors.kt` + Wear `MaterialTheme` `Colors` felülírás |
| Tipográfia (prompt §1 skála: hero 800 tabular, label uppercase tracked) | SF Rounded + `.monospacedDigit()`; súly/méret-ramp helper | Rendszer-font + `FontFamily`-ramp, `fontFeatureSettings: "tnum"` |
| Radius-skála (8/16/20/24/pill) | konstansok | konstansok |
| Ikonok | SF Symbols (♥ `heart.fill`, láng `flame.fill`, timer, stop, pause…) | Material Symbols megfelelők |
| Dynamic sizing (B4) | `ViewThatFits` + %-inset helper a 41→45 mm skálázáshoz | `BoxWithConstraints`-frakciók 1.2″→1.4″-hez |

### D2.2 watchOS frame-ek stylingja (canvas AW 01–07 sorrendben)

1. **01 Idle**: eco-jel + „Lifey” wordmark, calm brand-moment (B5).
2. **02 Metrika-lap**: „STRENGTH” fejléc-chip, hero eltelt idő (D0.1 döntés szerint), ♥ HR rose + 🔥 kcal orange ikonos metrika-sor, gyakorlat-kártya + szett-pill (`containerHighest`).
3. **03 Rest-hero**: drain-elő ring, `primary` → utolsó 5 mp `negative` színváltás, „Next · …” sor.
4. **04 Controls-lap**: End = `errorContainer`-fill + `onErrorContainer` szöveg, Pause másodlagos; ≥48 px tap-targetek.
5. **05 ENDING**: telefon-glyph + két szövegsor, muted.
6. **06 SUMMARY**: check `tertiary`, három stat-tile, „Saved to Health” sor.
7. **07 Health-denied**: `error`-család, „Review access” gomb.
8. **Ambient-variáns** (D0.3): fekete háttér, outline-tipó, másodperc-tick nélkül — előbb 1 frame a canvasba, aztán implementáció.

### D2.3 Wear OS frame-ek stylingja (canvas Wear 01–06 + 2 új frame)

1. **01 Idle**: azonos brand-moment.
2. **02 Metrikák**: `ScalingLazyColumn`-ban a designolt kártyák; curved `TimeText`.
3. **03 Controls-szekció**: End/Pause gombok a design szerint.
4. **04 Rest-hero**: bezel-ring progress, színváltás.
5. **05 Already-running hiba**: `errorContainer` dialógus.
6. **06 Degradált HR**: „––” muted + engedély-chip.
7. **Új frame-ek a canvasba**: Wear ENDING + SUMMARY (a D1.3/A5 párja — a canvas Wear-sora ma nem tartalmazza; az iOS 05/06 adaptálása round-Compose-ra).
8. **Ambient-variáns** (D0.3) — Wear-oldali frame is.

### D2.4 Telefon-oldali styling (canvas A–C)

- **A Settings-sor**: már létezik, a canvas szerinti ikon/alcím-finomítás.
- **B „Measuring” pill + startRejected-snackbar**: a P1-ben lefejlesztett pill design szerinti kinézete; a snackbar meglévő `AppSnackbar`-stílusban marad.
- **C Session-kártya**: ⌚ badge + a három stat (kcal/bpm/idő) canvas szerinti metric-accent színei — a mobil-téma tokenjei már léteznek, ez kis diff.

### D2.5 Kilépési feltétel

Minden canvas-frame-nek van 1:1 megfelelője a futó appban (szimulátor/emulátor screenshot-összevetés), 41 mm / 1.2″ méreteken is; a canvasba visszapótolva: GO-frame, ambient-frame-ek, Wear ENDING/SUMMARY.

---

## D3 — F5: set-logolás a watchról (design → fejlesztés)

Az F5 **funkcionális** terve a 40-es doc F5-fázisa (telefon marad a mester, a watch `logSet` eseményt küld, csak elérhető telefon mellett). Itt a **design-lépések** vannak; a canvasban ma **nincs** F5-frame, tehát a design-munka a nulláról indul a prompt §4 specifikációja szerint.

### D3.1 Design-fázis (a 41-es prompt §4 négy frame-je, platformonként külön)

| Frame | watchOS-változat | Wear OS-változat |
|---|---|---|
| 1. Log-set kontroll elhelyezése | Döntendő: külön TabView-lap vs. nagy alsó gomb a metrika-lapon; „a legkönnyebb tap az egész órán” — javaslat: nagy alsó gomb, mert a lapozás izzadt kézzel bizonytalan | Ugyanaz a kérdés `ScalingLazyColumn`-kontextusban: fix alsó gomb (nem görgethető el) vs. lista-elem; + rotary-interakció megfontolása |
| 2. Megerősítés-feedback | Szett-pill increment (2/4→3/4) `positive` mikro-animációval + haptika; ha a telefon rest-et indít, a rest-hero átmenet láncolva | Azonos viselkedés, Compose-animációval; bezel-ring induló animáció |
| 3. Reps/súly-állítás (másodlagos) | Digital crown stepper — de a default flow egy-tapos „ahogy tervezve” | Rotary bezel stepper — ugyanaz az elv |
| 4. Telefon-nem-elérhető állapot | Gomb ghosted + „Phone not reachable” magyarázat | Azonos, + a Wear reachability-jelzés (`NodeClient`) sajátosságai |

Kimenet: a canvas bővítése egy „F5 — set logging” sorral (4+4 frame), HU-stringkulcs-listával (`log_set_button`, `log_set_confirmed`, `phone_unreachable`…).

### D3.2 Fejlesztés-fázis (a design elfogadása után)

1. Dart: `WatchWorkoutService.events`-be új `setLoggedOnWatch` esemény (a channel-terv D3 már nevesíti); a `LogSessionScreen` a meglévő set-logolási útra köti (telefon logol → state-frissítés megy vissza → a watch-pill a visszaérkező state-ből frissül, nem lokálisan — így nincs kétirányú merge).
2. watchOS: log-set gomb + `sendMessage` (`isReachable`-guard, unreachable-állapot a designolt módon); crown-stepper opcionális második ütem.
3. Wear: ugyanez `MessageClient`-tel + reachability-detektálás; rotary-stepper második ütem.
4. Teszt: dupla-tap elleni debounce, unreachable-út, a visszaérkező state-frissítés köre.

---

## D4 — F6: standalone indítás a watchról (design → fejlesztés)

Az F6 funkcionálisan a legnagyobb falat (a 40-es doc szerint külön tervezést igényel — ütközés a resume-prompt logikával); a design itt is **megelőzi** az implementációt, és a design-fázis szándékosan korán készül el, hogy a funkcionális tervezés a képernyőkből indulhasson. A canvasban ma **nincs** F6-frame; a prompt §5 a specifikáció.

### D4.1 Design-fázis (prompt §5 négy frame-je, platformonként)

| Frame | watchOS-változat | Wear OS-változat |
|---|---|---|
| 1. Idle → launcher | Az Idle (D2.2/01) kap egy `primary`-fill „Start workout” gombot | Azonos evolúció; a standalone=false meta-data → true váltás következményeit a dev-fázis kezeli |
| 2. Pre-start picker | Rövid vertikális lista: „Quick strength” + néhány friss terv; `List`-carousel, kártya = `container` bg, radius 20 | `ScalingLazyColumn`-picker, azonos kártyastílus |
| 3. Standalone aktív képernyő | A D2.2/02 metrika-lap + diszkrét „not connected” jelző; az F5 log-set kontroll újrahasznosítva, lokálisan | Azonos, Wear-változatban |
| 4. Sync-állapot | „Will sync to phone” összegző kártya (idő/kcal/átlag-HR/szettek), synced `tertiary`-check vs. pending muted glyph | Azonos |

Kimenet: canvas „F6 — standalone” sor (4+4 frame) + string-kulcsok.

### D4.2 Fejlesztés-fázis (vázlat — a részletes terv a 40-es doc F6-tervezésekor készül)

1. **Külön funkcionális tervdoc kell először** (a 40-es doc is jelzi): watch-oldali lokális session-tárolás, kapcsolódáskori session-kreálás a telefonon, resume-prompt-ütközés feloldása, template-lista szinkron a watchra (ez új, telefon→watch adatirány).
2. watchOS: picker + lokális `HKWorkoutSession`-indítás + queued summary (`transferUserInfo` már queue-ol).
3. Wear: standalone-flag váltás, picker, lokális rögzítés + Data Layer-queue.
4. Telefon: bejövő „standalone session” → session-kreálás a meglévő outbox-útra.

---

## Sorrend és becslés (összefoglaló)

| Ütem | Tartalom | Becslés | Előfeltétel |
|---|---|---|---|
| D0 | 4 design-döntés lezárása | S | — |
| D1 | F4B fejlesztés (fázismodell + W1–W7 + A1–A6 + P1–P3 + teszt) | M–L | D0 |
| D2 | F4 design-rendszer + minden frame stylingja + canvas-pótlások | L | D1 |
| D3 | F5 design (4+4 frame), majd fejlesztés | M (design) + M–L (dev, a 40-es doc becslése) | D2 (a design-rendszerre épül) |
| D4 | F6 design (4+4 frame), majd külön funkcionális terv + fejlesztés | M (design) + L (dev) | D3 (az F5 log-set kontrollt újrahasznosítja) |

Megjegyzés: a D1 (F4B) és a D2 elején lévő design-rendszer-alap (D2.1) részben párhuzamosítható — a token-fájlok a funkcionális munkát nem zavarják.
