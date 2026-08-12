# 59 – Cardio: fejlesztési terv (lépésekre bontva)

Státusz: **KÉSZ TERV, a fejlesztés nem indult el.** A design **elkészült** (§1), tehát minden
UI-t szállító lépés indítható.
Előzmény: [51](51-cardio-overview-plan.md) (iterációk, kockázatok), [52](52-cardio-domain-backend-plan.md) (séma),
[53](53-cardio-mobile-plan.md) (mobil), [54](54-cardio-gps-route-plan.md) (GPS),
[55](55-cardio-watch-plan.md) (óra), [56](56-cardio-statistics-plan.md) (statisztika),
[57](57-cardio-design-prompt.md) (design prompt), [58](58-cardio-web-plan.md) (web).

> **Mi ez a doc, és mi nem.** Ez a **végrehajtási** terv: az 51-es doc iterációit (C0, C1, C2 …)
> **prompt-méretű lépésekre** bontja, mindegyikhez megadva az érintett fájlokat, a hozzá tartozó
> **design-frame-et** és a *kész-ha* feltételt. A *miért* és a döntések a fenti docokban vannak —
> itt nem ismételjük meg őket, csak hivatkozunk rájuk.
>
> **Egy lépés = egy beszélgetés = egy commit.** Ha egy lépés nem fér el ennyiben, az a lépés
> rosszul van vágva — bontsd tovább, ne told ki a határt.

---

## 1. A design elkészült (2026-08-10)

| Canvas | Tartalom |
|---|---|
| [`design/Lifey Cardio Design.dc.html`](design/Lifey%20Cardio%20Design.dc.html) | **Mobil**: M01–M29 (sötét téma, magyar) · M30–M32 (világos téma, angol minta) · **Web**: W01–W02 · mozgás/haptika-terv · nyitott termékkérdések |
| [`design/Lifey Cardio Watch Design.dc.html`](design/Lifey%20Cardio%20Watch%20Design.dc.html) | **Apple Watch**: AW 16–22 · **Wear OS**: W 15–21 — a meglévő watch-canvas számozásának folytatása |

**Ezzel az [51 §4](51-cardio-overview-plan.md) design-blokkolása feloldva**: a C2, C3, C5 és a
C6+ iterációk kódolása elindulhat.

### 1.1 Frame-leltár → melyik lépés használja

| Frame | Tartalom | Lépés |
|---|---|---|
| M01 · M02 · M03 | Gyorsindító lap · hidegindítás · „Összes” kibontva | C2.6, C2.7 |
| M04 · M05 | Aktív DISTANCE · MACHINE | C2.2, C2.3 |
| M06 · M07 | Aktív GAME — pályán · padon | C2.4 |
| M08 · M09 | Kézi szünet · **auto-pause** (vizuálisan elkülönítve) | C2.5, C4a.5 |
| M10 | Gyenge GPS-jel | C4a.4 |
| M11 | **Nincs távforrás** — futópad / GPS nélkül (a domináns szám idő lesz) | C2.2 |
| M12 | Befejezés — húzás közben | C2.5 |
| M13 · M14 · M15 | Összegzés útvonallal · legörgetve (értékelés + „szerkesztve”) · útvonal nélkül | C2.8 (M15), C4a.6 (M13) |
| M16 | Túra — magasságprofil + GPS-hézag | C4a.6, C8 |
| M17 · M18 | Kézi rögzítés — DISTANCE · GAME | C1.8, C1.9 |
| M19 · M20 | Edzéslista mind a hét típussal · fajta-szűrő | C1.6, C1.7 |
| M21 · M22 | Statisztika vegyes hét · nincs adat erre a fajtára | C3.3, C3.4 |
| M23 · M24 | iOS Live Activity · Dynamic Island | C2.9, **C2.10b** |
| M25 | Android tartós értesítés | C2.9, **C2.10a** |
| M26 · M27 · M28 | Engedély-magyarázó · megtagadva · véglegesen megtagadva / pontatlan | C4a.2 |
| M29 | Kezdőképernyő-widget (közepes + kicsi) | **C2.11a**, **C2.11b** |
| M30 · M31 · M32 | Világos téma + angol minta | **minden UI-lépés kilépési feltétele** |
| W01 · W02 | Web `ActivityChip` · web lista-sor | C1w.2, C1w.3 |
| AW 16 / W 15 | Egyesített indító lista | C5.4 |
| AW 17–20 / W 16–19 | Aktív cardio ×3 család + GAME padon | C5.5, C5.6 |
| AW 21 / W 20 | Összegzés + szinkron | C5.7 |
| AW 22 / W 21 | Gyenge jel · nincs pulzus | C5.5 |

**Nincs frame nélküli UI-lépés, és nincs lépés nélküli frame** — a kettő fedi egymást.

### 1.2 Amit a design szándékosan nyitva hagyott (termékdöntés)

A canvas 15. szekciója négy kérdést tesz fel. Mindegyik mellé odaírtam, **mikor válik
blokkolóvá** — addig nem kell dönteni:

| # | Kérdés | Blokkol ettől |
|---|---|---|
| Q-D1 | A splitek megjelenítési mélysége mobilon (csak km+tempó, vagy szint+pulzus is), és javítható-e kézzel egy szakasz | **C6** (futás-specifikum) |
| Q-D2 | A GAME pont/gól-számláló alapból látszik-e (javaslat: rejtve, egyszeri felajánlással) | **C2.4** |
| Q-D3 | Az auto-pause alapból be van-e kapcsolva, és típusonként külön-e | **C4a.5** |
| Q-D4 | **Eldöntve** (2026-08-12): egyenrangú, nincs extra jelzés — a kézzel szerkesztett (MANUAL-source) érték simán belemegy a heti/statisztikai összegbe, ugyanúgy, mint egy mért érték; az összesítés szintjén nincs megkülönböztetés. A session-részletnézet R8 szerint továbbra is mutatja a "kézzel szerkesztve" jelölést. Ez már a C3.1-ben leszállított `sum*Since` lekérdezések tényleges viselkedése is (nincs `distanceSource` szűrés) — C3.2-nek ehhez nincs extra munkája. | – |

---

## 2. A sorrend elve

Négy szabály döntötte el a lépések sorrendjét — ha valamit előre akarsz hozni, ezekbe ütközöl:

1. **Az audit legelöl.** A meglévő szett-feltételezések javítása (C0) *azelőtt* történik, hogy
   bármilyen cardio adat létezne — így regressziómentesen tesztelhető, és nem keveredik az új
   funkcióval ([51 R1](51-cardio-overview-plan.md)).
2. **A fogadó előbb, mint a küldő.** A szerver előbb fogadja el a cardio payloadot, mint hogy a
   kliens küldeni tudná; a telefon-oldali watch-feldolgozó előbb kész, mint a natív watch-küldő
   ([55 D-C5.4](55-cardio-watch-plan.md)). Így félkész oldal sosem termel feldolgozhatatlan adatot.
3. **Minden mérföldkő végén szállítható az app.** Nem maradhat félig bekötött képernyő két
   beszélgetés között.
4. **A GPS a legvégén a mag-funkcióhoz képest.** A C2 végén az élő cardio GPS nélkül is teljes
   ([54 §1](54-cardio-gps-route-plan.md)) — ha a GPS csúszik, semmi nem áll miatta.

### 2.1 Szállítási mérföldkövek

| MF | Mit lát a felhasználó | Iterációk |
|---|---|---|
| **MF1** | Semmit — de az app stabil marad üres session-öknél | C0 |
| **MF2** | Kézzel rögzíthet cardio edzést, a lista ikonos és szűrhető | C1 |
| **MF3** | Élőben futtathat cardio edzést, gyorsan indítja, a zárolási képernyőn látja | C2 |
| **MF4** | A statisztika helyes és fajtánként szűrhető; a weben is látszik | C3, C1w, C3w |
| **MF5** | Kültéren nyomvonalat rögzít, és az órájáról is indíthat | C4a, C5 |
| **MF6** | Sport-specifikus finomságok | C6–C9 |

---

## 3. C0 — Fundamentum (5 lépés) · MF1

| # | Lépés | Fájlok | Kész-ha |
|---|---|---|---|
| **C0.1** ✅ | Backend enumok: `SessionKind`, `ActivityType`, `ActivityFamily` | `workout/session/SessionKind.java`, `workout/session/cardio/` | Fordul, a család a típusból származik ([52 D-C1.5](52-cardio-domain-backend-plan.md)) |
| **C0.2** ✅ | Dart taxonómia: `activity_type.dart` (kódlista, label, **ikon**, **szín**, család) + ARB-kulcsok EN/HU | `features/workouts/domain/activity_type.dart`, `l10n/` | Az ikon-/szín-térkép **bitre az M01 frame** szerint; unit-teszt a kód↔label teljességre |
| **C0.3** ✅ | **Audit**: minden `sets`/`exercises`/`templateName` olvasási hely `kind`-tudatossá vagy üres-tűrővé tétele | [53 §0.1](53-cardio-mobile-plan.md) — audit-eredmény | Üres session minden képernyőn megnyitható, nem dob, nincs „0 gyakorlat” folt — a teszt bent marad a suite-ban |
| **C0.4** ✅ | Egyetlen `kind`-elágazási pont: `open_workout_screens.dart` (+ `workout_resume_prompt`), a cardio ág egyelőre `TODO` | `presentation/open_workout_screens.dart`, `application/workout_resume_prompt.dart` | Az elágazás **egy** helyen van; a strength út változatlan |
| **C0.5** ✅ | `recommended_template_provider` és a PR-motor erősítő-szűrője | `application/recommended_template_provider.dart`, `domain/personal_record.dart` | Cardio session nem visz zajt a terv-ciklusba, és nem termel erősítő PR-t |

---

## 4. C1 — Adat-mag és kézi rögzítés (9 lépés) · MF2

**Backend (C1.1–C1.4)** — a fogadó előbb.

| # | Lépés | Fájlok | Kész-ha |
|---|---|---|---|
| **C1.1** ✅ | V66 migráció: `session_kind`, `activity_type`, `moving_seconds` + CHECK + parciális index; entitás-mezők | `db/migration/V66__*.sql`, `WorkoutSession.java` | Meglévő sorok `STRENGTH`-ek; a CHECK sértése elbukik (teszt) |
| **C1.2** ✅ | V67 `cardio_details` + `CardioDetails` entitás (1:1) | `V67__*.sql`, `cardio/CardioDetails.java` | Cascade-törlés működik |
| **C1.3** ✅ | V68 `cardio_splits` + `CardioSplit` entitás | `V68__*.sql`, `cardio/CardioSplit.java` | Egyedi `(session, index)`; a splitek kliensről jönnek, nem itt számolódnak |
| **C1.4** ✅ | DTO-bővítés + mapper + **keresztmezős validáció** + `?kind=` szűrő + **`updatedAt`-bump** | `dto/`, `WorkoutSessionMapper`, `service/WorkoutSessionServiceImpl`, `WorkoutSessionController` | Régi kliens payloadja `STRENGTH`-et ad; `exercises: []` sosem null; **„csak a cardio-blokk változott” → a session `updatedAt`-je nő és megjelenik a deltában** ([52 §4](52-cardio-domain-backend-plan.md)); Postman frissítve |

**Mobil adatréteg (C1.5)**

| # | Lépés | Fájlok | Kész-ha |
|---|---|---|---|
| **C1.5** ✅ | Drift-táblák + séma-migráció + domain-bővítés + repository (create/update/pull, payload-builder, outbox-bump) + `watchByKind` + `CardioFormatter` | `core/local_db/tables/workout_session_tables.dart`, `domain/workout_session.dart`, `data/workout_session_repository.dart`, `core/format/` | Cardio session offline létrehozható és delta-synccel átér; a **`STRENGTH` payload bájtra azonos a maival** (regressziós teszt); metric/imperial formázás tesztelve |

**Mobil UI (C1.6–C1.9)**

| # | Lépés | Frame | Fájlok | Kész-ha |
|---|---|---|---|---|
| **C1.6** ✅ | `ActivityChip` (20/32/56 px) + session-kártya ikon-chippel és családfüggő fő metrikával | **M19** | `shared/widgets/activity_chip.dart`, `presentation/sessions_tab.dart`, `session_row_plan.dart` | Mind a hét típus renderel; az erősítő kártya vizuálisan változatlan, csak chipet kap |
| **C1.7** ✅ | Fajta-szűrő (mind / erősítő / cardio) + másodlagos típus-szűrő | **M20** | `presentation/workouts_screen.dart` | A szűrő állapota megmarad tab-váltáskor |
| **C1.8** ✅ | `LogCardioSheet` — típusválasztó, dátum/idő (múltbeli is), időtartam, DISTANCE + MACHINE mezők | **M17** | `presentation/log_cardio_sheet.dart` | Minden numerikus mező `MANUAL` forrásjelzést kap; múltbeli dátum menthető |
| **C1.9** ✅ | `LogCardioSheet` GAME ága (intenzitás, helyszín, opcionális box score) + RPE/jegyzet újrahasznosítás + olvasó összegzés-nézet | **M18**, M15 | ua. + `presentation/cardio_summary_screen.dart` | A GAME mezők a családhoz kötöttek; a mentett edzés megnyitható és olvasható |

---

## 5. C2 — Élő cardio, gyorsindítás, élő felületek (13 lépés) · MF3

C2.1–C2.9 tiszta Flutter/Dart — natív platform-kód nélkül, **Windowson is fejleszthető és
tesztelhető** (ugyanúgy, ahogy a C0/C1 eddig ment). C2.10 és C2.11 viszont platformspecifikus
natív kódot is visz (iOS: Swift/SwiftUI a `LifeyWidgets` Xcode-targetben — [24-es
doc](../24-ios-widget-live-activity-plan.md); Android: Kotlin — [25-ös
doc](../25-android-widget-ongoing-notification-plan.md)), ezért mindkettő **a/b lépésre bontva**:
az **a** ág Android + a platformfüggetlen Dart-rész, Windowson kész; a **b** ág iOS, **Xcode-ot,
tehát Mac-et igényel**. A kész-ha ettől függetlenül lépésenként külön áll — az a/b nem egy
lépés két fele, hanem két önálló, egymástól függetlenül szállítható lépés.

| # | Lépés | Platform | Frame | Kész-ha |
|---|---|---|---|---|
| **C2.1** ✅ | `CardioSessionScreen` váz: állapotgép (`IDLE→RUNNING⇄PAUSED→ENDING→SUMMARY`), ticker, **minden állapotváltás driftbe írva** | Windows | – | App-kilövés után az edzés helyreáll a pontos mozgásidővel |
| **C2.2** ✅ | DISTANCE elrendezés + a **„nincs távforrás”** ág (domináns szám időre vált) | Windows | **M04**, **M11** | A domináns szám a [57 §2](57-cardio-design-prompt.md) szabálya szerint vált; nincs „0,00 km” nagy helyen |
| **C2.3** ✅ | MACHINE elrendezés | Windows | **M05** | Kadencia/teljesítmény/ellenállás bevihető menet közben |
| **C2.4** ✅ | GAME elrendezés + **pályán/padon kapcsoló** (a `movingSeconds` csak „pályán” nő) | Windows | **M06**, **M07** | A játékidő és a bruttó idő külön viselkedik (teszt); *(Q-D2 nem oldva meg, ld. C2.4 feljegyzés — pontszámláló C9-re halasztva)* |
| **C2.5** ✅ | Szünet-állapotok (kézi vs. **auto-pause vizuálisan elkülönítve**) + befejezés húzással | Windows | **M08**, **M09**, **M12** | Az auto-pause más, mint a kézi; a befejezés koppintásra **nem** történik meg |
| **C2.6** ✅ | `activity_ranking.dart` — recency-súlyozott rangsor (21 napos felezés), tisztán tesztelhető | Windows | – | Felezés, döntetlen-feloldás, hidegindítás, vegyes lista mind tesztelve ([53 §3.4](53-cardio-mobile-plan.md)) |
| **C2.7** ✅ | Gyorsindító lap a FAB hosszú nyomására + „Összes” aktivitás-választó | Windows | **M01**, **M02**, **M03** | Hosszú nyomás + egy koppintás = fut az edzés, köztes képernyő nélkül |
| **C2.8** ✅ | Összegzés-képernyő (útvonal nélküli változat) + RPE + kézi szerkesztés „szerkesztve” jelöléssel | Windows | **M15**, **M14** | A szerkesztett érték felülírja a mértet, és jelölve marad ([51 R8](51-cardio-overview-plan.md)) |
| **C2.9** ✅ | `WorkoutSessionState` `kind`+`cardio` bővítés (előformázott stringek, epoch-alapú idő) | Windows | – | Régi natív build a `STRENGTH` ágra esik vissza, nem törik |
| **C2.10a** ✅ | Android tartós értesítés cardio-layout | Windows | **M25** | Nem „0 szett” látszik az Android értesítésben; frissítés csak változásra |
| **C2.10b** ✅ | iOS Live Activity + Dynamic Island cardio-layout | **Mac** | **M23**, **M24** | Nem „0 szett” látszik a zárolási képernyőn / Dynamic Islanden; frissítés ≤ 5 mp és csak változásra (ActivityKit-kvóta) |
| **C2.11a** ✅ | Deep-link route (`go_router`) + Android dinamikus app-shortcutok (`ShortcutManager`, natív híd) + Android kezdőképernyő-widget gombok | Windows | **M29** | Android app-ikon hosszú nyomásából / widgetből **egy** gesztussal indul az edzés; a route C2.11b-nek is kész célpont |
| **C2.11b** ✅ | iOS dinamikus app-shortcutok (`UIApplicationShortcutItem`, natív híd) + iOS kezdőképernyő-widget gombok | **Mac** | **M29** | iOS app-ikon hosszú nyomásából / widgetből **egy** gesztussal indul az edzés |

---

## 6. C3 — Statisztika (5 lépés) · MF4

| # | Lépés | Frame | Kész-ha |
|---|---|---|---|
| **C3.1** ✅ | Backend: repository-lekérdezések + `StatisticsResponse` additív bővítés | – | A meglévő mezők értéke **változatlan** rögzített adathalmazon (teszt) |
| **C3.2** ✅ | Mobil: `StatMetric` bővítés + **`weightedAverage`** aggregációs típus + `effectiveMinutes` szabály | – | A tempó távval súlyozott, 0 távon nem oszt nullával; erősítőnél a régi perc-szabály bitre azonos (Q-D4 eldöntve — lásd §1.2) |
| **C3.3** ✅ | Statisztika-képernyő: fajta-szűrő + cardio-metrikák + hiány-kezelés | **M21**, **M22** | Üres nap ≠ 0 pont ([56 D-C3.5](56-cardio-statistics-plan.md)) |
| **C3.4** ✅ | Dashboard bontás-sor + heti visszatekintő + **streak-küszöb** (15 perc mozgásidő) | – | A küszöb egyetlen konstans, tesztelve |
| **C3.5** ✅ | PR-motor cardio-ága (leghosszabb táv / mozgásidő / szintemelkedés) + edzői heti riport bővítés | – | Cardio nem termel erősítő PR-t és fordítva |

---

## 7. C1w / C3w — Web (5 lépés) · MF4

| # | Lépés | Frame | Kész-ha |
|---|---|---|---|
| **C1w.1** ✅ | `types.ts` + API-réteg átengedi az új mezőket | – | Típusok fordulnak, semmi más nem változik |
| **C1w.2** ✅ | Web `ActivityChip` + lista-sor `kind`-elágazás | **W01**, **W02** | Nincs üres cím és „· 0 szett” |
| **C1w.3** ✅ | **`SessionLogger` `kind`-kapu + olvasó cardio részletnézet** + útvonal-SVG | W02-ből származtatva | Cardio session megnyitása **nem** nyit szett-logolót ([58 W1](58-cardio-web-plan.md)) |
| **C1w.4** ✅ | Edzői kliens-nézet + naptár-előnézet `kind`-elágazása; `recommendation.ts` szűrő; `progress.ts` regressziós teszt | – | Az edző nem lát „0 gyakorlat / 0 kg volumen” cardio edzést ([58 W2](58-cardio-web-plan.md)) |
| **C3w.1** | `aggregate.ts` fajta-szűrő + cardio-adatsorok + dashboard-bontás + **paritás-teszt a mobillal** | – | Azonos bemenetre a web és a mobil ugyanazt a heti összesítést adja |

---

## 8. C4a — GPS és nyomvonal (6 lépés) · MF5

| # | Lépés | Frame | Kész-ha |
|---|---|---|---|
| **C4a.1** | `geolocator` bevezetése + platform-konfiguráció + `LocationService` (engedély- és pozíció-stream, teszt-implementációval) | – | Teszt-implementáció nélkül is fordul minden platformon |
| **C4a.2** | Engedély-utak: magyarázó lap a rendszer-kérdés előtt, megtagadva / véglegesen / pontatlan ágak | **M26**, **M27**, **M28** | **Megtagadott engedéllyel is elindul és menthető az edzés** ([51 D-C.5](51-cardio-overview-plan.md)) |
| **C4a.3** | `CardioTrackPoints` drift-tábla + azonnali pontírás | – | Kilőtt app legfeljebb egy pontot veszít |
| **C4a.4** | `track_filter.dart`: pontosság-/sebesség-/elmozdulás-kapuk, magasság-simítás, haversine-táv + gyenge jel UI | **M10** | Rögzített minta-nyomvonalakon a táv ≤ 5% hibával |
| **C4a.5** | Háttérfutás (Android előtér-szolgáltatás **a meglévő értesítéssel egyesítve**, iOS háttér-mód) + auto-pause bekötése | M09 | **Nem keletkezik két Android értesítés** ([54 §4.4](54-cardio-gps-route-plan.md)); akku ≤ 8%/óra, mérés dokumentálva *(Q-D3 döntés kell)* |
| **C4a.6** | Záró feldolgozás (ritkítás → polyline → outbox-bump, splitek) + `RoutePainter` + magasságprofil + kártya-miniatűr + 90 napos pont-karbantartás | **M13**, **M16** | Az útvonal mindkét témában olvasható; a hézag szaggatott |

---

## 9. C5 — Óra (7 lépés) · MF5

| # | Lépés | Frame | Kész-ha |
|---|---|---|---|
| **C5.1** | **Telefon-oldali fogadó előbb**: `standalone_session_processor` + `watch_session_merge` + `watch_set_log_decision` cardio-ága | – | Cardio payload feldolgozható, mielőtt bárki küldené ([55 D-C5.4](55-cardio-watch-plan.md)) |
| **C5.2** | Indító payload `activityType`/`venue` + `WatchWorkoutService` API-bővítés + állapot-átvitel | – | A `locationType` a `venue`-ból jön, nem találgatásból |
| **C5.3** | Egyesített picker payload (`version: 2`) a `rankQuickStartEntries()`-ből | – | Régi natív build a fallbackre esik, nem renderel ismeretlen sort |
| **C5.4** | watchOS: aktivitástípus-térkép + egyesített indító lista | **AW 16** | A kiemelt „Quick strength” kártya marad legfelül |
| **C5.5** | watchOS: aktív cardio ×3 család + gyenge jel / nincs pulzus | **AW 17–20**, **AW 22** | A pulzus a kiemelt másodlagos metrika |
| **C5.6** | Wear OS: `ExerciseType`/`dataTypes` térkép + ugyanazok a képernyők | **W 15–19**, **W 21** | Nem kérünk olyan adattípust, amit a szenzorkészlet nem tud |
| **C5.7** | Zárás-összegzés bővítés (zónák, táv, szint) + standalone cardio + pályán/padon kétirányú szinkron + **eszközös végpróba** | **AW 21**, **W 20** | Az óra-mérés csak akkor ír felül, ha a telefonnak nincs sajátja; végpróba mindkét platformon |

---

## 10. C6–C9 — Sport-specifikumok · MF6

Ezek egymástól függetlenek, tetszőleges sorrendben és ütemben csúsztathatók.

| # | Iteráció | Lépések | Függés |
|---|---|---|---|
| **C6** | Futás | km-splitek + tempó-diagram · kadencia · **legjobb 1/5/10 km csúszóablakkal** · futás-PR-ok · hangos/haptikus km-visszajelzés | C4a · *(Q-D1 döntés kell)* |
| **C7** | Szobabicikli | teljesítmény/kadencia/ellenállás bekötése · összmunka (kJ) · **intervallum-szerkesztő és -lejátszó** · gép-kalória külön kezelése | C2 |
| **C8** | Túra | magasságprofil-részletek · max magasság · GAP · útpont-jelölés · hátizsák-súly · időjárás-pillanatkép | C4a |
| **C9** | Játék | pulzuszóna-panel · box score · formátum/helyszín · kültéri GPS-mód | C5 |

---

## 11. Kockázati ellenőrzőpontok

Négy hely, ahol a hiba **néma** (semmi nem hibázik, csak rossz az eredmény) — ezért mindegyikhez
külön teszt tartozik, nem csak kézi ellenőrzés:

| Hol | Mi a néma hiba | Ellenőrzőpont |
|---|---|---|
| C1.4 / C1.5 | A cardio-mező változása nem bumpolja a session `updatedAt`-jét → **soha nem szinkronizál** | Kötelező teszt mindkét oldalon ([52 §4](52-cardio-domain-backend-plan.md)) |
| C3.1–C3.2 | A statisztika definíciója csendben megváltozik | Regressziós teszt rögzített, tisztán erősítő adathalmazon: **minden szám bitre azonos** |
| C3w.1 | A web és a mobil aggregációja szétcsúszik | Paritás-teszt ([56 ST11](56-cardio-statistics-plan.md)) |
| C4a.5 | Két Android értesítés, vagy csendben megölt háttér-mérés | Hosszú (60+ perces) eszközös próba + akku-mérés naplózva ([54 §8](54-cardio-gps-route-plan.md)) |

---

## 12. Összefoglaló

| Iteráció | Lépések | Mérföldkő |
|---|---|---|
| C0 | 5 | MF1 |
| C1 | 9 | MF2 |
| C2 | 13 (11 Windowson, 2 Mac-en: C2.10b, C2.11b) | MF3 |
| C3 · C1w · C3w | 5 + 4 + 1 | MF4 |
| C4a · C5 | 6 + 7 | MF5 |
| C6–C9 | iterációnként 4–6 | MF6 |

**Összesen ~50 lépés az MF5-ig**, plusz a sport-specifikumok. A javasolt vágási pont, ha
részletekben szállítanál: **MF2** (kézi rögzítés) már önmagában hasznos funkció, **MF3** az,
amitől a funkció „igazi”.

**Kezdésre javasolt:** `C0.1` és `C0.2` egy beszélgetésben (mindkettő tiszta hozzáadás,
semmit nem tör el), utána `C0.3` külön — az az egyetlen lépés, ami meglévő viselkedést módosít.

**Haladás:** `C0.1` és `C0.2` kész (2026-08-10) — `SessionKind`/`ActivityType`/`ActivityFamily`
enumok backenden, `activity_type.dart` + ARB-kulcsok EN/HU mobilon, unit-teszt a
kód↔label↔ikon teljességre. Backend fordul, `flutter analyze` és a teszt zöld.

`C0.3` is kész (2026-08-10) — a teljes audit-lista végigolvasva, a meglévő kód **nem tartalmazott
hibát**: a `sets`/`exercises`-t olvasó helyek már ma `isEmpty`/`whereType` őrökkel tolerálják az
üres listát. Ezt egy új widget-teszt (`sessions_tab_empty_session_test.dart`, 4 forgatókönyv)
zárja le tartósan a suite-ban; a teljes `test/features/workouts` suite (229 teszt) zöld maradt.
Két tétel, ami valódi kódmódosítást igényel, a C0.4/C0.5-re halasztva — azok nem hibajavítás,
hanem előkészítés a C1+ számára.

`C0.4` is kész (2026-08-10) — `open_workout_screens.dart` kapott egy `openSessionScreen(navigator,
session, {watchMastered, watchCurrentExerciseIndex})` függvényt: az **egyetlen** hely, ahol egy
meglévő session megnyitásakor eldől, melyik képernyő nyíljon. Az öt hívási hely
(`sessions_tab.dart`, `dashboard_screen.dart`, `upcoming_workout_card.dart`,
`workout_resume_prompt.dart`, `push_tap_handler.dart`) mind ezen keresztül megy — mindegyiknél a
navigátor-feloldás (pl. `rootNavigator: true` vs. nélküle) és az await/fire-and-forget viselkedés
pontosan megmaradt, csak a „melyik képernyő” döntés lett kiemelve. A cardio-ág egyelőre `TODO`
kommentben (a `sessionKind` mező hiányában nincs mit elágaztatni — az C1.5-ben érkezik). A
sablon-indítás (`LogSessionScreen(template: ...)`) szándékosan **kívül maradt**: cardióra V1-ben
nincs sablon ([51 §5](51-cardio-overview-plan.md)). `flutter analyze` teljes projektre és a teljes
`flutter test` (645 teszt) tiszta — nulla regresszió.

`C0.5` is kész (2026-08-10) — két külön eredménnyel:

- **`recommended_template_provider.dart`: valódi fix.** A `.take(10)` mostantól a
  `.whereType<String>()` **után** fut, nem előtte — így egy sablon nélküli session (ma egy
  szabadon indított erősítő edzés, holnap minden cardio session, [51 §1.1](51-cardio-overview-plan.md):
  cardio V1-ben nem kap sablont) **nem foglal helyet** a legutóbbi-10 ablakban, csak egyszerűen
  kimarad belőle. Új tesztfájl (`recommended_template_provider_test.dart`, 7 teszt, első lefedettség
  ennek a fájlnak) — a legfontosabb köztük kézzel kiszámolt regresszió: 8 sablon nélküli session a
  lista elején a **régi** kódot null-t visszaadásra kényszerítette volna (a 10-es ablak 8 helyét
  elvitte a zaj, a valódi 6-elemű A/B ciklusból csak 2 fért be), az **új** kód helyesen felismeri a
  ciklust és `tA`-t javasol.
- **`personal_record.dart` / PR-motor: nincs ma javítandó kód.** A [53 §0.1](53-cardio-mobile-plan.md)
  audit már megállapította: a `getPrBaseline` az `exercise_sets` táblát joinolja, aminek egy cardio
  session sosem lesz sora — a kizárás szerkezeti, védőháló nélkül is helyes. Egy explicit
  `kind`-szűrő nem írható meg addig, amíg a mező nem létezik (C1.5) — ez a **C3.5** feladata marad,
  ahogy az 51/53-as doc is jelezte. A domain-réteg (`personal_record_test.dart`) már ma is teljes
  körűen teszteli az üres-lista eseteket minden függvényen (`PrBaseline.fromSets([])`,
  `computePrHistory([])`, `detectPrsInOrder(baseline, [])`), tehát nincs lefedettségi rés sem.

`flutter analyze` teljes projektre és a teljes `flutter test` (652 teszt, +7 az új
`recommended_template_provider_test.dart`-ból) tiszta — nulla regresszió. Ezzel a **teljes C0
iteráció kész.**

`C1.1` is kész (2026-08-10) — **ez az első lépés, ami valódi cardio-sémát visz be.**
`V66__cardio_session_kind.sql`: `session_kind varchar(16) not null default 'STRENGTH'`,
`activity_type varchar(32)` (nullable), `moving_seconds integer` (nullable),
`workout_sessions_kind_activity_ck` CHECK (a séma szintjén kényszeríti a D-C1 diszkriminátor
invariánsát: `CARDIO` ⇔ van `activity_type`), és egy parciális index
(`idx_workout_sessions_user_kind_started`, `where deleted_at is null`) a jövőbeli fajta-szűrt
listákhoz. A `WorkoutSession` entitás megkapta a három mezőt, a `sessionKind` Java-oldali
`STRENGTH` alapértékkel (a DB `default`-jával összhangban).

Új Testcontainers-alapú migrációs teszt (`CardioSessionKindMigrationTest`, a meglévő
`UpcomingSessionRegressionTest` mintáját követve): egy `session_kind` nélküli insert
`'STRENGTH'`-re és `activity_type IS NULL`-ra fut le; `CARDIO` + `activity_type` együtt elfogadott;
`CARDIO` + hiányzó `activity_type`, illetve `STRENGTH` + kitöltött `activity_type` mindkettő
`SQLException`-t dob a CHECK-nevére hivatkozva. **Ezt a tesztet nem tudtam ebben a sandboxban
lefuttatni** — a Docker daemon nem fut (a Rancher Desktop CLI jelen van, de a VM nincs indítva), és
a Testcontainers ehhez valódi Dockert igényel; a teszt viszont fordul (`mvn test-compile` zöld), és
a `UpcomingSessionRegressionTest`-tel azonos, már bevált mintát követi. A gyors, Docker nélküli
`WorkoutSessionControllerTest` (11 teszt, `@WebMvcTest`) lefutott és zöld — az entitás-bővítés nem
tört el semmit a kontroller-rétegen. `mvn compile` és `mvn test-compile` mindkettő tiszta.
**A CI-ben (ahol fut Docker) ellenőrizendő, hogy `CardioSessionKindMigrationTest` ténylegesen zöld.**
*(Frissítés: lásd a doc legvégén — utólag Docker elérhetővé vált, és ez a teszt is lefutott.)*

`C1.2` is kész (2026-08-10) — `V67__cardio_details.sql` + a `CardioDetails` entitás.

A tábla és az entitás bitre a [52 §2.2/§3.1](52-cardio-domain-backend-plan.md) szerint épült, **egy
tudatos eltéréssel**: a doksi eredeti SQL-vázlata `created_at`/`updated_at` oszlopot is javasolt a
táblán, de a meglévő gyerektáblák (`workout_session_exercises`, `program_workouts`) egyike sem visz
ilyet — csak a **top-level**, önmagában szinkronizálandó táblák (`training_programs`) kapnak
saját időbélyeget. Mivel a `cardio_details` sosem szinkronizálódik önállóan (csak a szülő
`workout_sessions.updated_at` számít, [52 §4](52-cardio-domain-backend-plan.md)), a saját
időbélyeg holt súly lett volna — kihagytam, a bevett gyerektábla-mintát követve.

A `WorkoutSession.java`-t **nem** bővítettem az inverz `@OneToOne(mappedBy = "workoutSession")`
mezővel — ez a C1.2 fájllistájában sem szerepelt, és a mapper/DTO-munkával (C1.4) egy időben lesz
értelme bekötni. A `CardioDetails` addig is önállóan perzisztálható és lekérdezhető az owning
oldali `@OneToOne`-on keresztül.

Új teszt: `CardioDetailsTest` (`com.lifey.workout.session.cardio`), Testcontainerrel valódi
Postgres ellen — teljes mezőkör írás/olvasás, minden family-specifikus oszlop nullable (egy üresen
induló cardio session ne bukjon el NOT NULL miatt), az 1:1 egyediség, mindkét CHECK constraint
(`intensity`, `venue`), és a hard-delete cascade (raw SQL DELETE-tel, mert az app csak
soft-delete-el — ez a jövőbeli hard-delete útvonalak védőhálója). Egy technikai csapdát menet
közben javítottam: a `BaseEntity` `GenerationType.IDENTITY`-je miatt Hibernate a beszúrást
azonnal `persist()`-kor végrehajtja (nem tudja batch-elni), tehát a constraint-sértés már a
`persist()` hívásán dobódik, nem a később hívott `flush()`-on — az `assertThatThrownBy`-t ennek
megfelelően a `persist()` köré tettem, `PersistenceException` + `hasStackTraceContaining` páros
(nem `DataIntegrityViolationException`/`hasMessageContaining`), mert egy nyers `EntityManager`
nem megy át a Spring Data repository-k kivétel-fordító AOP rétegén, és a Postgres hibaszöveg
Hibernate becsomagolása után nem biztos, hogy a legfelső kivétel `getMessage()`-ében van — a teljes
stack trace (a „Caused by” lánccal együtt) viszont mindig tartalmazza.

**Ugyanaz a korlát, mint C1.1-nél: ezt a tesztet sem tudtam lefuttatni** (nincs futó Docker
daemon ebben a sandboxban). Amit igazolni tudtam: `mvn compile` és `mvn test-compile` mindkettő
tiszta, a gyors `WorkoutSessionControllerTest` (11 teszt, nem igényel Dockert) továbbra is zöld.
**A CI-ben ellenőrizendő, hogy `CardioSessionKindMigrationTest` és `CardioDetailsTest` ténylegesen
zöld** — utóbbinál különös figyelemmel a fenti kivétel-típus feltételezésre.

`C1.3` is kész (2026-08-10) — `V68__cardio_splits.sql` + a `CardioSplit` entitás.

Bitre a [52 §2.3](52-cardio-domain-backend-plan.md) szerint: `(workout_session_id, split_index)`
egyedi constraint (a splitek 0-tól indexeltek, kliensen számolódnak záráskor, és a szerver sosem
származtatja őket — nincs is miből, a nyers GPS-pontok sosem érnek fel a szerverre,
[52 D-C1.2](52-cardio-domain-backend-plan.md)). A `cardio_details`-nél megkezdett mintát követve
**itt sincs** `created_at`/`updated_at` (tiszta gyerektábla, sosem szinkronizálódik önállóan) —
ez most már konzisztens a két táblán, tehát nem eltérés, hanem a C1.2-ben lefektetett szabály
követése. A `WorkoutSession.java` `splits` mezőjét itt sem kötöttem be — az is C1.4-re marad, a
`cardioDetails` mezővel egy időben.

Új teszt: `CardioSplitTest`, a `CardioDetailsTest` szerkezetét követve — teljes mezőkör
írás/olvasás, opcionális mezők (szintváltozás, pulzus) nullable-ellenőrzése, több split
egy session-ön belül (JPQL-lekérdezéssel visszaolvasva, sorrend-ellenőrzéssel), **azonos
split-index két különböző session-ön nem ütközik** (a composite unique valóban session-re
szűkített, nem globális), azonos split-index ugyanazon session-ön belül **igen** ütközik
(`PersistenceException` + a constraint neve a stack trace-ben, ugyanaz a mintázat, mint
`CardioDetailsTest`-ben), és a hard-delete cascade.

**Ugyanaz a korlát, mint C1.1/C1.2-nél: ezt a tesztet sem tudtam lefuttatni** (nincs futó Docker
daemon ebben a sandboxban). `mvn compile` és `mvn test-compile` mindkettő tiszta, a gyors
`WorkoutSessionControllerTest` (11 teszt) továbbra is zöld. **A CI-ben ellenőrizendő, hogy
`CardioSplitTest` ténylegesen zöld** — ugyanazzal a fenntartással, mint `CardioDetailsTest`-nél.

Ezzel a **backend séma-munka (C1.1–C1.3) kész** — `workout_sessions` diszkriminátora,
`cardio_details`, `cardio_splits` mind megvan.

`C1.4` is kész (2026-08-10) — **ez volt a legnagyobb C1-es lépés**, ez teszi a cardio adatot
először elérhetővé a REST API-n. Amit tartalmaz:

- **`WorkoutSession.java`** végre bekapcsolva a `cardioDetails` (`@OneToOne`) és `splits`
  (`@OneToMany`, `splitIndex` szerint rendezve) mezőkkel — ez volt a C1.2/C1.3-ban tudatosan
  elhalasztott rész.
- **4 új DTO**: `CardioDetailsRequest`/`Response`, `CardioSplitRequest`/`Response` — bitre a
  [52 §2.2/§2.3](52-cardio-domain-backend-plan.md) szerinti mezőkör, `@PositiveOrZero`/`@Min`/`@Max`
  Bean Validationnel a fizikai mennyiségeken.
- **`WorkoutSessionRequest`/`Response`** additív bővítés (`sessionKind`, `activityType`,
  `movingSeconds`, `cardio`, `splits`) — a meglévő mezők **sorrendje és jelentése változatlan**.
- **Keresztmezős validáció**: `InvalidCardioRequestException` (400) — `CARDIO` ⇔ van
  `activityType`; `STRENGTH` esetén `activityType`/`cardio` null és `splits` üres. Ugyanazt az
  invariánst kényszeríti, mint a V66 CHECK constraint, csak a service-ben, hogy tiszta 400-at
  adjon egy nyers 409 helyett.
- **`?kind=` szűrő**: két új repository-metódus (`...AndSessionKindOrderByStartedAtDesc`,
  `...AndSessionKind`) — **additív**, a meglévő szűretlen metódusok és az őket használó tesztek
  érintetlenek. A delta-sync végpont (`findDelta`) **szándékosan nem** kapott szűrőt
  ([52 §3.2 D-C1.3](52-cardio-domain-backend-plan.md)). A `findPageForUser` (edzői nézet) sem —
  az a web-oldali C1w-re marad.
- **`updatedAt`-bump**: a `WorkoutSessionServiceImpl.update()` már **eleve feltétel nélkül**
  bumpolt minden hívásnál (`session.setUpdatedAt(Instant.now())`, függetlenül attól, mi
  változott) — ez a legkockázatosabb pont a [52 §4](52-cardio-domain-backend-plan.md) szerint, de
  a meglévő kód szerkezete miatt **nem kellett új feltételes logika**: elég volt a
  `replaceCardioDetails`/`replaceSplits` hívást ugyanabba a feltétel nélküli útba tenni, mint a
  `replaceSets`/`replacePlannedExercises`-t.
- **Postman-kollekció** frissítve: „Log a cardio session (example)” és „List cardio workout
  sessions (kind filter, example)” új kérés, a „List workout sessions” leírása kiegészítve.

**Fontos, tervtől eltérő döntés a `cardio` blokk update-szemantikájára**: a request **teljes
csere**, nem részleges patch — egy `cardio: null` update **törli** a meglévő cardio-adatokat,
ugyanúgy, ahogy egy üres `sets: []` törli a szetteket. Ezt a doksik nem mondták ki explicit
módon, de a meglévő `replaceSets`/`replacePlannedExercises` minta (mindig `.clear()` + újraépítés)
ezt sugallja, és a mobil kliens úgyis mindig a teljes aktuális állapotot küldi — ez dokumentálva
van a service kódjában és egy dedikált teszttel (`update_nullCardioBlockClearsAnExistingCardioDetailsRow`).

**Tesztek** (a legkritikusabb pont, a bump-szabály, Mockitóval **ténylegesen lefuttatva**, nem
csak megírva):
- `WorkoutSessionServiceImplTest` — 10 új teszt: cardio create teljes round-trip, `sessionKind`
  hiánya → `STRENGTH` a válaszban, mind a négy keresztmezős validációs hiba, **`update_cardioOnlyEditBumpsParentUpdatedAt`**
  (a `update_childOnlyEditBumpsParentUpdatedAt` pontos cardio-párja), a meglévő `CardioDetails`
  sor újrahasznosítása update-kor (nem duplikátum), a null-cardio törlés, a splits teljes csere.
  **Mind a 31 teszt (21 régi + 10 új) lefutott és zöld** — ez pure-Mockito teszt, nem igényel
  Dockert.
- `WorkoutSessionKindFilterRepositoryTest` (új, Testcontainers) — a `?kind=` szűrt derived-query
  metódusok valódi Postgres ellen, mert egy Mockitós teszt nem kapná el, ha a metódusnév elgépelve
  rossz SQL-t generálna.

**Ugyanaz a korlát, mint C1.1–C1.3-nál: a Testcontainers-teszteket (`WorkoutSessionKindFilterRepositoryTest`,
és a C1.1–C1.3-ban írt három) nem tudtam lefuttatni** (nincs Docker daemon). Amit igazolni tudtam:
`mvn clean compile` és `mvn clean test-compile` mindkettő tiszta; a három Docker-mentes
tesztosztály (`WorkoutSessionControllerTest` 11, `TrainerClientDataControllerTest` 25,
`WorkoutSessionServiceImplTest` 31 — összesen 67 teszt) mind lefutott és zöld, beleértve a
`TrainerClientDataControllerTest`-et is, amit nem szándékoztam módosítani, de a
`WorkoutSessionResponse` mezőbővítése miatt frissíteni kellett a benne lévő 3 pozíciós
konstruktor-hívást. **A CI-ben ellenőrizendő mind a négy Testcontainers-teszt** (a három korábbi +
`WorkoutSessionKindFilterRepositoryTest`).

**Javítás (2026-08-10):** tévesen `C2.1`-et jelöltem következőnek — a C1 iteráció **nem ért
véget** a backenddel. C1.5–C1.9 (mobil adatréteg + kézi rögzítés) is a C1-hez tartozik, csak más
fájlokban; ezek nélkül a backend cardio API-nak nincs semmilyen mobil fogyasztója. A helyes
folytatás:

`C1.5` kész — lásd lentebb a részletes leírást. **Következő: `C1.6`** — `ActivityChip` widget
(20/32/56 px) + session-kártya ikon-chippel és családfüggő fő metrikával.

A `C2.1` (`CardioSessionScreen` váz) csak **C1.5–C1.9 után** jön — a C2 (élő cardio) a C1.5-ös
Drift-adatrétegre épül, ami mostantól megvan.

---

## Testcontainers-utólagos ellenőrzés (2026-08-10, Docker elérhetővé vált)

A C1.1–C1.4 alatt négy Testcontainers-teszt csak **fordítva** volt ellenőrizve (Docker hiányzott
ebben a sandboxban). A felhasználó saját IDE-jében lefuttatta a teljes suite-ot, és **46 teszt
elbukott** — nem 46 külön hibáról volt szó, hanem **egyetlen közös okról**: a `CardioSplitTest`
context-indítási hibája miatt Spring minden más, azonos konfigurációjú `@SpringBootTest`-nél is
elbukott (`ApplicationContext failure threshold exceeded`), teljesen cardión kívüli teszteket is
magával rántva (`FoodSearchAccentRegressionTest`, `InternalApiIntegrationTest`,
`TrainerIdsWithActiveClientsRegressionTest` stb.) — Hibernate a **teljes** sémát validálja
context-indításkor, nem csak az adott teszthez tartozó táblákat.

**Két valódi hiba derült ki, mindkettő javítva:**

1. **Séma-eltérés** — `V67__cardio_details.sql`-ben `intensity smallint`, de a
   `CardioDetails.intensity` Java `Integer` mező, amit a Hibernate alapból SQL `integer`-re képez
   le. A `Schema validation: wrong column type` hiba blokkolta a teljes context-et. Javítás:
   `smallint` → `integer`, a meglévő `rpe` (1-10 értékelés) mintáját követve — a migráció még
   sosem futott le sikeresen sehol, tehát a közvetlen szerkesztés (nem új migráció) biztonságos
   volt.
2. **Tranzakció-hiba a saját tesztjeimben** — `CardioDetailsTest`/`CardioSplitTest` nyers
   `EntityManager.persist()`-et hívott tranzakció nélkül (`TransactionRequired` hiba). Class-szintű
   `@Transactional`-t **szándékosan nem** használtam — az minden tesztet visszagörgetne a végén,
   ami a hard-delete-cascade tesztek íróit láthatatlanná tenné a külön, nem-tranzakciós nyers JDBC
   kapcsolat előtt (hamis zöld eredmény, nem valódi teszt). Helyette `TransactionTemplate`-tel
   minden írás saját, azonnal commitoló tranzakcióban fut — ezt mindkét tesztfájlban bevezettem.

**Eredmény, mindhárom lépésben ellenőrizve:**
- A négy cardio Testcontainers-teszt önmagában: **20/20 zöld**.
- `com.lifey.workout.session.**` + `com.lifey.trainer.**` együtt: **277/277 zöld** (beleértve a
  korábban áldozatként elbukott, cardión kívüli teszteket is).
- **A teljes backend suite: 696/696 zöld, `BUILD SUCCESS`.**

Ezzel a C1.1–C1.4 minden korábbi „nem tudtam lefuttatni” fenntartása feloldva — a teljes cardio
backend-munka (séma + entitások + API) most már **valósan, végponttól végpontig igazolt**, nem
csak fordítás-szinten ellenőrzött.

---

## C1.5 kész (2026-08-10) — mobil adatréteg

A backend C1.1–C1.4 mobil oldali párja: a Drift-táblák, a domain-modell és a repository most már
teljes egészében ismeri a cardio mezőket, `STRENGTH`-nél pedig bájtra azonos marad a viselkedés.

**Drift-séma** (`core/local_db/tables/workout_session_tables.dart`, `core/local_db/app_database.dart`):
- `WorkoutSessions`-höz hozzáadva: `sessionKind`, `activityType`, `movingSeconds`.
- Két új tábla: `CardioDetails` (`@DataClassName('CardioDetailsRow')`, PK = `sessionClientId`, ~27
  nullable mező a backend `cardio_details`-t tükrözve) és `CardioSplits`
  (`@DataClassName('CardioSplitRow')`, PK = `clientId`).
- `schemaVersion` 33 → 34, `_addColumnIfMissing()` mintát követő migrációs blokk (idempotens,
  megszakított migrációt is túlél); `dart run build_runner build` lefuttatva, a generált
  `app_database.g.dart` ellenőrizve.

**Domain** (`domain/workout_session.dart`):
- Új `CardioMetrics` (elnevezve, nem `CardioDetails`, hogy ne ütközzön a Drift tábla-osztály
  nevével egy fájlon belül) és `CardioSplit` value class.
- `WorkoutSession` bővítve `sessionKind` (default `'STRENGTH'`), `activityType`, `movingSeconds`,
  `cardio`, `splits` mezőkkel, plusz `isCardio`, `family`, `effectiveDuration` derived gettereket.

**Repository** (`data/workout_session_repository.dart`) — a legnagyobb változás:
- `create()`/`update()` mindkettő tudja a cardio mezőket; az `update()` a kodbázis meglévő
  „hiányzó = megőriz, jelenlévő-nullal = töröl” (`Value<T>`) mintáját követi, mert a `rate()` és az
  `enrichHealthMetrics()` is hívja anélkül, hogy minden mezőt ismerné.
- `_payload()`: `STRENGTH`-nél a cardio mezők **ki vannak hagyva** a payloadból (nem csak nullák) —
  ez tartja a bájtra-azonos szinkron-alakot; `sets`/`exercises`/`cardio`/`splits` mindig teljes
  csere (a kliens mindig a jelenlegi teljes állapotot küldi).
- Új `watchByKind(String? kind)` — `null` esetén `watchAll()`-ra esik vissza.
- `delete()` és `entity_sync_config.dart`'s `_cleanupWorkoutSessionChildren()` gondoskodik a
  `cardio_details`/`cardio_splits` sorok törléséről is.

**Pull engine** (`core/sync/pull_engine.dart`):
- `_upsertWorkoutSession()` beolvassa a `sessionKind`/`activityType`/`movingSeconds` mezőket
  (hiányzó `sessionKind` esetén lokálisan `'STRENGTH'`-re esik vissza — legacy/cache-elt válasz
  esetére); cardio_details/cardio_splits törlés + újrabeszúrás minden pullnál (nem duplikál).

**`CardioFormatter`** (új: `core/format/cardio_formatter.dart`):
- Tiszta függvények `(érték, UnitSystem)` → formázott string — nincs `BuildContext`/Riverpod
  függőség, hogy a Live Activity payload-építő (natív oldal, izolált szálon) is használhassa
  ugyanazt a logikát, ne csak a widget-fa.
- `distance` (km/mi, 2 tizedes), `elevation` (m/ft, egész), `pace` (perc:mp /km vagy /mi, `null` ha
  a táv 0 vagy negatív — osztás-nullával elkerülve), `speed` (km/h vagy mph, 1 tizedes, `null` ha az
  időtartam 0), `duration` (`m:ss` egy óra alatt, `h:mm:ss` egy óra fölött, a meglévő stopper-konvenciót
  követve: csak a legbaloldalibb egység nem nullázott elől).
- Szándékos eltérés a meglévő `core/utils/unit_converters.dart` mintától (ami nyers
  szám-konverziókat ad, a hívóra bízva a metric/imperial elágazást): itt az elágazás egy helyen,
  magában a formázóban van, mert a jövőbeli hívási pontok száma nagy lesz (élő cardio képernyő,
  statisztika, óra-híd) és mindegyiknél ismételni kellene.

**Tesztek:**
- `test/features/workouts/data/workout_session_repository_cardio_test.dart` — 13 teszt: `STRENGTH`
  payload bájtra azonos, cardio oda-vissza, csere-nem-hozzáfűzés, `rate()`/`enrichHealthMetrics()`
  megőrzés, explicit-null törlés szemantika, `watchByKind`, törlési cleanup.
- `test/core/sync/pull_engine_cardio_test.dart` — 4 teszt: `STRENGTH` válasz, hiányzó
  `sessionKind` kulcs (legacy), teljes `CARDIO` válasz feltöltés, újra-pull csere-nem-duplikálás.
- `test/core/format/cardio_formatter_test.dart` — 14 teszt: minden formázó függvény metric és
  imperial ágon, plusz a nulla/negatív perem-esetek.

**Eredmény:** teljes `flutter test` futtatás — **682/682 zöld** (668 korábbi + 14 új
`CardioFormatter`-teszt; a repository/pull-engine cardio-tesztek már a 668-ban benne voltak).

A `C1` mobil adatrétege (Drift + domain + repository + pull + formázó) ezzel készen áll — a C1.6
onnantól UI-réteg (`ActivityChip` + session-kártya), ami már csak olvassa ezt az adatot.

---

## C1.6 kész (2026-08-11) — `ActivityChip` + session-kártya

Az első mobil **UI**-lépés a cardio munkában — eddig csak adatréteg épült (C0, C1.1–C1.5).

**`shared/widgets/activity_chip.dart`** (új): egy komponens, tetszőleges `size`-zal (a design
20/32/56 px-en mutatja be, de a session-kártya a saját 44 px-es jelvényméretét használja —
lásd lent). Kerek háttér az akcentszín 14%-os fedésével sötét, 16%-os fedésével világos témában
(`Theme.of(context).brightness` szerint elágazva) — bitre a
`design/Lifey Cardio Design.dc.html` §1 "ActivityChip" leírása szerint. Az ikonméret a chip
54%-a, kerekítve. Az `activityType`/`activityTypeColor`/`activityTypeIcon` (C0.2) hívásokra épül,
tehát a `'STRENGTH'` szentinel is működik vele.

**`presentation/session_row_plan.dart`** bővítve `cardioCardPrimaryMetric(session, unitSystem)`
tiszta függvénnyel — ez adja a session-kártya **családfüggő fő metrikáját**:
- DISTANCE (futás/séta/túra): a táv, a `design` §2 "cél alakú" száma — ha nincs rögzítve
  (pl. kézi séta-napló táv nélkül), a `movingSeconds`/wall-clock időtartamra esik vissza,
  ugyanaz a logika, mint az aktív képernyő "nincs távforrás" ága (C2.2).
- MACHINE (szobabicikli) és GAME (kosár/foci/egyéb): mindig az időtartam
  (`effectiveDuration`), sosem a táv — "a szobabicikli negyven perc, nem tizennyolc kilométer".
- `null`, ha a session sem távval, sem idővel nem rendelkezik még (STRENGTH, vagy egy épp
  induló cardio session).

**`presentation/sessions_tab.dart`** — `_SessionCard` additív bővítése, **tudatosan minimális
kockázatú döntéssel**: az erősítő ág (jelvény, szín izomcsoport szerint, "N szett" sor) **egy
sort sem változott** — a kész-ha ("az erősítő kártya vizuálisan változatlan") szó szerint
teljesül, nem csak megközelítőleg. Az új cardio ág:
- Jelvény: `ActivityChip(activityType: session.activityType!, size: 44)` — kör alakú, az
  erősítő jelvény (44 px, lekerekített négyzet, `Icons.fitness_center`) helyén, de attól
  vizuálisan megkülönböztethetően (kör vs. négyzet), pontosan ahogy az M19 makett mutatja.
- Cím: mivel egy cardio sessionnek nincs `templateName`-je, a cím az `activityTypeLabel` lesz
  (pl. "Futás") — a `title != null` feltétel innentől mindkét ágat lefedi, a dátumsor stílusa
  (label vs. body) ugyanúgy követi, mint eddig a `templateName`-nél.
- Fő metrika sor: `cardioCardPrimaryMetric` eredménye a "N szett" helyén — futó session esetén
  továbbra is az `_StatusPill` ("Folyamatban") nyer, változatlanul.
- A `unitSystem`-et a `SessionsTab` (`ConsumerStatefulWidget`, van `ref`-je) olvassa ki a
  `settingsControllerProvider`-ből (`.value ?? UserSettings.defaults()` minta, ugyanaz, mint az
  `onboarding_edit_screen.dart`-ban) és adja tovább propként a `_SessionCard`-nak (ami
  `StatelessWidget`, nem érhetné el a Riverpod-ot közvetlenül `ref` nélkül).

**Váratlan lelet, C1.6-hoz nem tartozó, de blokkoló hiba**: a `flutter test` futtatás elsőre
**fordítási hibával bukott el az egész suite-on** — a generált kód (`lib/l10n/app_localizations*.dart`
és `lib/core/local_db/app_database.g.dart`) **2026-08-06-i, a C0.2/C1.1–C1.5 ARB-kulcsai és
Drift-oszlopai előtti** állapotban volt befagyva ebben a sandboxban (`flutter gen-l10n` és
`dart run build_runner build` a korábbi lépések során lefutott, de a kimenet nem volt jelen a
munkakönyvtárban ennek a beszélgetésnek az elején). Ez **nem C1.6 regresszió** — bármelyik
korábbi lépés első tesztfuttatásakor előjött volna, csak eddig egyik sem indított `flutter test`-et
a teljes projektre ebben a sandboxban. Javítás: `flutter gen-l10n` + `dart run build_runner build`
újrafuttatva, mindkettő tiszta; utána a teljes suite lefordult.

**Tesztek:**
- `test/shared/widgets/activity_chip_test.dart` (új, 6 teszt) — méret/kör alak, ikon-arány két
  méretnél, a `STRENGTH` szentinel, és a sötét/világos alfa **külön** tesztként (egy korábbi,
  egyetlen tesztbe zsúfolt verzió hamis zöldet adott volna: két egymást követő `pumpWidget`
  hívás `const` azonos-argumentumú widgettel Dart-konstans-kanonizáció miatt **ugyanaz az
  objektum**, a Flutter-elemfa ezért nem építi újra — a widget maga helyes volt, a teszt-módszer
  nem).
- `session_row_plan_test.dart` bővítve 7 új `cardioCardPrimaryMetric`-teszttel: mindhárom család,
  a táv-nélküli DISTANCE-fallback, imperial mértékegység, `STRENGTH` → `null`, és a "még semmi
  sincs rögzítve" eset.
- `sessions_tab_cardio_test.dart` (új): mind a hét `ActivityType` külön session-ként pumpolva
  (egy 7-elemű lista egyetlen tesztben túlcsordítaná az alapértelmezett teszt-viewportot, és a
  `ListView.builder` képernyőn kívüli elemei ezért nem lennének a widgetfában) — mindegyik
  megjeleníti a saját `ActivityChip`-jét és a lokalizált cím-szövegét; plusz külön teszt a
  DISTANCE/MACHINE fő metrika helyességére és a futó cardio session pillájára.
- `sessions_tab_empty_session_test.dart` kapott egy `settingsControllerProvider`-override-ot
  (`_FakeSettingsController`, a projektben már bevett minta, pl.
  `statistics_screen_test.dart`) — enélkül az új `unitSystem`-függőség egy valódi, DB-t igénylő
  Riverpod-providert próbált volna felépíteni a widget-tesztben.

**Eredmény:** `flutter analyze` (teljes projekt) tiszta; a teljes `flutter test` **701 lefutott
tesztből 697 zöld** — a 4 bukás mind a `chat_repository_test.dart` "image attachments"
csoportjában van, Windows-specifikus fájlzár-versenyhelyzet (`PathAccessException` a teszt saját
temp-könyvtárának törlésekor), teljesen független a cardio-munkától (nem érintettem sem a chat
feature-t, sem a hozzá tartozó fájlokat) — környezeti flake, nem C1.6-regresszió.

**Következő:** `C1.7` — fajta-szűrő (mind / erősítő / cardio) + másodlagos típus-szűrő a
`workouts_screen.dart`-on, M20 szerint.

---

## C1.7 kész (2026-08-11) — fajta-szűrő + másodlagos típus-szűrő

**Tudatos eltérés az M20 makett szerkezetétől.** Az M20 canvas egy teljes képernyős lapot mutat
két szinttel: **CSALÁD** sor (Mind / Táv / Gép / Játék — `ActivityFamily` szerint) és alatta
**TÍPUS** chip-rács darabszámmal. Ennek a lépésnek a saját táblázat-sora (§4 fent) viszont
explicit **más** hierarchiát ír elő: *"mind / erősítő / cardio + másodlagos típus-szűrő"* —
vagyis `SessionKind` szerinti elsődleges szűrés (nem `ActivityFamily` szerinti),
egy cardio-n belüli másodlagos `ActivityType`-szűrővel. A plan szövegét követtem, mert az az
ehhez a lépéshez tartozó explicit "kész-ha" forrása; a teljes M20-lap (család-sor, darabszám-
jelvények, "N edzés megjelenítése" gomb) egy jóval nagyobb, önálló bottom-sheet komponens lenne —
ha a termék mégis a család-alapú szűrést és a teljes lapot akarja, az egy külön, saját
kész-ha-val ellátott lépés kellene legyen, nem C1.7 burkolt kibővítése.

**`presentation/sessions_tab.dart`**:
- Új, tesztelhető, tiszta predikátum: `matchesSessionKindFilter(session, {kindFilter,
  activityTypeFilter})` — `kindFilter` `null`/`'STRENGTH'`/`'CARDIO'`, `activityTypeFilter`
  csak `'CARDIO'` alatt számít (egyébként figyelmen kívül marad — egy esetleges elavult
  másodlagos érték sosem szűrhet lopva).
- `SessionsTab` két új, opcionális propot kapott (`kindFilter`, `activityTypeFilter`),
  alkalmazva mind a `filtered` (dátum szerint már szűrt lista), mind az `upcoming`
  (edző által ütemezett, még el nem indult) szakaszra — így egy "csak erősítő" szűrő egy
  jövőbeli cardio-ütemezést is elrejt, nem csak a lezárt session-öket.

**`presentation/workouts_screen.dart`**:
- Egyetlen `String _sessionKindFilterValue` state (üres string = "Mind" szentinel, ugyanaz a
  minta, mint a meglévő `_exerciseCategoryFilter`-nél) — **nem két külön mező** a
  kind/activityType párra, hogy egy friss választás sosem hagyhat hátra elavult másodlagos
  szűrést (a teljes érték cserélődik, nem részlegesen).
- `_sessionKindFilter` getter dekódolja ezt `(kind, activityType)` párrá; `_sessionKindFilterLabel`
  adja a gomb feliratát.
- A trailing terület (AdaptiveAppBar `trailing`) mostantól egy `Row` két gombbal: az új
  `LabeledFilterButton` (Mind / Erősítő / — elválasztó — / Kardió (mind) / hét konkrét típus,
  egy lapos lista, `PopupMenuButton`-alapon, ugyanaz a minta, mint a gyakorlat-kategória
  szűrőnél) + a meglévő `DateRangeFilterButton`. Csak a Sessions fülön (index 0) jelenik meg.
- Új ARB-kulcs: `sessionKindCardioLabel` ("Cardio" EN / "Kardió" HU) — az egyetlen felirat,
  ami eddig nem létezett; a többi (`allFilterLabel`, `activityTypeStrength`, az egyes
  `activityType*` nevek) már megvolt C0.2-ből.

**A kész-ha ("a szűrő állapota megmarad tab-váltáskor") szerkezetileg garantált**: a
`_sessionKindFilterValue` a `_WorkoutsScreenState`-ben él, ugyanabban az objektumban, mint a már
működő `_sessionFilter`/`_exerciseCategoryFilter` — a `TabController` fül-váltása nem hozza létre
újra ezt a State-et, tehát nincs külön tennivaló ennek biztosítására (ugyanaz az architekturális
garancia, amit a meglévő két szűrő is élvez).

**Tesztek** (`sessions_tab_kind_filter_test.dart`, új):
- `matchesSessionKindFilter`: mind a négy kombináció (null/STRENGTH/CARDIO, CARDIO+típus) +
  egy védekező eset (elavult `activityTypeFilter` egy nem-CARDIO `kindFilter` alatt).
- `SessionsTab` a propokkal bekötve: STRENGTH szűrő elrejti a cardio session-t; CARDIO+RUNNING
  csak a futást mutatja, a sétát nem; szűrő nélkül minden látszik.
- A `WorkoutsScreen`-t magát **nem** kapta widget-teszt — a C0.3 auditban a `DashboardScreen`-nél
  már meghozott döntést követve (aránytalanul nehéz felhúzás sok providerrel egy megerősítő
  tesztért), a szűrő-perzisztencia pedig architekturálisan, nem futásidőben garantált.

**Eredmény:** `flutter analyze` (teljes projekt) és `flutter test test/features/workouts`
(**274/274 zöld**) tiszta.

---

## C1.8 kész (2026-08-11) — `LogCardioSheet`, DISTANCE + MACHINE

**Tudatos döntés a típusválasztó terjedelméről.** A mobil-terv (§2) szerint a lapon **mind a
hét** `kActivityTypes` érték választható — a mezőkészletet a **család** dönti el, nem a típus
("A típusválasztó a lap tetején marad, mert a választás alatta mindent átrendez"). Ez azt
jelenti, hogy egy GAME típus (kosár/foci/egyéb) is kiválasztható **már ebben a lépésben**, jóval
azelőtt, hogy a GAME-specifikus mezők (intenzitás, helyszín, box score — C1.9) elkészülnének. Ez
nem hiányosság: a megosztott mezők (dátum/idő + időtartam) minden családnál működnek, tehát egy
"kosaraztam 52 percet" bejegyzés már most menthető, csak intenzitás/pontszám nélkül — a GAME-ág
C1.9-ben bővül ki, nem C1.8-ban épül újra.

**Tudatos egyszerűsítés a mobil-terv §2 mezőlistájához képest.** A doksi 5. pontja
("Kalória (opcionális), pulzus-átlag (opcionális)") **nem** került be — a `WorkoutSession.
activeCalories`/`averageHeartRate` mezők kódkommentje (`domain/workout_session.dart`) explicit
kimondja, hogy ez a két mező **kizárólag** órás gazdagításból származik 2026-07-16 óta (a régi
manuális "Import from Health" utat akkor törölték); egy manuális beviteli mezőt visszahozni ide
szembemenne ezzel a már meghozott döntéssel. A MACHINE család saját, ettől független
`deviceCalories` mezője ("a gép kijelzett kalóriaértéke, sosem összegződik az napi aktív
kalóriába") viszont bekerült, mert azt a doksi külön, "gép-kalória" néven listázza, és a
`CardioMetrics`-nek van rá saját mezője.

**Nincs belépési pont bekötve ebben a lépésben** — a terv fájllistája ehhez a lépéshez kizárólag
`presentation/log_cardio_sheet.dart`-ot nevezi meg. A lap önmagában teljes és tesztelt
(`showModalBottomSheet`-tel bárhonnan nyitható, a meglévő `LogRecipeSheet`/`AddExerciseSheet`
mintát követve), de a Workouts FAB-ba vagy a `TemplatePickerScreen`-be kötése szándékosan
kimaradt — az a C1.9 (amikor a lap a GAME ággal együtt tényleg feature-complete lesz) vagy a
C2.7 gyorsindító-lap munkájának a feladata, nem ennek a lépésnek.

**`application/workout_session_controller.dart`**: új `logCardioSession({startedAt,
activityType, movingSeconds, cardio})` — vékony átadó a már C1.5-ben kész `_repo.create()`
felé, `sessionKind: 'CARDIO'`-val; a `finishedAt`-et `startedAt + movingSeconds`-ból származtatja,
mert egy utólagos bejegyzésnek nincs külön szünet/bruttó ideje (az csak a GAME családnál és az
élő C2-es képernyőn értelmezett fogalom).

**`presentation/log_cardio_sheet.dart`** (új):
- Típusválasztó: vízszintesen görgethető `ChoiceChip`-sor mind a hét `kActivityTypes` értékkel,
  ikon+címke, az aktivitás színével kiemelve (`activityTypeColor`/`activityTypeIcon`,
  C0.2-ből).
- Dátum/idő: a meglévő `LogRecipeSheet` `showDatePicker`+`showTimePicker` mintája,
  `lastDate: DateTime.now()`-val — ez zárja ki szerkezetileg a jövőbeli dátumot, és **engedi**
  a múltbelit (kész-ha).
- Időtartam: három kompakt szám-mező (ó/p/mp), az M17 makett hh:mm:ss formátumát követve — a
  mobil-terv doksi eredetileg csak perceket említett, de a makett pontosabb, és ez a makett a
  frame-forrás ehhez a lépéshez.
- DISTANCE ág: táv (mértékegység-függő, `Settings` metric/imperial kapcsolóját tiszteletben
  tartva, `km`↔`mi` váltással a mentéskor) + opcionális szintemelkedés.
- MACHINE ág: táv (ugyanaz a mező, újrahasznosítva) + átlag-teljesítmény (W) + kadencia (rpm) +
  ellenállás-szint + gép-kalória.
- **Kész-ha, "minden numerikus mező MANUAL forrásjelzést kap"**: a `CardioMetrics`-nek
  ténylegesen csak **két** forrás-mezője van (`distanceSource`, `caloriesSource` — ez az egyetlen
  provenienciát a domain-modell ismer, [51 R8](51-cardio-overview-plan.md)); a lap mindkettőt
  `'MANUAL'`-ra állítja, valahányszor a megfelelő érték ki van töltve, egyébként `null` marad.
- `cardio: null` megy a szerverre, ha **egyetlen** family-specifikus mező sincs kitöltve (csak
  dátum+időtartam) — ez tartja a C1.5-ben lefektetett invariánst ("cardio non-null csak ha van
  legalább egy rögzített metrika"), nem küld üres-de-nem-null objektumot.

**Tesztek** (`log_cardio_sheet_test.dart`, új, 8 teszt): a kontroller `logCardioSession()`
metódusán fake-elve (nem a Drift-repository szintjén — az már C1.5-ben lefedett, ez a lap saját
számítását ellenőrzi) — alapértelmezett DISTANCE-mezők, Save letiltva nulla időtartamnál, MACHINE
típusra váltás cseréli a mezőket, GAME típusra váltás csak a közös mezőket hagyja, a beküldött
`movingSeconds`/`distanceMeters`/`MANUAL`-jelzés helyessége, a csak-időtartam eset `cardio: null`-t
küld, a múltbeli dátum (a `_startedAt` alapértelmezett "most" értéke) változatlanul átmegy a
submitba, és az imperial mértékegység helyes mérföld→méter átváltása.

**Eredmény:** `flutter analyze` (teljes projekt) és `flutter test test/features/workouts`
(**282/282 zöld**, +8 az új `log_cardio_sheet_test.dart`-ból) tiszta.

---

## C1.9 kész (2026-08-11) — GAME ág, RPE/jegyzet, `CardioSummaryScreen`

**`presentation/widgets/rpe_selector.dart`** (új): a `PostWorkoutFeedbackSheet` privát
`_RpeChip`+sor-logikája kiemelve egy publikus, paraméterezhető `RpeSelector` widgetbe
(`min`/`max`, opcionális alsó/felső horgony-felirat) — ez a szó szerinti "RPE/jegyzet
újrahasznosítás". A `PostWorkoutFeedbackSheet` ezt használja változatlan viselkedéssel (1-10,
"Very easy"/"Maximal effort" horgonyokkal); a `LogCardioSheet` **kétszer** hívja: 1-10-zel a
univerzális RPE-hez, 5-ös maxszal a GAME család intenzitásához (`CardioMetrics.intensity`) — két
különböző mező, egy komponens.

**`application/workout_session_controller.dart`**: `logCardioSession` kapott `rpe`/
`feedbackNote` paramétereket, átadva a C1.5-ben már kész `_repo.create()`-nek.

**`presentation/log_cardio_sheet.dart`** bővítve:
- GAME ág (csak `_family == ActivityFamily.game` esetén jelenik meg): `SegmentedButton<String>`
  helyszín-váltó (Terem/Szabadtér), `RpeSelector(max: 5)` intenzitás, +/− pontszámláló
  (`scorePoints`) — bitre az M18 makett szerint. Az `assists`/`rebounds` mezőket a
  `CardioMetrics` ismeri, de az M18 makett és a "opcionális box score" szöveg csak egyetlen
  "Pont" számlálót mutat — a további két mező kimaradt, hogy ne legyen a makettnél gazdagabb a
  lap egy olyan funkciónál, amit a doksi maga is "opcionálisnak" jelöl.
- Univerzális RPE (1-10) + jegyzet szekció minden család alatt, a Mentés gomb fölött — az M17
  makett is mutatja ezt DISTANCE-nál, tehát nem GAME-specifikus, hanem tényleg közös.
- A `hasAnyMetric` ellenőrzés (ami eldönti, hogy `cardio` `null` legyen-e) kibővült az
  `intensity`/`venue`/`scorePoints` mezőkkel is.

**`presentation/cardio_summary_screen.dart`** (új) — **tudatosan nem** az M15 makett
(élő-edzés, szerkeszthető, teljesítmény-görbés) verziója; az a C2.8 feladata. Ez egy egyszerű,
**csak olvasható** nézet, ami a ma létező egyetlen cardio-forrást (a `LogCardioSheet`-tel
kézzel rögzített, mindig befejezett session-t) mutatja:
- Fejléc: `ActivityChip` + típusnév + dátum.
- Fő metrika kártya, családfüggő: DISTANCE-nál táv (vagy időtartam, ha nincs táv rögzítve —
  ugyanaz a "nincs távforrás" fallback, mint a C1.6-os kártyán), MACHINE-nél mindig mozgásidő,
  GAME-nél mindig játékidő.
- Másodlagos metrika-csempék, családfüggők: DISTANCE → időtartam + tempó (`CardioFormatter.pace`)
  + szintemelkedés; MACHINE → táv + átlag-teljesítmény + kadencia + ellenállás + gép-kalória;
  GAME → helyszín + intenzitás + pontszám.
- **Tudatos egyszerűsítés**: a GAME "bruttó idő" (a design M18-ban külön mutatott, a padon
  töltött idővel együtt számoló mező) **nem** jelenik meg — egy kézzel rögzített GAME session
  esetén a bruttó idő mindig **pontosan egyenlő** a játékidővel (a `LogCardioSheet` egyetlen
  időtartam-mezőt vesz fel, abból lesz mindkettő), tehát a két szám megkettőzése ma
  félrevezető lenne. A pályán/padon megkülönböztetés csak a C2 élő edzésnél válik valódivá.
- Nincs "Értékelés" felszólítás egy nem értékelt session-nél, és nincs szerkesztés-gomb — a
  kész-ha csak "megnyitható és olvasható"-t kér, a szerkesztés a C2.8 dolga.

**`presentation/open_workout_screens.dart`**: a C0.4 óta várakozó `TODO(cardio)` feloldva —
`openSessionScreen` mostantól `session.isCardio` esetén `CardioSummaryScreen`-t nyit,
`STRENGTH`-nél változatlanul `LogSessionScreen`-t. **Ez a fájl nem szerepelt a C1.9 fájllistájában**,
de enélkül a lépés saját kész-ha-ja ("a mentett edzés megnyitható és olvasható") nem teljesülne:
e nélkül a `sessions_tab.dart` kártyájára koppintva egy cardio session ma is az üres,
gyakorlat-alapú `LogSessionScreen`-t nyitná meg — nem hibázna (C0.3 audit óta védett eset), de
helytelen képernyőt mutatna. Ugyanaz a döntés, mint C1.7-nél: a terv fájllistája irányadó, nem
kimerítő.

**Tesztek:**
- `rpe_selector` külön tesztfájlt nem kapott — a `PostWorkoutFeedbackSheet`-en és a
  `LogCardioSheet`-en keresztül már lefedett, önmagában triviális widget.
- `log_cardio_sheet_test.dart` bővült 4 új teszttel: GAME mezők megjelenése, GAME beküldés
  (helyszín/intenzitás/pontszám a `cardio`-ban, DISTANCE/MACHINE mezők érintetlenül), RPE+jegyzet
  helyes átadása, és üres jegyzet → `null` (nem üres string). A meglévő Save-koppintásokat egy
  közös `_tapSave` helper váltotta ki: az RPE+jegyzet mezőkkel a lap tartalma rendszeresen
  túlnyúlik az alapértelmezett teszt-viewporton, és egy képernyőn kívüli koppintás korábban csak
  figyelmeztetett, nem buktatta el a tesztet — most `ensureVisible` előzi meg minden Mentés-tapot.
- `cardio_summary_screen_test.dart` (új, 6 teszt): mindhárom család fő+másodlagos metrikái,
  a DISTANCE táv-nélküli fallback, és az értékelt/nem értékelt eset.
- `open_session_screen_navigation_test.dart` (új, 2 teszt): `openSessionScreen` ténylegesen
  `CardioSummaryScreen`-t nyit cardio session-re, és változatlanul `LogSessionScreen`-t
  erősítőre — ez volt az egyetlen ág, amit a C0.4-es `TODO` óta semmilyen teszt nem fedett.

**Eredmény:** `flutter analyze` (teljes projekt) tiszta; a teljes `flutter test` **724/728
zöld** — a 4 bukás mind a már ismert, cardión kívüli `chat_repository_test.dart`
Windows-fájlzár-flake (lásd C1.6 feljegyzés). Ezzel a **teljes C1 iteráció (C1.1–C1.9) kész** —
**MF2 elérve**: kézzel rögzíthető egy cardio edzés (mind a hét típus, mind a három család),
a lista ikonos és szűrhető, a mentett edzés megnyitható és olvasható.

---

## C2.1 kész (2026-08-11) — `CardioSessionScreen` váz + epoch-alapú mozgásidő

Ez a **C2 iteráció első lépése** — a Windowson fejleszthető ág (`C2.1`–`C2.9`) kezdete, a fenti
a/b-bontás szerint. Ez volt az **első valóban új Drift-oszlop C1.5 óta**: a séma-munka (C0–C1)
mind meglévő táblákat bővített cardio-mezőkkel, ez itt viszont futásidejű, **kliens-only**
állapotot vezet be, ami sosem szinkronizálódik.

**A tervezési döntés, ami mindent visz: epoch-checkpoint, nem élő számláló.** A kész-ha
("App-kilövés után az edzés helyreáll a pontos mozgásidővel") két lehetséges megvalósítást
engedne: (a) egy `movingSeconds`-ot másodpercenként növelő számláló, driftbe írva minden
tick-nél, vagy (b) egy **epoch-időbélyeg**, amiből a pontos érték bármikor visszaszámolható. A
(b)-t választottam — ez a kodbázisban **már bevett minta** (a pihenő-időzítő
`restEndsAtEpochMs`-je, amit az 53-as doc §5 kifejezetten a Live Activity payloadhoz is javasol:
"Egyetlen kivétel: az idő továbbra is epoch-alapú... hogy a natív felület magától ketyegjen,
frissítés-kvóta nélkül"). Ennek két közvetlen következménye van:
- **Nem kell másodpercenkénti DB-írás** — csak a valódi állapotváltásoknál (indítás, szünet,
  folytatás, befejezés) írunk driftbe; a ticker a képernyőn csak `setState`-et hív.
- **Az app-kilövés utáni helyreállás "ingyen" jön** — egy `RUNNING` közben megölt appnál a
  `movingSinceEpochMs` egyszerűen ott marad, ahol volt; amikor a session újra betöltődik
  (akár másnap), a `liveMovingSeconds(now)` helyesen beleszámolja a **teljes** halott-app
  intervallumot is, mert nincs "élő" állapot, amit el kellene veszíteni — csak egy
  falióra-időbélyeg, amit bármikor újra ki lehet értékelni.

**Séma** (`core/local_db/tables/workout_session_tables.dart`, `app_database.dart`): új
`movingSinceEpochMs` (nullable int) oszlop a `workout_sessions` táblán — `schemaVersion` 34→35,
a bevett `_addColumnIfMissing` migrációs mintával. **Tudatosan kliens-only**: a
`WorkoutSessionRepository._payload()` sosem tartalmazza (a szerver nem is ismeri), és a
`pull_engine.dart`-ot **nem kellett módosítani** — az `_upsertWorkoutSession` már ma is explicit
mezőnkénti `WorkoutSessionsCompanion`-t épít, ami sosem hivatkozik erre az oszlopra, tehát egy
pull-lal érkező frissítés a Drift `.write()` szemantikája szerint **érintetlenül hagyja** —
pontosan ez a kívánt viselkedés (egy másik eszköznek semmi dolga azzal, hogy *ezen* a telefonon
melyik képernyő van épp tick-elés közben).

**Domain** (`domain/workout_session.dart`): `movingSinceEpochMs` mező + két új tag:
- `isCardioRunning` getter (`inProgress && movingSinceEpochMs != null`).
- `liveMovingSeconds(DateTime now)` — a `now`-t explicit paraméterként veszi át (nem
  `DateTime.now()`-t hív belül), hogy tiszta, órafüggetlen unit-tesztekkel ellenőrizhető legyen.

**Repository/Controller**: `create()`/`update()` bővítve `movingSinceEpochMs` paraméterrel,
ugyanazzal az "absent-preserving" `Value<T>` konvencióval, mint a többi mező — `rate()`/
`enrichHealthMetrics()` (amik nem tudnak a cardio-checkpointról) így nem törölhetik ki
véletlenül egy futó session ellenőrzőpontját. Négy új kontroller-metódus
(`startCardioSession`/`pauseCardioSession`/`resumeCardioSession`/`finishCardioSession`) — mind
vékony `_repo.create()`/`update()` hívás; a "mennyi a mozgásidő **most**" számítást szándékosan
a **hívó** (a képernyő) végzi, nem a repository — így a repository/kontroller réteg
óra-független és egyszerűen tesztelhető marad.

**`presentation/cardio_session_screen.dart`** (új) — **tudatosan nem családfüggő még**: a
DISTANCE/MACHINE/GAME elrendezések a C2.2/C2.3/C2.4 lépésekre maradnak, ez a lépés csak a
vázat építi (ahogy a táblázat-sora is mondja). Amit tartalmaz:
- `ActivityChip` + típusnév + állapotcímke (Folyamatban/Szünet/Befejezve) + a mozgásidő nagy
  számjegyekkel (`CardioFormatter.duration`), családtól függetlenül.
- `Timer.periodic(1s)` csak `setState`-et hív — **nincs másodpercenkénti DB-írás** (l. fent).
- Szünet/Folytatás/Befejezés gombok, mindegyik a megfelelő kontroller-hívást indítja, hibánál
  `AppSnackbar`-ral jelez és **nem** változtatja a látható állapotot (a felhasználó újra
  próbálhatja).
- **`IDLE` a gyakorlatban sosem renderel** ezen a képernyőn — a képernyő mindig egy már
  elindított (`startedAt` kitöltött) session-nel példányosul; a "hogyan indul el" (FAB
  hosszú nyomás) a C2.7 dolga.
- **`ENDING` egyelőre egy sima megerősítő `AlertDialog`**, nem a húzásos (slide-to-finish)
  gesztus — az a C2.5 táblázat-sorában külön szerepel ("befejezés húzással"), tudatosan nem
  itt épült meg. A kész-ha ehhez a lépéshez nem köti ki a gesztust, csak azt, hogy a
  mozgásidő pontosan helyreálljon.
- **`SUMMARY` egyelőre egy minimális "Befejezve" placeholder-nézet** (a gombok eltűnnek, a
  végső mozgásidő látszik) — az RPE-bevitel, kézi szerkesztés és "szerkesztve" jelölés a
  C2.8 táblázat-sorának a tárgya.

**`open_workout_screens.dart`**: a C1.9-ben épített cardio-ág tovább finomítva —
`session.isCardio && session.inProgress` → `CardioSessionScreen`; `session.isCardio` és
befejezve → változatlanul `CardioSummaryScreen`; `STRENGTH` változatlan. Ez a fájl megint nem
szerepelt a C2.1 táblázat-sorának fájllistájában (ami üres, "–"), de e nélkül a kész-ha nem
lenne tesztelhető a valós navigációs úton keresztül — ugyanaz a döntés, mint C1.7/C1.9-nél.

**Tesztek** (mindegyik Windowson futtatva, Docker/Testcontainers nélkül — a mobil oldali Drift
tesztek `NativeDatabase.memory()`-t használnak, nem a backend Postgres-mintát):
- `workout_session_cardio_live_test.dart` (új, domain-szint, 7 teszt): `liveMovingSeconds`
  mind a négy eset (szünetel, sosem mozgott, fut, **app-kilövési rés áthidalva** — ez utóbbi
  szó szerint a kész-ha bizonyítéka, tiszta függvényként, process-kilövés szimulálása nélkül),
  `isCardioRunning` mindhárom eset.
- `workout_session_repository_cardio_live_test.dart` (új, Drift, 4 teszt): a mező
  perzisztálódik, de **sosem** kerül a kimenő payloadba (`create` és `update` is), és egy
  cardio-t nem ismerő `update()`-hívás (mint `rate()`) nem törli ki véletlenül.
- `cardio_session_screen_test.dart` (új, 8 teszt): a kritikus eset — egy régóta nyitott
  checkpointtal újranyíló képernyő **az első frame-en** a teljes eltelt időt mutatja (nem kell
  hozzá ticker-tick); Szünet/Folytatás/Befejezés helyes kontroller-hívásai a helyes, élőben
  számolt összeggel; a megerősítő dialógus törlése nem változtat semmin; egy sikertelen írás
  után a képernyő a régi, látható állapotban marad.
- `open_session_screen_navigation_test.dart` bővítve a folyamatban lévő cardio esettel.

**Eredmény:** `flutter analyze` (teljes projekt) tiszta; `flutter test test/features/workouts`
**313/313 zöld**; a teljes `flutter test` **746/749 zöld** — a 3 bukás a már ismert,
cardión kívüli `chat_repository_test.dart` Windows-fájlzár-flake.

---

## C2.2 kész (2026-08-11) — DISTANCE elrendezés + „nincs távforrás” ág

**A forrás-konfliktus, amit fel kellett oldani.** Két doc mond mást a DISTANCE család domináns
számáról: az 53-as doc §4.2 táblája (korábbi, a design-canvas előtti terv) "eltelt mozgásidőt"
ír; az 57-es doc §2 táblája + a DD-5 döntési napló ("eldöntve 2026-08-09") **táv**-ot mond,
három indoklással (a táv a "cél alakú" szám, a konzisztenciát a *szerep* tartja — DISTANCE-nál
táv, MACHINE-nél idő, GAME-nél játékidő —, és a hiányzó távforrást nem elrendezéssel, hanem a
hiány kimondásával kell kezelni). Az 57-es a **később döntött, explicit "eldöntve" jelölésű**
forrás, és a C2.2 táblázat-sora saját maga is erre hivatkozik ("A domináns szám a [57 §2]
szabálya szerint vált") — tehát az 57-es doc nyert: **táv a domináns**, nem idő. Ugyanaz a
minta, mint C1.7 (M20 vs. a táblázat-sor szövege) és C1.9 (M15 vs. a kész-ha) esetén: a
design-döntési dokumentum vagy a lépés saját kész-ha-ja explicit iránymutatása erősebb, mint egy
korábbi tervdoksi táblázata.

**A gyakorlati következmény: C2.2-ben GPS nélkül a "nincs távforrás" ág szinte mindig aktív.**
A GPS csak C4a-ban érkezik ([51 §4](51-cardio-overview-plan.md): "a C2 végén az élő cardio GPS
nélkül is teljes"), tehát ebben a lépésben **nincs automatikus távforrás egyáltalán** — a táv
kizárólag a felhasználó kézi bevitelén keresztül kap értéket, pontosan úgy, ahogy az 57-es doc
DD-5-je előírja: "távforrás nélkül... a táv szerkeszthető mezőként a másodlagos sorba kerül." Ez
nem egy ritka szél-eset, hanem **a lépés fő útvonala** — a kézi táv-szerkesztő dialógus ezért
nem opcionális extra, hanem a kész-ha ("nincs 0,00 km nagy helyen") tényleges megvalósítása:
enélkül a domináns szám örökre az üres táv-eset maradna.

**`application/workout_session_controller.dart`**: új `updateLiveCardioMetrics(clientId,
{startedAt, cardio})` — vékony `_repo.update()`-hívás, ami **szándékosan nem nyúl**
`movingSeconds`/`movingSinceEpochMs`-hez (távolság-szerkesztés sosem érinti az időzítést).

**`presentation/cardio_session_screen.dart`**:
- `_family` getter (`activityFamilyOf(_activityType)`) dönti el, melyik törzs renderel;
  MACHINE/GAME egyelőre a C2.1-es family-agnosztikus placeholdert kapja (C2.3/C2.4 dolga).
- DISTANCE törzs: domináns szám = táv, ha `_distanceMeters` pozitív, egyébként mozgásidő
  (fallback). Másodlagos sor **mindig 3 csempe**, a design M04/M11 szerint: amelyik a
  {táv, mozgásidő} párból épp nem domináns, + tempó (kötőjel, ha nincs táv) + pulzus (mindig
  kötőjel — nincs szenzorforrás bekötve még, ez egy jövőbeli óra-integráció).
- A táv-csempe **mindig** koppintható (domináns helyen is, másodlagos helyen is) — GPS nélkül
  ez az egyetlen mód, ahogy a táv valaha értéket kap, tehát nincs értelme csak a fallback-ágra
  korlátozni a szerkeszthetőséget.
- A szerkesztő-dialógus mértékegység-tudatos (`Settings` metric/imperial), és a beírt érték
  `distanceSource: 'MANUAL'`-lel megy a `CardioMetrics`-be — ugyanaz a provenience-konvenció,
  mint a `LogCardioSheet`-nél (C1.8).
- **Tudatos egyszerűsítés**: a táv-szerkesztés **teljes cserével** írja a `cardio` blokkot
  (`CardioMetrics(distanceMeters: ..., distanceSource: 'MANUAL')`), nem összefésüléssel — ma ez
  biztonságos, mert a DISTANCE család C2.2-ben semmilyen más cardio-mezőt nem állít be még
  (szintemelkedés stb. később). Egy jövőbeli MACHINE/GAME élő-szerkesztő útvonalnak már
  össze kellene fésülnie, mint a `LogCardioSheet` submit-ja teszi.
- **Egy valódi hibát fogott el a teszt, nem csak a design-kérdést**: a dialógus eredetileg egy
  kézzel kezelt `TextEditingController`-t `dispose()`-olt közvetlenül a `showDialog` visszatérése
  után — ez "A TextEditingController was used after being disposed" hibát dobott, mert a
  bezáródó dialógus-átmenet még egy frame-ig a mezőhöz volt csatolva. Javítás: `TextFormField`
  `initialValue`-val (nincs kézzel kezelt controller, a widget saját State-je intézi az
  élettartamot) — ez egy általános Flutter-csapda, nem cardio-specifikus, de itt a
  widget-tesztek (nem a kézi kipróbálás) fogták meg.

**Tesztek:**
- A meglévő `cardio_session_screen_test.dart` (C2.1) kapott egy `settingsControllerProvider`
  fake-et — a DISTANCE-törzs mostantól ezt is olvassa, és enélkül egy valódi, DB-függő
  Riverpod-providert épített volna fel a widget-tesztben (ugyanaz a hiba-osztály, mint
  C1.6/C1.9-nél, most a képernyő-tesztre is átterjedve). A meglévő 8 teszt asszerciói
  változatlanul érvényesek maradtak, mert mindegyik fixture táv nélküli RUNNING session — a
  fallback-ág pontosan ugyanazt a family-agnosztikus megjelenítést adja, mint amit a C2.1-es
  tesztek eredetileg vártak.
- `cardio_session_screen_distance_test.dart` (új, 8 teszt): domináns/másodlagos csere mindkét
  irányban, a nulla táv ugyanúgy fallback-ol, mint a hiányzó, a "sosincs nagy 0,00 km" garancia,
  a táv-csempe koppintása mindkét pozícióból megnyitja a szerkesztőt, mentés helyesen számol
  mértékegység szerint (metric és imperial is), Mégse nem ír semmit, és egy MACHINE session
  változatlanul a generikus törzset kapja.

**Eredmény:** `flutter analyze` (teljes projekt) tiszta; `flutter test test/features/workouts`
**321/321 zöld**.

---

## C2.3 kész (2026-08-11) — MACHINE elrendezés

**Nincs forrás-konfliktus ezúttal** — az 53-as és az 57-es doc egyaránt "eltelt mozgásidőt" mond
a MACHINE domináns számának, táv · kadencia (rpm) · teljesítmény (W) másodlagos sorral. A
domináns hely tehát **rögzített**, nem vált (a DISTANCE-nél látott táv/idő-csere itt nem
értelmezett) — az M05 makett jegyzete szerint is: "a szobabicikli 'negyven perc', nem
'tizennyolc kilométer' — a gép távja amúgy is becslés."

**Ugyanaz a "nincs automatikus forrás" valóság, mint C2.2-ben, csak három mezőre.** Nincs
Bluetooth-os edzésgép-párosítás tervben, tehát a táv/kadencia/teljesítmény mindegyike **kézzel
bevitt** érték — ezt mondja ki a kész-ha szó szerint ("bevihető menet közben"). Az ellenállás
külön kezelést kapott: az 53-as doc "Extra vezérlő" oszlopa expliciten "ellenállás-léptetőt" kér
(nem dialógust), a "intervallum-sáv" társát viszont "(C7)"-tel jelöli — vagyis egy **jövőbeli**
(szobabicikli-specifikus) lépésre halasztva. Az intervallum-sáv ezért **nem** épült meg itt; az
ellenállás-léptető igen, mert semmi nem jelöli későbbre.

**Refaktor, amit a MACHINE-lépés kikényszerített**: a C2.2-es `_updateDistance` **teljes
cserével** írta a `CardioMetrics`-et, a kódban dokumentált feltétellel: "ma biztonságos, mert a
DISTANCE család semmilyen más cardio-mezőt nem állít be még." A MACHINE ág ezt a feltételt
azonnal megsérti — négy egymástól független mező (táv, kadencia, teljesítmény, ellenállás)
ugyanazon a session-ön, bármelyik önmagában szerkeszthető. Ha a régi teljes-csere logika marad,
a kadencia beállítása **kitörölné** a már beírt teljesítményt. Megoldás: mind a négy mező saját
helyi state-ben követve, egy közös `_updateCardioMetrics({distanceMeters, avgCadence, avgWatts,
resistanceLevel})` metódus mindig a **teljes**, összefésült `CardioMetrics`-et építi újra és
küldi — minden `_edit*`/`_adjust*` hívó csak a saját megváltozott mezőjét adja át, a többi a
jelenlegi state-ből jön. Ugyanaz az elv, mint a `LogCardioSheet` submit-jánál, csak élő
session-re alkalmazva. Ezt egy dedikált regressziós teszt zárja le (lásd lent) — enélkül a
hiba csendben marad (a UI helyesen frissülne a *most* szerkesztett mezőre, csak a többi tűnne
el a háttérben, ugyanaz a "néma hiba" kategória, mint amit a doc 11. szekciója már korábban is
kiemelt más lépéseknél).

**Refaktor, ami emiatt kifizetődött**: a C2.2-es `_editDistance` egyedi dialógus-kódja
kiemelve egy általános `_promptNumber(title, suffix, initialText)` helperré — a MACHINE három
mezője (táv, kadencia, teljesítmény) mind ezt hívja, csak a címke/mértékegység különbözik. A
domináns-szám blokk is kiemelve egy közös `_DominantMetric` widgetbe (opcionális `onTap`-tal) —
a DISTANCE-nél koppintható (táv-szerkesztésre), a MACHINE-nél nem (nincs mit felülírni rajta).

**`presentation/cardio_session_screen.dart`**:
- `_machineBody`: rögzített "mozgásidő" domináns (nem koppintható); táv/kadencia/teljesítmény
  három csempe, mindegyik koppintható, "—"-t mutat üresen; ellenállás +/− léptető, 0-nál alul
  zárolva (nincs értelmes negatív ellenállás).
- `build()` mostantól `switch (_family)`-vel ágazik három irányba (DISTANCE/MACHINE/GAME) — a
  korábbi bináris `_family == distance ? ... : genericBody` helyett, mert immár két valódi ág
  van a generikus mellett.

**Tesztek:**
- `cardio_session_screen_machine_test.dart` (új, 7 teszt): domináns mindig mozgásidő és sosem
  vált tábra, a domináns blokk nem koppintható, **a kadencia szerkesztése nem törli a már
  beállított távot/teljesítményt** (a refaktor valódi regressziós próbája), a fordított irány
  (teljesítmény szerkesztése megőrzi a kadenciát), az ellenállás-léptető növel/perzisztál és
  0-nál nem enged tovább csökkenni.
- A meglévő `cardio_session_screen_distance_test.dart`-ban az "egy MACHINE session még mindig a
  generikus törzset kapja" teszt **elavulttá vált** (a MACHINE immár saját törzset kap) —
  átírva "egy GAME session"-re, ami tényleg még a C2.1-es placeholdert kapja C2.4-ig.

**Eredmény:** `flutter analyze` (teljes projekt) tiszta; `flutter test test/features/workouts`
**328/328 zöld**.

---

## C2.4 kész (2026-08-11) — GAME elrendezés + pályán/padon kapcsoló

**Ez volt a három családi elrendezés közül a legmélyebb** — nem elrendezés-variáció, hanem egy
valódi második, a meglévőtől független időzítő bevezetése. A GAME az egyetlen család, ahol a
C2.1-ben lefektetett egyetlen szünet-fogalom (`_isRunning`/`_isPaused`, a `movingSinceEpochMs`
nullából/nem-nullból származtatva) többé **nem elég**: a pályán/padon váltás is megállítja a
játékidőt, de a bruttó idő eközben **tovább fut** — az M07 makett jegyzete szó szerint kimondja,
hogy ez a "meccs szünet" (a teljes edzés-szintű szünet) **külön** akció a pályán/padon
kapcsolótól, és csak az utóbbi állítja meg a bruttó időt is.

**A modell, amit ez kikényszerített**: a `_isRunning`/`_isPaused` mostantól egy explicit
`_manuallyPaused` mezőből származik (nem a `movingSinceEpochMs` null-ságából, mint C2.1–C2.3-ban
— az a mező immár **két** ok miatt is nullázódhat: kézi szünet VAGY padon). A "gyűjt-e most a
játékidő" feltétel: `!_manuallyPaused && (nem GAME VAGY pályán)`. Emellett egy **teljesen
független második epoch-checkpoint pár** (`_grossSeconds`/`_grossSinceEpochMs`) — ugyanaz az elv,
mint C2.1 `movingSeconds`/`movingSinceEpochMs`-e, csak a bruttó időre, és csak `!_manuallyPaused`
által vezérelve (a pályán/padon állapot nem érinti).

**Tudatos, dokumentált egyszerűsítés: a bruttó idő és a pályán/padon állapot nem perzisztálódik
driftbe.** A domain-modellnek/backendnek **nincs** mezője egyikre sem — a `movingSeconds` már ma
is *a* cardio-időtartam ([56 D-C3.3](56-cardio-statistics-plan.md), streak-küszöb,
`effectiveDuration`), egy új Drift-oszlop bevezetése (mint C2.1-nél a `movingSinceEpochMs`)
ehelyütt aránytalan lett volna egy tisztán élő-képernyős, sosem szinkronizálandó
kényelmi-mérőszámért. Következmény: egy app-kilövés után **nem** lehet eldönteni, hogy egy
lefagyott `movingSinceEpochMs` kézi szünet vagy padon miatt fagyott-e le — a betöltés ilyenkor a
**biztonságosabb** olvasatot választja (kézi szünet, tehát Folytatás gombot mutat, nem
csendben feltételezi, hogy a játékos még pályán van). A bruttó idő ilyenkor a "feltételezzük,
hogy a szezon kezdete óta futott" becslést kapja (`now - startedAt`) — ez felülbecsül egy
esetleges korábbi szünet hosszával, de ez így is jobb, mint nullára visszaállni egy órája futó
meccsnél.

**Q-D2 (pontszámláló láthatósága) — nem megoldva, tudatosan kikerülve.** A táblázat-sor maga
jelzi, hogy ehhez a lépéshez döntés kellene, de az 53-as doc saját táblázata a "gyors pont/gól
léptetőt" **"(C9)"**-cel jelöli — egy későbbi, sportspecifikus iterációra ("Játék") halasztva.
Mivel C2.4 kész-ha-ja saját maga is csak zárójelben, nem a fő kritériumban említi a
pontszámlálót, és a valódi otthona C9, **nem épült be pontszámláló ebbe a lépésbe** — ez nem
hiányosság, hanem az 53-as doc saját elhelyezési döntésének követése. (A C1.9-ben épült
`LogCardioSheet` pontszámláló más eset: utólagos, egyszeri bevitel egy már befejezett
session-höz, nem élő, játék-közbeni számláló — nem ugyanaz a Q-D2 által felvetett aggály.)

**`presentation/cardio_session_screen.dart`**:
- `_gameBody`: domináns "JÁTÉKIDŐ" (nem koppintható); másodlagos sor bruttó idő · pulzus (—) ·
  zóna (—); alatta a nagy pályán/padon kapcsoló (`_CourtToggleButton`, két 130×84 px gomb,
  haptikus visszajelzéssel — [53 §4.3](53-cardio-mobile-plan.md) explicit mérete/hüvelyk-zóna
  kérése szerint).
- A meglévő generikus Szünet/Folytatás gomb-sor **megmarad** GAME-nél is — ez testesíti meg a
  "meccs szünetet"; a felirat nem lett GAME-specifikusra cserélve ("Meccs szünet" helyett
  változatlanul "Szünet"/"Folytatás") — apró, tudatos vizuális egyszerűsítés.
- `_genericBody` **törölve** — mindhárom család saját törzset kapott, nincs több "még nincs
  elrendezése" eset, tehát a régi fallback holt kóddá vált.
- Két, a review-ban észlelt holt getter (`_isPaused`, `_shouldAccrueMoving`) eltávolítva —
  mindkettő a régi, egyszerűbb modellből maradt vissza, és az új, három-ágú logikában már nem
  volt hívási helyük (a `_resume()`-ban a "fog-e gyűjteni" kérdést muszáj külön, a
  `_manuallyPaused` **még régi** értékével számolni, tehát a getter maga félrevezető lett volna).

**Tesztek** (`cardio_session_screen_game_test.dart`, új, 8 teszt) — **a numerikus tick-elés nem
tesztelhető közvetlenül**: mind `_liveMovingSeconds`, mind `_liveGrossSeconds` valódi
`DateTime.now()`-t olvas, amit a `tester.pump(duration)` nem mozgat előre (csak a Timer-sor fut
le szimulált időben, a benne olvasott órát nem). A "két óra másképp viselkedik" állítást ezért —
ugyanúgy, mint C2.1 kilövés-teszteknél — **konstruált, már eltérő állapotú session-ökkel**
bizonyítja, nem várakozással: egy `movingSeconds: 600` + `startedAt: 20 perce` frissen betöltött,
lefagyott session az első frame-en **két különböző, determinisztikus** számot mutat
(játékidő 10:00, bruttó ~20:00) — ez önmagában bizonyítja a független követést. A
kapcsoló/szünet **vezérlésfolyamát** (mi fagy le, mi nem, mikor van letiltva) közvetlenül, a
rögzített kontroller-hívásokon keresztül ellenőrzi: Padon → `pauseCardioSession`; Pályán ← Padon
→ `resumeCardioSession`; kézi szünet közben mindkét kapcsológomb `onTap: null`; kézi szünetből
Folytatás **pályán maradva** újraindítja a játékidőt, **padon maradva** nem (a `resumeCardioSession`
egyáltalán nem hívódik ez utóbbi esetben) — ez a lépés legfontosabb regressziós próbája.

A meglévő `cardio_session_screen_distance_test.dart`-ban egy másik elavult teszt ("egy GAME
session még mindig a generikus törzset kapja") is törölve — GAME immár saját törzzsel
rendelkezik, nincs több család a generikus placeholderen.

**Eredmény:** `flutter analyze` (teljes projekt) tiszta; `flutter test test/features/workouts`
**335/335 zöld**. Ezzel a **három családi elrendezés (C2.2–C2.4) mind kész.**

---

## C2.5 kész (2026-08-12) — szünet-állapotok (kézi vs. auto-pause) + befejezés húzással

**A GPS-hiány miatti tervezési döntés, ami mindent visz.** Az auto-pause **tényleges kiváltása**
GPS-sebességre épül ([53 §4.3](53-cardio-mobile-plan.md)), ami csak C4a-ban érkezik — a
táblázat-sor ezt maga is jelzi: az auto-pause *bekötése* külön, C4a.5 alatt szerepel. C2.5 tehát
nem építhet valódi triggert, csak a **vázat és a vizuált**: egy `autoPause()` publikus hívást,
amit ma senki nem hív (a GPS-kód C4a.5-ben fog), plusz a két állapot (kézi/auto) vizuálisan
elkülönített megjelenítését. Ugyanaz a minta, mint C2.1 `movingSinceEpochMs`-e vagy C2.4
`_onCourt`-ja: egy jövőbeli lépésnek szánt horgony, ami már ma tesztelhető és helyes.

**A horgony konkrétan: a State-osztály publikussá tétele.** A `_CardioSessionScreenState` mostantól
`CardioSessionScreenState` — ugyanaz a minta, mint a Flutter saját `Form`/`FormState`,
`Scaffold`/`ScaffoldState` párosa. Három publikus metódus rajta: `pause()`/`resume()` (a gombok
mögötti, korábban privát logika átnevezve, változatlan viselkedéssel) és az új `autoPause()` — ez
utóbbi a `_family != distance` esetben nyugodt no-op (auto-pause csak DISTANCE-nél értelmezett,
[53 §4.3](53-cardio-mobile-plan.md)), egyébként ugyanazt a checkpoint-fagyasztást végzi, mint
`pause()`, csak `_PauseReason.auto`-t jelölve. C4a.5 dolga lesz egy `GlobalKey<CardioSessionScreenState>`-en
keresztül hívni, amint a GPS-sebesség 15 mp-ig 0,5 m/s alatt marad — ez a lépés csak azt
garantálja, hogy amikor az a hívás megérkezik, a képernyő helyesen reagál rá.

**Miért nincs külön `autoResume()`.** A design (DD-6, [57 §](57-cardio-design-prompt.md)) és az
53-as doc is csak a *szüneteltetett* állapot vizuálját különbözteti meg — a folytatás, akár a
felhasználó koppint, akár a GPS észlel újra mozgást, ugyanaz a hívás (`resume()`), ugyanaz a
checkpoint-nyitás. Nincs mit külön "auto-folytatásnak" jelölni a képernyőn.

**Pause-kártya, M08 vs M09.** Új `_PauseStatusCard`: kézi szünetnél semleges (`onSurfaceVariant`)
szín, `pause_circle` ikon, "Paused" cím + "You stopped it · X ago" alcím (élő, a szünet kezdete
óta ketyegő időtartammal — ehhez a tickernek **futnia kell szünet alatt is**, nem csak futás
közben: az `initState`/`_pauseAs` mostantól sosem állítja le a tickert pause-kor, csak
`_finish()`-nél). Auto-pause-nál a design saját, nem témázott barnás-drapp árnyalata
(`#C49A6C`, [design M09](design/Lifey%20Cardio%20Design.dc.html)), `motion_photos_paused` ikon,
szegélyezett kártya, és a doksi saját szövege ("Megálltál, ezért a mérést mi állítottuk meg.
Magától folytatódik, amint elindulsz."). A szünetelt família-törzs (`familyBody`) 0,6 opacitással
kiszürkül szünet alatt (M08 jegyzete: "egyik sem változik"), de **tapinthatóság nélkül nem**
csorbul — a metrika-szerkesztő dialógusok szünet alatt is elérhetők maradnak, mert épp ilyenkor a
legkényelmesebb kézzel korrigálni egy értéket.

**A folytatás-gomb is elágazik reason szerint**: kézi szünetnél a megszokott teli zöld
"Folytatás" `FilledButton`; auto-pause-nál egy új `_AutoPauseResumeButton` — szaggatott szegély,
két sor ("Move to resume" / "or tap here to resume manually"), tudatosan **nem** teli gomb, mert
az elsődleges elvárás itt a mozgás, nem a koppintás (design M09 jegyzete).

**Befejezés húzással — a régi `AlertDialog` teljesen eltűnt.** A kész-ha szó szerint kimondja:
"a befejezés koppintásra nem történik meg." Egy `showDialog` + `FilledButton('Finish')` pár
strukturálisan **mindig** koppintásra zárható, tehát nem csak kiegészítésre, hanem **cserére**
szorult. Az új `_SlideToFinishBar` nyers `Listener`-t használ (nem `GestureDetector`-t) — ez a
döntés nem esztétikai: egy `GestureDetector` tap-recognizere egy mozdulatlan le-fel koppintásra is
lefutna, pont azt engedve meg, amit a kész-ha tilt. A `Listener` pointer-eseményei ezzel szemben
nyers adatot adnak, a "koppintás" fogalma sehol nem jelenik meg a döntési logikában:
- **Húzás**: `onPointerMove` a helyi `dx`/szélesség arányból élő `progress`-t számol; 75%
  fölötti elengedésnél (`onPointerUp`) fut le a befejezés, alatta 0-ra ugrik vissza.
- **Hosszú nyomás (600 ms)**: `onPointerDown`-kor egy `Timer` indul; ha 600 ms-en belül nincs
  `onPointerMove`/`onPointerUp`, lefut ugyanaz a befejezés-út, haptikus jelzéssel — ez az M08
  jegyzet "hosszú nyomás (600 ms a zászlóra) ugyanezt teszi" sorának a megvalósítása.
- **Sima koppintás**: sem 75%-os elmozdulás, sem 600 ms várakozás nem történik, tehát egyik ág sem
  fut le — ez pontosan a kész-ha bizonyítéka, és ezt egy dedikált teszt is lezárja (lásd lent).

**M12 megerősítő overlay, megosztott `ValueNotifier`-en át.** A húzás közben megjelenő,
elsötétített összegző réteg (`_FinishConfirmationOverlay`) és maga a sáv két külön widget — az
overlay a képernyő `Stack`-jének tetején, a sáv a görgethető tartalom belsejében. Mindkettő
ugyanazt a `ValueNotifier<double> _finishProgress`-t olvassa/írja (nem `setState`-en át
szinkronizálva): a sáv minden pixelnyi húzásnál írja, az overlay `ValueListenableBuilder`-rel
olvassa **és** a saját "Mégse" sora közvetlenül nullázza — enélkül a Mégse gomb nem tudná
visszaállítani a sáv belső húzás-állapotát, mert a kettő nem ugyanaz a widget-példány.
**Tudatos átvétel, nem duplikálás**: az overlay szövege a már meglévő `finishCardioConfirmTitle`/
`finishCardioConfirmMessage` ARB-kulcsokat használja (a leírásuk frissítve "dialógus" → "overlay"),
mivel tartalmilag ugyanaz a megerősítő szöveg, csak más felületen jelenik meg.

**Váratlan lelet, C2.5-höz nem tartozó, de a munka során felfedezett holt ARB-kulcs**: a régi
`cardioSessionPausedLabel` ("Paused"/"Szünet") a plain "Paused" állapot-szöveget adta, amit ez a
lépés lecserélt a pause-kártyára — a kulcs emiatt **teljesen árva** lett (semmilyen fájl nem
hivatkozott rá a törlés után, ellenőrizve `grep`-pel). Töröltem mindkét ARB-ból és
újragenaráltam a lokalizációt, ahelyett hogy holt súlyként otthagytam volna — ugyanaz az elv,
amit a doc korábban is követett (pl. C1.2 `cardio_details` időbélyeg-mezőjének tudatos
kihagyása).

**Tesztek** (`cardio_session_screen_test.dart`, jelentősen bővítve — a régi "Finish asks for
confirmation"/"cancelling the finish confirmation" két teszt törölve, hiszen a mögöttük álló
`AlertDialog` megszűnt):
- A meglévő futó/szüneteltetett teszteket kiegészítettem a pause-kártya és a sáv jelenlétének
  ellenőrzésével (a régi `OutlinedButton('Finish')` helyett `find.text('Slide to finish')`).
- `slide-to-finish` csoport (5 teszt): sima koppintás nem fejez be (600 ms várakozással is
  ellenőrizve, hogy nem marad égve egy késleltetett timer); 75% fölötti húzás + elengedés az
  overlay-t mutatja, majd befejez és eltünteti a vezérlőket; 75% alatti húzás visszaugrik;
  az overlay Mégse sora nullázza az állapotot anélkül, hogy a még lenyomva tartott pointer
  bármit tenne utána; 600 ms-es hosszú nyomás (mozgás nélkül) befejez.
- `auto-pause` csoport (3 teszt): `state.autoPause()` (a publikus State-en, `tester.state<
  CardioSessionScreenState>`-tel elérve) auto-pause kártyát mutat, nem a kézit; a dashed
  folytatás-gomb koppintása ugyanúgy `resumeCardioSession`-t hív, mint a kézi Folytatás; MACHINE
  családon `autoPause()` no-op (nincs `pauseCalls`, nincs kártya).
- Egy kockázati pont, amit a hosszú-nyomás és a sikeres húzás tesztjei tudatosan kerülnek: a
  befejezés után a `_SlideToFinishBar` (és a rajta lévő `Listener`) **eltűnik a fából** (`_isFinished`
  igazra vált, a teljes vezérlő-sor feltétele hamis lesz) — egy `gesture.up()` hívás egy már
  eltávolított `Listener`-re pointer-esemény-küldést kockáztatna. A hosszú-nyomásos tesztben ezért
  szándékosan **nem** hívok `gesture.up()`-ot a Timer általi befejezés után; a húzásos tesztben az
  `up()` maga még biztonságos (a leválasztás csak a rákövetkező `pump`/`pumpAndSettle` alatt,
  aszinkron módon történik meg, az `up()` szinkron dispatch-e után).

**Eredmény:** `flutter analyze` (teljes projekt) tiszta; `flutter test test/features/workouts`
**341/341 zöld** (335 + 6 nettó — 2 elavult teszt törölve, 8 új: 5 slide-to-finish + 3 auto-pause);
a teljes `flutter test` **774/777 zöld**, a 3 bukás a már ismert, cardión kívüli
`chat_repository_test.dart` Windows-fájlzár-flake (lásd C1.6 feljegyzés).

---

## C2.6 kész (2026-08-12) — `activity_ranking.dart`, recency-súlyozott rangsor

Tisztán Dart, semmilyen widget vagy Riverpod-provider nélkül — a `recommended_template_provider.dart`
mintáját követve (ami a *tiszta* predikciós függvényt egy külön, provider-szintű join-tól
elválasztja): ez a lépés csak a rangsoroló függvényt adja, a cím/ikon feloldását (pl. egy
`templateClientId`-hoz tartozó terv neve) a jövőbeli fogyasztókra hagyva (C2.7 gyorsindító lap,
C2.11 app-shortcut, C5.3 óra-payload) — egyik sem épült még, ez a doc §3.4-ben ("D-C.8") leírt,
mindhárom közös igazságforrása.

**A rangsor-kulcs típusa, `QuickStartEntry`.** A doksi szövege szerint a kulcs cardiónál az
`activityType`, erősítőnél a `templateClientId` (sablon nélküli erősítő → egyetlen közös "üres
edzés" vödör). Két névvel-konstruált, értékegyenlőségű osztály (`QuickStartEntry.strength([id])`
és `QuickStartEntry.cardio(type)`) — a `activityTypeLabel`/`Icon`/`Color` (C0.2) már ma is ismeri
a `'STRENGTH'` szentinelt kevert listákhoz ([activity_type.dart:50](../../mobile/lib/features/workouts/domain/activity_type.dart#L50)
sajátdokstringje kifejezetten erre a §3.4-es funkcióra hivatkozik), de a `QuickStartEntry` nem ezt
a string-szentinelt viszi tovább, mert a kulcsnak a sablon-azonosítót is hordoznia kell (két
különböző terv **külön** rangsorolt bejegyzés, nem egy közös "erősítő" alatt).

**A pontszám-formula szó szerint**: `Σ 0.5^(nap / 21)` a kulcs **befejezett**
(`finishedAt != null`) session-jein — egy folyamatban lévő session nulla jelet hordoz, ki van
zárva a `for` ciklus elején. A `nap` tört napokban számol (`inMilliseconds /
millisecondsPerDay`), nem egész napokban — élesebb, teszthez pontosabban számolható decay, és
elkerüli a naphatár-műterméket, amit egy `inDays`-alapú kerekítés okozna.

**A döntetlen-lánc három szintje, a doksi kettő helyett.** A doksi csak kettőt mond ("a frissebb
utolsó használat nyer; ha az is egyezik, a `kActivityTypes` megjelenítési sorrend"), de ez a
sorrend **csak azokra az elemekre ad választ, amik szerepelnek is `_defaultOrder`-ben** (a hét
cardio típus + az üres-edzés vödör) — két **különböző, valódi sablon** (`tPushA` vs. `tPullB`)
egyike sincs ebben a listában, tehát mindkettő ugyanarra a "lista végén" indexre esne, változatlan
döntetlennel. Mivel a `List.sort` Dartban **nem garantáltan stabil**, ez elvben nemdeterminisztikus
kimenetet adhatna azonos bemeneten két futtatás között. Hozzáadtam egy negyedik, a doksiban nem
szereplő, tisztán a determinizmusért felvett szabályt: azonosító szerinti ábécésorrend
(`_identityTiebreak`) — ez a doksi szabályait sosem írja felül (csak azután fut le, hogy mindhárom
korábbi szint már döntetlen), és valós adaton szinte sosem aktiválódik (két különböző sablonnak
egyszerre pontra **és** másodpercre egyező utolsó használata kellene hozzá).

**Hidegindítás = feltöltés, nem csere.** A `_defaultOrder` (üres edzés, majd a hét cardio típus
`kActivityTypes` sorrendben) csak azt a maradékot tölti be, ami a valódi rangsorból hiányzik a
`max`-ig — egy már rangsorolt kulcs (akár valós, akár korábban már betöltött default-elem) nem
kerül be kétszer. Ez azt jelenti, hogy egyetlen valós session esetén is a **valós** bejegyzés áll
elöl, a lista csak alatta egészül ki — nem "vagy-vagy" döntés a valós rangsor és a hidegindítási
lista között, ahogy egy naiv "ha kevés az előzmény, mutasd a defaultot" megvalósítás tenné.

**Tesztek** (`activity_ranking_test.dart`, 15 teszt, öt csoportban): hidegindítás (üres lista,
egyetlen valós bejegyzés + feltöltés, nincs duplikált feltöltés); felezési idő (azonos
gyakoriságnál a frissebb nyer; **két 42 napos session pontra ugyanannyit ér, mint egy 21 napos**
— ez a lépés legfontosabb, kézzel kiszámolt bizonyítéka a felezési időre és az összegzésre
egyszerre; gyakoriság felülírja az egyetlen friss használatot, ha az összpontszám nagyobb);
döntetlen-lánc mindhárom szintje (recency → default sorrend, beleértve az üres-edzés vs. cardio
esetet is → azonosító-ábécésorrend két valódi sablon között); csoportosítás (több sablon nélküli
erősítő session **egy** vödörbe összegződik; különböző sablonok **külön** bejegyzések maradnak);
folyamatban lévő session nem termel pontot és nem jelenik meg; vegyes lista (erősítő + cardio
együtt, kombinált pontszám szerint); `max` levágás és `max: 0` üres lista. Minden pontszám-alapú
asszerció kézzel kiszámolt `0.5^(nap/21)` értékekre épül a teszt kommentjében, nem csak a végső
sorrendre hivatkozik — így egy jövőbeli, hibásan átírt kitevő (pl. `nap/30`) elbukna, nem csak egy
durva sorrend-csere.

**Eredmény:** `flutter analyze` (teljes projekt) tiszta; az új `activity_ranking_test.dart`
**15/15 zöld**; a teljes `flutter test` **789/792 zöld** (774 + 15 új), a 3 bukás a már ismert,
cardión kívüli `chat_repository_test.dart` Windows-fájlzár-flake.

**Következő:** `C2.7` — gyorsindító lap a FAB hosszú nyomására + „Összes” aktivitás-választó,
M01/M02/M03 szerint. Ez lesz `rankQuickStartEntries()` első valódi UI-fogyasztója — itt kell majd
megoldani a `templateClientId` → sablonnév feloldást is (a `recommendedTemplateProvider` mintáját
követve).

---

## C2.7 kész (2026-08-12) — gyorsindító lap + „Összes edzéstípus” választó

**Visszamenőleges javítás a C2.6-ban épített `_defaultOrder`-en, mielőtt bármi más történt volna.**
A C2.6-os "hidegindítás" lista szövegesen az 53-as doc §3.4 mondatát követte ("erősítő → futás →
séta → szobabicikli"), de ez a lépés az M02 design-frame-hez lett rendelve — és az M02 mockup
**más** sorrendet mutat, kimondott indoklással: "futás · séta · erősítő · szobabicikli — a két
GPS-es típus előre, mert azokat nem lehet utólag rekonstruálni." Ugyanaz a minta, mint C1.7/C2.2-nél
korábban: a design-frame (itt: a *saját* frame-je ennek a lépésnek) erősebb forrás, mint egy
korábbi doc táblázatának szövege. Javítás `activity_ranking.dart`-ban: `_defaultOrder` mostantól
`[RUNNING, WALKING, strength(), INDOOR_BIKE, HIKING, BASKETBALL, FOOTBALL, OTHER_CARDIO]`.

Eközben egy **második, tudatosan szét nem választott** hibát is találtam a C2.6-os kódban: a
döntetlen-feloldás (recency után) és a hidegindítás-feltöltés **ugyanazt** a listát használta
(`_defaultOrderIndex`), holott a doksi két **külön** szabályt ír le — "ha [a recency] is egyezik, a
`kActivityTypes` megjelenítési sorrend" (döntetlen) vs. "a lista feltöltve az alapértelmezett
sorrendből" (hidegindítás). Szétválasztva: `_cardioTiebreakIndex` (cardio-cardio döntetlenre,
`kActivityTypes` alapján, erősítő mindig nyer egy cardióval szembeni döntetlent) és `_defaultOrder`
(csak feltöltésre, M02 szerint) — a kettőnek **nem kell** megegyeznie, és az M02 szerint ténylegesen
nem is egyezik (az erősítő a feltöltésben 3. helyen áll, egy döntetlenben viszont mindig nyer).
`activity_ranking_test.dart` érintett tesztjei frissítve az új sorrendre és a szétválasztott
mechanizmusra hivatkozó kommentekkel — mind a 15 teszt továbbra is zöld.

**A FAB hosszú nyomás, megosztott mechanizmus.** A `ShellFabConfig` (`shared/widgets/shell_fab.dart`)
kapott egy opcionális `onLongPress` mezőt; a tényleges FAB-ot render elő `main_shell.dart`
`GestureDetector`-ba csomagolja, amikor ez nem null — a `FloatingActionButton`-nak nincs saját
`onLongPress`-e, ez az egyetlen mód hozzáadni anélkül, hogy a widgetet villázni kellene. A
Nutrition/Weight tabok (a `shellFabProvider` másik két fogyasztója) `onLongPress: null`-t adnak —
viselkedésük változatlan. A `workouts_screen.dart`-ban csak a Sessions fül (index 0) FAB-ja kap
tényleges hosszú nyomást (a Templates/Exercises fülek FAB-ja mást csinál, hosszú nyomásuk
félrevezető lenne).

**`activity_ranking.dart` első valódi fogyasztója: `quick_start_options_provider.dart`** (új) — a
`recommendedTemplateProvider` mintáját követve két réteg: a C2.6-os tiszta `rankQuickStartEntries()`
változatlan marad, ez a fájl csak **összeköti** a kimenetét a `workoutTemplateControllerProvider`
sablonlistájával (`ResolvedQuickStartEntry = ({entry, template})`), hogy a UI névvel/gyakorlatszámmal
tudja megjeleníteni a sablon-bejegyzéseket. Plusz `isQuickStartColdStartProvider` (< 3 befejezett
session — M02 jegyzete: "amíg nincs elég adat a rangsorhoz (≥3 edzés)").

**`quick_start_sheet.dart`** (új) — a gyorsindító lap (M01/M02): cím + alcím, opcionális
hidegindítás-magyarázó sáv, 2×2 rács a top-4 rangsorolt elemből, "Összes edzéstípus" sor. **Egy
koppintás = fut az edzés** — a kész-ha szó szerint: `startCardioQuickly`/`startStrengthQuickly` a
sáv bezárása **után** azonnal a megfelelő élő képernyőt pusholja, köztes beállító képernyő nélkül.

- **Cardio indítás**: `startCardioSession()` (C2.1, ma először hívva UI-ból — a
  `open_workout_screens.dart` saját kommentje már C2.1 óta ezt a lépést várta: "today only reachable
  from tests, since the quick-start entry point is C2.7"). A navigációhoz szükséges `WorkoutSession`
  objektumot **helyben** építi fel (nem várja meg a repository stream frissülését) — a
  `startCardioSession` implementációja pontosan ismert (`movingSeconds: 0`,
  `movingSinceEpochMs == startedAt`), tehát nincs mit egy stream-lookupra várni, és ez elkerül egy
  verseny-helyzetet. Utána `openSessionScreen(rootNavigator, session)` — a C0.4 óta épülő **egyetlen
  elágazási pont** újrahasznosítva, nem egy saját `CardioSessionScreen`-push.
- **Erősítő indítás**: **tudatosan nem** `openSessionScreen`-en át — annak saját dokstringje
  kifejezetten kizárja a friss sablon-indítást ("Deliberately not used for starting a fresh session
  from a template… that path has nothing to branch on"). Helyette bitre a meglévő
  `TemplatePickerScreen._start` mintája: közvetlen `LogSessionScreen(template: template)` push.
- Mindkét indító függvény **megosztott** a lap csempéi és az `ActivityPickerScreen` sorai között —
  nem duplázott logika, csak más lista-alak hívja ugyanazt.

**`activity_picker_screen.dart`** (új) — az "Összes edzéstípus" célja (M03): CARDIO szekció mind a
hét típussal, ERŐSÍTŐ TERVEK szekció a felhasználó sablonjaival. **Tudatos eltérés a mockuptól**:
nincs keresőmező (a lista amúgy is rövid, 7 + néhány sablon, és a keresés élő szűrése + a két
különböző adattípus együttes szűrése aránytalan pluszmunka lett volna ehhez a lépéshez), és nincs
"Üres edzés" sor az erősítő szekcióban — ez utóbbi **nem hiányosság**, maga az M03 makett sem mutat
ilyet ("aki idáig eljutott, jó eséllyel olyat keres, ami nincs a négy csempén"), és az üres edzés
továbbra is egy koppintásra van a FAB sima érintésén és a meglévő `TemplatePickerScreen`-en át.

**Tudatos egyszerűsítés a csempe-alcímeken**: az M01 makett gyakoriság-szöveget mutat ("Heti 3× ·
kedden"), az M02 hideg állapotban helyszín-jelzést ("Kültéri"/"Beltéri"), az M03 pedig
típusonként eltérő metrika-leírást. Mindhárom helyett **egyetlen, család-alapú** alcím-mechanizmus
(`activityModalitySubtitle`) — DISTANCE/MACHINE/GAME csak három szöveg, nem hét plusz a
gyakoriság-számítás — a heti gyakoriság/nap kiszámítása új logikát igényelt volna a rangsorolón
kívül, a kész-ha pedig ("hosszú nyomás + egy koppintás = fut az edzés") ezt nem követeli meg.

**Váratlan, C2.7-hez nem tartozó, de a munka során felfedezett teszt-környezeti korlát**: a
`LogSessionScreen(template: …)` (friss sablon-indítás) widget-tesztben történő teljes felhúzása
(`pumpAndSettle`) egy `AnimationController`-hibába fut (`elapsedInSeconds >= 0.0` assertion a
`MusicStickyButton` körüli page-transition/ticker interakcióban) — feltehetően azért, mert a
képernyő közvetlenül a valódi `workoutSessionRepositoryProvider`-t olvassa (nem a tesztekben
mockolt controllert), Drift-adatbázis nélkül. **Ez a meglévő `template_picker_screen.dart`-ra is
igaz** (aminek szintén nincs saját tesztje, ugyanezzel a push-mintával) — nem C2.7-regresszió, csak
eddig senki nem próbálta widget-teszttel elérni ezt az utat. A gyorsindító lap tesztjei ezért csak
a csempe-tartalmat és a lap bezárását ellenőrzik erősítő-indításnál, a cardio-utat viszont
végponttól végpontig (a `CardioSessionScreen` ilyen probléma nélkül felhúzható).

**Tesztek:**
- `activity_ranking_test.dart` — a C2.6-os 15 teszt frissítve az M02-korrekcióra (lásd fent),
  továbbra is 15/15 zöld.
- `quick_start_sheet_test.dart` (új, 7 teszt): hidegindítás-sorrend (M02), hidegindítás-banner
  3-as küszöbnél, cardio-csempe koppintása ténylegesen elindítja és a `CardioSessionScreen`-t
  nyitja (a lap eltűnik alóla), erősítő-csempék (üres/sablonos) helyes felirata, "Összes
  edzéstípus" az `ActivityPickerScreen`-t nyitja, egy ottani sor is azonnal indít.
- `activity_picker_screen_test.dart` (új, 5 teszt): mind a hét cardio típus a családfüggő
  alcímmel, az erősítő szekció rejtve sablon nélkül, sablonok gyakorlatszámmal (üres edzés sor
  nélkül), cardio sor indítása, bezárás gomb.

**Eredmény:** `flutter analyze` (teljes projekt) tiszta; a teljes `flutter test` **801/804 zöld**
(789 + 12 nettó új: 7 quick-start-sheet + 5 activity-picker), a 3 bukás a már ismert, cardión
kívüli `chat_repository_test.dart` Windows-fájlzár-flake. Ezzel **C2.1–C2.7 mind kész** — hátra
van C2.8/C2.9 (mindkettő Windowson fejleszthető), majd C2.10/C2.11 (natív kód, részben Mac-et
igényel).

**Következő:** `C2.8` — összegzés-képernyő (útvonal nélküli változat) + RPE + kézi szerkesztés
„szerkesztve” jelöléssel, M15/M14 szerint.

---

## C2.8 kész (2026-08-12) — összegzés-képernyő: szerkeszthető, RPE, „szerkesztve” jelölés

**A legfontosabb szerkezeti döntés: egy képernyő, nem kettő.** A C1.9-es `CardioSummaryScreen`
saját dokstringje már akkor kimondta: "tudatosan **nem** az M15 makett (élő-edzés, szerkeszthető,
teljesítmény-görbés) verziója; **az C2.8 feladata**." Ez azt jelenti, hogy C2.8 célfájlja nem egy
új képernyő, hanem a meglévő `cardio_summary_screen.dart` **felváltása** — ugyanaz a widget
szolgálja ki mindkét elérési utat: a `CardioSessionScreen._finish()` most már `pushReplacement`-tel
egyenesen ide navigál (a korábbi, C2.1 óta ismert "Befejezve" placeholder-t felváltva — ld. C2.1
saját feljegyzése: "az RPE-bevitel, kézi szerkesztés és 'szerkesztve' jelölés a C2.8 táblázat-sorának
a tárgya"), **és** az `open_workout_screens.dart` egy héttel később újranyitott, befejezett cardio
session-re is ugyanide mutat, változatlanul. Egy érték, amit most szerkesztesz, ugyanúgy jelenik meg,
akár most zártad le az edzést, akár három hete csináltad.

**A "szerkesztve" jelölés hatóköre: pontosan a két mező, aminek ma valódi eredet-jelzése van.**
Az [51 R8](51-cardio-overview-plan.md) szó szerint azt mondja, "minden metrikának van `source`
jelzése" — de a mai séma (C1.5/C1.8/C2.2/C2.3) ezt ténylegesen csak két mezőre építette ki:
`distanceSource` és `caloriesSource`. Elevation/kadencia/watt/ellenállás/GAME-mezők nem kapnak
`source` oszlopot, mert **semmilyen automatikus forrásuk sincs ma** (nincs GPS, nincs BLE-s
edzőgép-párosítás, [53 §4.2](53-cardio-mobile-plan.md) "Extra vezérlő" oszlopa is csak jövőbeli
munkaként említi őket) — egy teljes séma-bővítés minden mezőre olyan munka lenne, aminek ma nincs
kifizetődése (nincs mihez képest "szerkesztettnek" jelölni egy elevation-t, amíg nincs GPS-becslés).
C2.8 ezért a **mintát** építi meg (koppintás-szerkeszt-jelölés) a két mezőn, ahol ma valóban létezik
az eredet-fogalom, a többit érintetlenül, olvashatóan hordozza tovább.

**Tudatos eltérés a mockup Mentés-gombjától: mezőnkénti autosave, nem egy közös "Mentés".** Az M14
alján egy "Mentés" gomb van; ehelyett ez a lépés a `CardioSessionScreen` már bevett mintáját
folytatja (koppintás → dialógus → azonnali perzisztálás) — az RPE-koppintás és a jegyzet-mező
fókuszvesztése is azonnal ír. Ez elkerüli egy "mentetlen módosítás" állapot bevezetését, amire
másképp semmi szükség nem lenne.

**Kód-újrahasznosítás, nem duplikálás.** A `_promptNumber` (C2.2-ben a `CardioSessionScreen`
privát metódusa) kiemelve egy közös `widgets/prompt_number_dialog.dart`-ba (`promptNumber(context,
l10n, {title, suffix, initialText})`) — mindkét képernyő ugyanazt hívja, most már tényleg egy
helyen. Az RPE-szekció az `RpeSelector` + a `postWorkoutFeedbackTitle`/`Anchor*`/`NoteHint`
ARB-kulcsokat használja, amiket a `LogCardioSheet` (C1.9) már bevezetett — nulla új string ehhez.
A `rateSession()`/`updateLiveCardioMetrics()` controller-metódusok is már léteztek (C1.x/C2.2) —
ehhez a lépéshez **egyetlen új controller-metódus sem kellett**.

**Amit a képernyő tudatosan nem tartalmaz**: útvonal, split-lista, pulzuszóna-sáv (mind C4a/C5
GPS/óra-adatot igényel, ami ma nem létezik — "GPS nélkül nincs útvonal, sehol"), és a MACHINE
teljesítmény-görbe (idősoros watt-mintavétel, amit az app ma nem rögzít). Ezek nem hiányosságok,
hanem a doc saját "útvonal nélküli változat" megnevezésének szó szerinti követése.

**`cardio_session_screen.dart` mellékhatásai**: a `_finish()` most már a helyi állapotból
(`_distanceMeters`/`_avgCadence`/`_avgWatts`/`_resistanceLevel`) építi fel a záró `WorkoutSession`-t
— ez pontosan az, amit a `_updateCardioMetrics` a háttérben már perzisztált, tehát nincs
stream-lekérdezési verseny. A build()-ből eltűnt az `_isFinished`-ág ("Befejezve" felirat + a
vezérlők elrejtése) — az invariáns szerint (`open_workout_screens.dart` az egyetlen valódi belépési
pont) ez a képernyő **mindig** egy folyamatban lévő session-nel példányosul, tehát ez az ág a
gyakorlatban sosem futott volna le; az orphánná vált `cardioSessionFinishedLabel` ARB-kulcs törölve
(ugyanaz az audit-fegyelem, mint C2.5-ben).

**Tesztek:**
- `cardio_summary_screen_test.dart` — a C1.9-es 6 olvasási teszt megtartva (egy MACHINE-fixture
  ellenállás-értéke 6→14-re módosítva, hogy ne ütközzön az RPE 1-10 chip-feliratokkal), plusz 9 új:
  "szerkesztve" jelölés egy már manuális `distanceSource`-ú session-ön; RPE-chip koppintás azonnal
  ír; jegyzet csak fókuszvesztéskor ír, **és csak, ha már van értékelés** (a `rateSession` `rpe`
  paramétere nem nullable); táv-szerkesztés perzisztál és jelöl, **más MACHINE-mezőt nem töröl**
  (regressziós teszt, ugyanaz a minta, mint a C2.3-as `_updateCardioMetrics`-tesztnél); gép-kalória
  szerkesztése ugyanígy; sikertelen írás nem változtatja a látható értéket.
- `cardio_session_screen_test.dart` — a C2.5-ös két befejezés-teszt ("Finished" szöveg helyett)
  most `find.byType(CardioSummaryScreen)`-t ellenőriz, és hogy a `CardioSessionScreen` már nincs a
  fában.

**Eredmény:** `flutter analyze` (teljes projekt) tiszta; a teljes `flutter test` **809/812 zöld**
(801 + 8 nettó új), a 3 bukás a már ismert, cardión kívüli `chat_repository_test.dart`
Windows-fájlzár-flake.

**Következő:** `C2.9` — `WorkoutSessionState` `kind`+`cardio` bővítés (előformázott stringek,
epoch-alapú idő) a Live Activity / ongoing notification hídhoz.

---

## C2.9 kész (2026-08-12) — `WorkoutSessionState` cardio-bővítés + a híd bekötése

**A kész-ha ("régi natív build a STRENGTH ágra esik vissza, nem törik") két külön dolgot kényszerít
ki, nem egyet.** Először: a `kind` mezőnek **alapértéke** van (`'STRENGTH'`), pontosan úgy, ahogy a
domain-modell `WorkoutSession.sessionKind`-ja is teszi — így a `LogSessionScreen` és mind a ~15
meglévő teszt-konstrukció ebben és a `watch_workout_service_test.dart`-ban **változtatás nélkül**
továbbra is azt jelenti, amit eddig, `kind: 'STRENGTH'`-ként. Másodszor, és ez a finomabb rész: egy
régi build, ami a `kind`-ot **egyáltalán nem ismeri**, kizárólag a meglévő mezőket
(`exerciseName`, `setsDone`, `setsTotal`) olvassa — tehát a "nem törik" nem attól igaz, hogy a
natív oldal helyesen ágazik el (azt csak C2.10a/C2.10b építi meg), hanem attól, hogy a
`CardioSessionScreen` **tudatosan** ezekbe a régi mezőkbe is értelmes cardio-tartalmat ír:
`exerciseName: "Futás — 5,24 km"` (típus + domináns metrika), `setsTotal: null` (nem `0`) — ez
utóbbi már ma, C2.10a natív munkája nélkül is elkerüli a "0 szett" csúnya megjelenést a
meglévő, változatlan Android-renderelőn, mert a `_renderAndroidNotification` már ma is csak akkor
fűzi hozzá az "N/total" törtet, ha `setsTotal` nem null.

**`CardioLiveMetrics`, három szint, szó szerint a doc saját megfogalmazása szerint.** Az 53-as doc
D-C2.3 kódrészlete ezt írja: "`CardioLiveMetrics? cardio; // primary/secondary/tertiary metrika,
előre formázva`" — ez a lépés pontosan ezt a három szintet építette meg (`primaryLabel/Value`,
`secondaryLabel/Value`, `tertiaryLabel/Value`), amit az M23/M24 (iOS Live Activity, C2.10b) és M25
(Android, C2.10a) mockupok is következetesen mutatnak: DISTANCE → táv/mozgásidő/tempó; MACHINE →
mozgásidő/kadencia/watt; GAME → játékidő/bruttó idő/pulzus. A `CardioSessionScreenState`-ben új
`_cardioLiveMetrics()` ezt a hármat származtatja, **ugyanazokból a helyi mezőkből**
(`_distanceMeters` stb.), amiket a családfüggő `_distanceBody`/`_machineBody`/`_gameBody` már ma is
megjelenít — nem megosztott adatobjektumból, mert ilyen ma nincs a widget-fa és a payload között
(ugyanaz a "kis duplikáció elfogadható" döntés, mint a `_finish()` záró `CardioMetrics`-énél).

**Az epoch-alapú idő, a doc kifejezett kérése.** "Egyetlen kivétel: az idő továbbra is
epoch-alapú... hogy a natív felület magától ketyegjen, frissítés-kvóta nélkül" — a
`CardioLiveMetrics` ezért nem egy statikus "mozgásidő" stringet visz, hanem a C2.1 óta bevett
`movingSecondsBase`/`movingSinceEpochMs` checkpoint-párt (a szünetnél `null` az utóbbi) —
ugyanaz a minta, mint a meglévő `restEndsAtEpochMs`, amit a natív oldal már ma is önállóan tud
ketyegtetni. Ez a C2.10a/C2.10b natív munkájának lesz az alapja, ezt a lépést önmagában nem
igényli semmi (a Windows-tesztek csak a JSON-alak helyességét ellenőrzik).

**A híd tényleges bekötése `CardioSessionScreen`-be** — enélkül a kész-ha üres állítás maradt
volna ("egy régi build nem törik", de sosem kap semmit, amin törhetne). A `LogSessionScreen`
pontosan ugyanazt a három-zászlós mintát követi (`_startingSessionNotifier`/
`_sessionNotifierStarted`/`_sessionNotifierUnavailable`), **watch-mirror hívás nélkül** — az C5
dolga, nem C2.9-é ([55 D-C5.1](55-cardio-watch-plan.md): a telefon-oldali cardio-feldolgozó előbb
kell elkészüljön, mint bármi, ami payloadot küldene neki). `start()` a képernyő `initState`-jéből,
egy postFrame-callback mögé rejtve (ugyanaz az ok, mint `LogSessionScreen`-nél: `AppLocalizations.of`
nem biztonságos `initState` közben); `update()` minden állapotváltó műveletnél
(`pause`/`resume`/`_setOnCourt` mindkét ága/`_updateCardioMetrics`); `end()` a `_finish()`-ben, a
navigáció előtt, `unawaited`-ként, hogy ne késleltesse az összegzésre lépést.

**Tesztek:**
- `workout_session_notifier_service_test.dart` — a meglévő ~10 pontos map-egyezőségi teszt
  frissítve a három új kulccsal (`kind: 'STRENGTH', activityType: null, cardio: null` a
  STRENGTH-fixture-öknél); 4 új teszt: `kind` alapértéke, egy teljes CARDIO `toJson()`-alak,
  szüneteltetett `CardioLiveMetrics` `movingSinceEpochMs`-e null, és egy valódi CARDIO `start()`
  hívás az iOS csatornán.
- `watch_workout_service_test.dart` — ugyanaz a map-frissítés két helyen (ez a fájl is
  `WorkoutSessionState.toJson()`-t szerializál, a `LogSessionScreen` watch-mirror hívásán
  keresztül — a teljes tesztkészlet futtatása fogta ezt el, nem előre látott érintettség).
- `cardio_session_screen_test.dart` (új csoport, 5 teszt, egy második `_pumpWithNotifier`
  segédfüggvénnyel és egy `_RecordingNotifierService` fake-kel, ami felülírja
  `start`/`update`/`end`-et): indításkor `kind: 'CARDIO'` + a "0 szett" nélküli fallback-mezők;
  szünet → `update(paused: true)`; folytatás → `update(paused: false)`; táv-szerkesztés →
  frissített `primaryValue`; befejezés → `end()`.

**Eredmény:** `flutter analyze` (teljes projekt) tiszta; a teljes `flutter test` **818/821 zöld**
(809 + 9 nettó új), a 3 bukás a már ismert, cardión kívüli `chat_repository_test.dart`
Windows-fájlzár-flake. Ezzel a **C2 iteráció mind a 9 Windowson fejleszthető lépése (C2.1–C2.9)
kész** — hátra van C2.10a (Android natív layout, Windowson fejleszthető), C2.10b (iOS Live
Activity, Mac kell) és C2.11a/b (deep-link + app-shortcut + kezdőképernyő-widget).

**Következő:** `C2.10a` — Android tartós értesítés cardio-layout (M25) — ezt a Dart-oldali
`_renderAndroidNotification`-t bővíti `kind == 'CARDIO'`-ágra, natív Kotlin-kód nélkül.

---

## C2.10a kész (2026-08-12) — Android tartós értesítés cardio-layout

**Tisztán Dart-oldali, ahogy a kész-ha ígérte** — nincs Kotlin-változás, mert
`flutter_local_notifications` már ma is támogatja mindazt, amire szükség volt
(`usesChronometer` kapcsolható); csak eddig senki nem tette elérhetővé hívóoldalról.

**`_renderAndroidNotification` `kind == 'CARDIO'`-ága, a C2.9-ben pontosan erre épített
`movingSecondsBase`/`movingSinceEpochMs` checkpoint-párra támaszkodva:**

- **A body a `CardioLiveMetrics` primary/secondary/tertiary értékeiből épül**
  (`" · "`-tal fűzve), a `'—'` helykitöltők kihagyásával — ugyanaz a szemlélet, mint a
  "nincs 0 szett": egy meg nem mért érték (pl. a GAME pulzusa ma) inkább hiányzik, mint
  hogy csúnyán látsszon.
- **A chronometer natívan ketyeg, JS-oldali percenkénti/másodperces frissítés nélkül**: a
  `when` epochot a `movingSinceEpochMs - movingSecondsBase*1000` képlet adja — ez az a
  trükk, ami miatt a C2.9 kész-ha megjegyzése kifejezetten ezt a párost nevezte meg
  "ennek lesz az alapja" — Android saját "now - when" chronometere így egyetlen
  epoch-eltolással jeleníti meg helyesen a bázis + élő-telt időt, anélkül hogy a Dart
  oldal minden másodpercben újraküldene egy stringet.
- **Szünetben a chronometer kikapcsol** (`usesChronometer: false`), nem csak befagy —
  Android saját maga számolja a chronometert a rendszeróra alapján, ezt Dartból nem lehet
  "megállítani" anélkül, hogy ki ne kapcsolnánk; enélkül a szünetelt idő alatt is
  tovább nőtt volna a kijelzett szám, pont azt hazudva, amit ez a lépés ki akart javítani.
  Ez az egyetlen hely, ahol `NotificationService.showWorkoutSession` és
  `WorkoutSessionNotifierService`'s injectable `_showAndroidNotificationCall` típusa
  bővült egy `usesChronometer` paraméterrel (alapértéke `true`, tehát a STRENGTH-ág
  viselkedése változatlan).

**"frissítés csak változásra"** — a kész-ha másik fele, és nem cardio-specifikus: egy
`_lastAndroidRender` rekord (`title, body, subText, whenEpochMs, chronometerCountDown,
usesChronometer`) gyorsítótárazza az utoljára ténylegesen kiküldött tartalmat, és
`_renderAndroidNotification` kilép, mielőtt meghívná a natív réteget, ha semmi nem
változott. `start()`/`end()`/`endAll()` nullázza — enélkül egy új munkamenet, aminek a
tartalma véletlenül egyezik az előző munkamenet utolsó állapotával, néma maradna.

**Tesztek** (`workout_session_notifier_service_test.dart`, 8 új): a meglévő ~10 fake
closure mind kapott egy `usesChronometer = true` paramétert (a régi szignatúra már nem
illeszkedett az új konstruktor-típusra); új tesztek: cardio body összefűzése és a `'—'`
kiszűrése, futó cardio chronometer-epochja, szünetelt cardio `usesChronometer: false`-ja
+ statikus body-ja, két azonos `update()` csak egyszer renderel, egy változás a
duplikátumsorozat után újra renderel, és egy új munkamenet azonos tartalommal mégis
renderel (a cross-session reset ellenőrzése).

**Eredmény:** `flutter analyze` (teljes projekt) tiszta; a teljes `flutter test`
**827/830 zöld** (818 + 9 nettó új — 8 új teszt, 1 régi net bővült paraméterlistával, nem
számít újnak), a 3 bukás a már ismert, cardión kívüli `chat_repository_test.dart`
Windows-fájlzár-flake. Ezzel a **C2 iteráció 10 Windowson fejleszthető lépéséből
(C2.1–C2.10a) mind kész** — hátra van C2.10b (iOS Live Activity, Mac kell) és
C2.11a/b (deep-link + app-shortcut + kezdőképernyő-widget, C2.11a Windowson,
C2.11b Mac-en).

**Következő:** `C2.11a` — deep-link route (`go_router`) + Android dinamikus
app-shortcutok + Android kezdőképernyő-widget gombok (M29) — Windowson fejleszthető, a
másik útja `C2.10b`-nek (Mac kell hozzá).

---

## C2.11a kész (2026-08-12) — Deep-link route + Android dinamikus app-shortcutok + widget gombok

**Három rész, egy közös alapon.** A [`53 §3.4`](53-cardio-mobile-plan.md) D-C.8 által előre
megnevezett három fogyasztó (gyorsindító lap, shortcut-frissítő, watch-payload) közül ez a lépés
a másodikat építette meg — és egy negyediket is (widget), amit a doc ugyanoda sorolt. Egyik sem
duplikálja a rangsorolást: mind `rankQuickStartEntries`-ből (C2.6) és a már meglévő
`quickStartEntriesProvider`-ből (C2.7) dolgozik.

**A deep-link, mert ez a másik kettő közös alapja.** `quickStartDeepLinkUri`/
`quickStartEntryFromDeepLinkUri` ([activity_ranking.dart](../../mobile/lib/features/workouts/application/activity_ranking.dart))
egy `QuickStartEntry`-t old fel `lifey://workout/start?activity=CODE[&template=clientId]`
URI-vá és vissza — `'STRENGTH'` itt tisztán URI-szintű sentinel (nem valódi
`kActivityTypes`-érték), hogy egyetlen `activity` paraméter válasszon a cardio/erősítő ág között.
`app_router.dart` meglévő `onException`-ága (ami eddig csak a `lifey://workout` bare linket
kezelte — újra megnyitja a futó edzést) bővült: ha az URI egy felismert `start` linket hordoz,
`workout_resume_prompt.dart` új `startQuickStartEntryFromDeepLink`-je indítja el — **de csak ha
nincs már futó edzés**, különben ugyanúgy azt nyitja meg újra, mint a bare link (a shortcutra/widget
gombra edzés közben kattintás nem hoz létre árva második session-t).

**A tényleges indítás nem a C2.7 sheet-függvényeit hívja.** `startCardioQuickly`/
`startStrengthQuickly` ([quick_start_sheet.dart](../../mobile/lib/features/workouts/presentation/quick_start_sheet.dart))
egy `BuildContext`-et és egy popolható bottom sheet-et tételeznek fel — egy hidegindítású
shortcut-tapnak egyik sincs. A cardio ág adatlétrehozó fele kivált egy önálló
`createCardioSession`-be (navigáció nélkül), amit mindkét hívó (a sheet csempéje és az új
deep-link belépési pont) megoszt; az erősítő ág a sablon feloldása után közvetlenül
`LogSessionScreen`-t push-ol, ugyanúgy mint eddig, csak sheet-pop nélkül.

**A `quickStartEntryTitle` átköltözött** a presentation-rétegből (`quick_start_sheet.dart`) az
application-rétegbe (`quick_start_options_provider.dart`) — a shortcut/widget-frissítőnek
(core-réteg) kellett ugyanaz a cím-feloldás, amit a sheet csempéje mutat, és a core-réteg nem
importálhat egy widget-fájlt anélkül, hogy a rétegződést (`CLAUDE.md` "feature-based packaging")
megsértené.

**Android natív oldal, mindkettő ugyanazt a mintát követi, mint a `workout_session_notifier`/
`WatchBridge`/`MediaSessionBridge`** — plain `MethodChannel`-osztály, nem Flutter-plugin
(D-C2.2):

- **`lifey/shortcuts`** ([ShortcutsBridge.kt](../../mobile/android/app/src/main/kotlin/com/khunor/lifey/ShortcutsBridge.kt)) —
  `ShortcutManager.setDynamicShortcuts`, API 25 alatt csendes no-op. Minden shortcut ugyanazt az
  app-ikont kapja (nincs aktivitás-típusonkénti drawable-készlet — ez a másodlagos belépési pontért
  nem éri meg 8 vektor-ikont karbantartani), a cím és a deep-link különbözteti őket. Az `Intent`
  explicit `MainActivity`-re célzott (`ACTION_VIEW` + `Uri` + komponens), nem implicit — nincs
  esély chooser-dialógusra, és Flutter deep-link-kezelése az `Intent.data`-t olvassa,
  a felbontás módjától függetlenül.
- **Widget-gombsor** ([TodaySummaryWidgetProvider.kt](../../mobile/android/app/src/main/kotlin/com/khunor/lifey/TodaySummaryWidgetProvider.kt),
  [widget_today_summary.xml](../../mobile/android/app/src/main/res/layout/widget_today_summary.xml)) —
  két fix csempe-slot (a `WidgetSnapshotWriter` már top-2-re vágja a listát, ez csak a másik oldali
  biztosíték), mindegyik saját `PendingIntent`-tel (`FLAG_UPDATE_CURRENT`, egyedi request-code
  slotonként, hogy Android ne cache-elje össze a két különböző célt). Csak szöveges címke, nincs
  ikon a csempéken — ugyanaz az egyszerűsítés, mint a shortcutoknál.
- **`AndroidManifest.xml`**: `lifey://` scheme intent-filter (`VIEW`/`DEFAULT`/`BROWSABLE`) +
  `flutter_deeplinking_enabled` meta-data — eddig **egyáltalán nem volt** regisztrálva Androidon
  (csak iOS Info.plist-jében), az ongoing-notification tap ugyanis eddig natív plugin-callbacket
  használt, nem URI-t (docs/25-android-widget-ongoing-notification-plan.md mintája) — ezúttal
  viszont a doc kifejezetten `go_router`-be parse-olandó URI-t kért (D-C2.2), hogy a route
  C2.11b-nek (iOS) is kész célpont legyen.

**A frissítési ütem, dokumentált D-döntés szerint** ("app háttérbe kerülésekor, nem minden
képernyőnyitáskor", [53 §3.2](53-cardio-mobile-plan.md)): a meglévő `WidgetSnapshotController`
(eddig csak a kalória/lépés-számláló debounced írója) kapott egy `_refreshQuickStart()`-ot, amit
**csak** a konstruktor és `didChangeAppLifecycleState(paused)` hív — szándékosan **nem**
figyeli `quickStartEntriesProvider`-t közvetlenül, mert az minden edzés-befejezésen (tehát a
dashboard-számlálót is mozgató minden szett-logoláson) újraszámolna, ami pont az a "minden
build-ben" viselkedés, amit a doc kizár. A közte lévő debounced írásokhoz a legutóbb
kiszámolt lista cache-elve marad (`_quickStart` mező).

**Amit ez a lépés szándékosan leegyszerűsített a design canvashoz képest** (M29 mockup: 4 csempés
"Gyors indítás" widget + kétállapotú kis widget élő számlálóval): az 53-as doc §3.3 tényleges
szövege csak "gyorsindítás gombsort a top-2 edzéssel" ígér, ugyanarra a deep-linkre — ez a lépés
pontosan ezt építette, nem a mockup teljes vizuális gazdagságát (nincs élő/futó állapot a
widgetben, nincs 4-csempés elrendezés) — ugyanaz a fegyelem, mint C2.10a-nál a mockup 3.
metrika-sorával szemben.

**Tesztek:** `activity_ranking_test.dart` (+7, URI oda-vissza + hibás/idegen URI elutasítása),
`app_shortcuts_service_test.dart` (új fájl, 4 teszt: unavailable no-op, JSON-alak, üres lista
ténylegesen törli — nem skip-eli —, hiányzó natív handler nyelése),
`widget_snapshot_writer_test.dart` (+1, top-2 vágás + címke/deep-link helyesség). A router/
resume-prompt új ága (`startQuickStartEntryFromDeepLink`) nem kapott dedikált widget-tesztet —
navigátor-/BuildContext-függő integrációs felszín, amit ez a kódbázis eddig sem tesztelt
közvetlenül (lásd `openActiveWorkoutSession` sem).

**Natív build-ellenőrzés:** mivel ez a lépés Kotlin-t és AndroidManifest-et is módosít, amit
`flutter analyze`/`flutter test` nem fordít le, egy teljes `flutter build apk --debug` futott
ellenőrzésként — sikeresen lefordult (`ShortcutsBridge.kt`, a bővített
`TodaySummaryWidgetProvider.kt`, az új XML/drawable erőforrások, a manifest-bővítés).

**Eredmény:** `flutter analyze` (teljes projekt) tiszta; `flutter build apk --debug` sikeres; a
teljes `flutter test` **839/842 zöld** (827 + 12 nettó új: 7 URI-teszt, 4 shortcuts-teszt, 1
widget-snapshot-teszt), a 3 bukás a már ismert, cardión kívüli `chat_repository_test.dart`
Windows-fájlzár-flake.

**Következő:** `C2.10b` (iOS Live Activity + Dynamic Island, Mac kell) vagy `C2.11b` (iOS
dinamikus app-shortcutok + kezdőképernyő-widget gombok, szintén Mac kell) — a C2 iteráció
mind a 11 Windowson fejleszthető lépése (C2.1–C2.11a) kész.

---

## C2.10b kész (2026-08-12) — iOS Live Activity + Dynamic Island cardio-layout

**A meglévő STRENGTH-implementáció (`WorkoutActivityAttributes.swift`, `LiveActivityChannel.swift`,
`WorkoutLiveActivity.swift`, mind Windowson már megírva a 24-es doc Phase 2 részeként, de eddig
sosem fordítva/futtatva) kapott egy cardio-ágat — natív kód nélkül nem volt mit tesztelni ezekből
a fájlokból, ez volt az első alkalom, hogy ez a három fájl ténylegesen lefordult.**

**`ContentState` bővítés** (`ios/Shared/WorkoutActivityAttributes.swift`): a C2.9-ben lefektetett
Dart `WorkoutSessionState`/`CardioLiveMetrics` szerződés szó szerinti Swift-tükre — `kind`,
`activityType`, `cardio: CardioLiveMetricsState?` (új, top-level struct, a Dart `CardioLiveMetrics`
mind a nyolc mezőjével). A `kind` alapértéke **nem** ide került (ahogy a Dart oldalon), hanem a
dict-parszolásba — indoklás a fájl saját megjegyzésében: ActivityKit mindig egy *teljes*
`ContentState`-et kódol/dekódol vissza, sosem részlegeset, tehát a struct saját Codable-jének
nincs "hiányzó kulcs" esete, amit alapértékkel kellene kezelnie.

**`LiveActivityChannel.swift`**: a `contentState(from:)` dict-parszoló kapott egy `kind`/`activityType`
olvasást (ugyanaz az `?? "STRENGTH"` alapérték, mint a Dart oldalon) és egy új
`cardioLiveMetrics(from:)` segédfüggvényt a beágyazott `"cardio"` dict-hez — `nil`-t ad vissza
STRENGTH-frissítésnél (nincs `"cardio"` kulcs) és hibás blokknál egyaránt, ami mindkét esetben a
STRENGTH-renderelő ágra tereli a natív UI-t.

**`WorkoutLiveActivity.swift` — a tényleges UI, M23/M24 szerint:**

- **Fejléc** (`CardioHeaderView`, lock screen; `CardioIslandLeading`, sziget): ikon (SF Symbol
  `activity_type.dart` kódonként — `figure.run`/`figure.walk`/`figure.hiking`/`bicycle`/
  `basketball.fill`/`soccerball`/`bolt.fill`, sosem lokalizált szöveg, csak kódra kapcsolt ikon) +
  `attributes.title` (már lokalizált, a Dart oldal adja át indításkor — nem kellett új
  aktivitás-címke logika) + a **mozgásidő natívan ketyegő megjelenítése**
  (`CardioMovingTimeView`).
- **A ketyegés maga, a doc kifejezett kérése szerint** ("hogy a natív felület magától ketyegjen,
  frissítés-kvóta nélkül"): `CardioMovingTimeView` a C2.9-ben pontosan erre épített
  `movingSecondsBase`/`movingSinceEpochMs` checkpoint-párt shifteli el (`since − base·1000`) egy
  `Text(timerInterval:)`-be — ugyanaz a "when = since − base" trükk, mint a C2.10a Android
  chronometeréé. Szünetben (`movingSinceEpochMs == nil`) statikus, Swift-re portolt
  `CardioFormatter.duration`-szöveget mutat, nem próbál tovább ketyegni.
- **Metrika-sor** (`CardioMetricsRow`, lock screen): a primary label/value nagy méretben balra
  (a Dart `CardioLiveMetrics.primaryValue` már előformázott string, family-függően táv/mozgásidő/
  játékidő — lásd `CardioSessionScreen._cardioLiveMetrics`), a secondary/tertiary két kisebb
  statpár jobbra (`CardioStatPair`). Egy `"—"` placeholder-értékű slot (pl. GAME pulzusa ma) **nem
  jelenik meg** — ugyanaz a "hiányzik, nem csúnya" döntés, mint a C2.10a Android body-szűrőjénél.
- **Szünet-vizuál**: a primary érték és a fejléc-ketyegő elhalványul (`opacity`), a fejlécen egy
  `pause.circle.fill` SF Symbol jelenik meg — nincs lokalizált "Szüneteltetve" felirat, mert a
  payload nem visz ilyen stringet (a 24-es doc döntés #6-a szerint az extension sosem fordít, csak
  előformázott stringet renderel; egy ikon nem sérti ezt).
- **Dynamic Island**: **egy** `DynamicIsland` érték, nem kettő — a STRENGTH/CARDIO elágazás minden
  region/compact/minimal `@ViewBuilder` closure-jén *belül* van (`if let cardio { … } else { … }`),
  mert a `DynamicIsland<Leading, Trailing, Bottom, CompactLeading, CompactTrailing, Minimal>`
  generikus típusa rögzül a widget-konfigurációban, és két különböző konkrét `DynamicIsland`-példány
  visszaadása két branch-ből típushibát adott volna (ez volt az első build-hiba, ld. lentebb).
  Kompakt: ikon + `primaryValue`; kibontott: fejléc-mintázat balra, primary+secondary jobbra,
  tertiary lent (ha nem `"—"`); minimál: csak ikon.

**Két valódi build-hiba derült ki, mindkettő javítva, csak a natív Mac-fordítás fedte fel őket
(pontosan ezért Mac-lépés ez, nem Windowson írt-és-sose-fordított kód, mint az előző Phase 2
Swift-fájlok voltak):**

1. **`missing return in closure expected to return 'DynamicIsland'`** — a `dynamicIsland:` closure
   nem `@ViewBuilder`, tehát a `let cardio = …` segédváltozó bevezetése után a `DynamicIsland { … }`
   már nem implicit visszatérési érték volt (a closure-nek pontosan egy kifejezésből kell állnia
   ehhez). Javítás: explicit `return DynamicIsland { … }.widgetURL(...)`.
2. **Ezen a gépen a helyi Drift-kódgenerálás elavult volt** a `mobile/lib/core/local_db/tables/
   workout_session_tables.dart`-hoz képest (`app_database.g.dart` `.gitignore`-olt, tehát
   gépenkénti) — a `Runner` cél Flutter-build script fázisa emiatt bukott
   (`movingSinceEpochMs` hiányzó paraméter a generált `WorkoutSessionsCompanion`-ön). Nem a
   cardio-munka hibája, hanem első Mac-fordítás előtti hiányzó `dart run build_runner build`;
   lefuttatva megoldódott, semmilyen forráskód nem változott emiatt.

**Build-ellenőrzés** (natív kód, `flutter test`/`flutter analyze` nem fordítja le):
`xcodebuild -workspace Runner.xcworkspace -scheme LifeyWidgets -sdk iphonesimulator build` —
**BUILD SUCCEEDED** a fenti két hiba javítása után, a teljes `Runner` host-app-ot is felépítve (a
`LifeyWidgets` séma függősége). `flutter analyze` a teljes projektre tiszta.

**Amit ez a lépés szándékosan nem tett meg:** eszközön/szimulátoron futtatott vizuális
végpróbát (lock screen + Dynamic Island tényleges megjelenítése egy futó cardio session-nel) — a
felhasználó kérésére ez most kimaradt, saját eszközén nézi meg. A 24-es doc "Phase 2 checklist"
5–6. pontja (build 16.2+ szimulátoron, manuális QA-lista) ezért **továbbra is nyitott**, ahogy már
a Phase 2 STRENGTH-munkánál is nyitva maradt target-membership-ellenőrzésként — most már legalább
a build maga bizonyítottan zöld.

**Következő:** `C2.11b` — iOS dinamikus app-shortcutok (`UIApplicationShortcutItem`, natív híd) +
iOS kezdőképernyő-widget gombok (M29, Mac kell) — ezzel zárulna a teljes C2 iteráció mind a 13

---

## C2.11b kész (2026-08-12) — iOS dinamikus app-shortcutok + kezdőképernyő-widget gombok

**Ugyanaz a szerződés, a C2.11a Android-oldalán már bevált mintát követve**: a Dart oldal
(`AppShortcutsService`, `WidgetSnapshotWriter`) platform-semleges volt már C2.11a óta — ez a lépés
kizárólag a natív iOS felet és egy egysoros Dart-bővítést adott hozzá.

**`ShortcutsChannel.swift`** (új, `ios/Runner/`) — a `lifey/shortcuts` csatorna iOS fele,
`ShortcutsBridge.kt` szó szerinti Swift-tükre: `"update"` metódus, `{id, shortLabel,
deepLinkUri}` lista → `UIApplication.shared.shortcutItems`. Egy eltérés az Androidtól:
`UIApplicationShortcutIcon.IconType`-nak nincs "generic" esete (csak fix szemantikus
glyph-készlet — compose, play, add, …), egyik sem illett volna jobban egy tetszőleges
`kActivityTypes`-bejegyzéshez, mint a semmi, tehát `icon: nil` (csak felirat) — ugyanaz a "nem
éri meg típusonkénti ikont karbantartani" döntés, mint a Kotlin oldalon, csak a nulla ikon lett a
konkrét megvalósítása, nem a launcher-ikon (ami Swiftben nem ugyanúgy elérhető, mint
`R.mipmap.ic_launcher` Kotlinban).

**`AppDelegate.swift`** — a csatorna regisztrálása a meglévő `registrar(forPlugin:)` mintával,
plusz **két hívási pont**, a shortcut-koppintást ugyanoda irányítva, ahová egy `lifey://`
Safari-link vagy a Live Activity koppintása is megy:

- `application(_:performActionFor:completionHandler:)` — meleg indítás (az app már fut).
- `didFinishLaunchingWithOptions`, `launchOptions[.shortcutItem]` — **hideg** indítás, mert Apple
  dokumentáltan **nem** hívja meg a fenti metódust egy nem futó appra, hanem a launchOptions-ban
  adja át. A hívás **a `super.application(...)` UTÁN** történik — az állítja fel a Flutter
  motort/binary messengert, amibe a deep link forward-olódik; ugyanaz a sorrend-függés, mint
  ahogy iOS maga is kezeli egy hideg indítású Safari-linket.
- Mindkettő egy közös `openDeepLink(from:)`-ba fut, ami a shortcut `userInfo["deepLinkUri"]`-jét
  URL-lé alakítva **közvetlenül meghívja az örökölt `application(_:open:options:)`-öt** — azt a
  metódust, amit a `FlutterAppDelegate` már ma is használ egy sima `lifey://` linkhez. Emiatt a
  go_router C2.11a-ban épített `onException` deep-link-kezelése **iOS-specifikus ág nélkül**
  kiszolgálja a shortcutot is.

**Kezdőképernyő-widget gombok** (`TodaySummaryWidget.swift`) — a `TodaySnapshot` kapott egy
`quickStart: [QuickStartWidgetEntry]?` mezőt (a `WidgetSnapshotWriter` már C2.11a óta írja ezt a
kulcsot, csak a Swift-oldali dekódolás hagyta figyelmen kívül eddig — `Codable` szótlanul eldobja
az ismeretlen kulcsot, tehát ez nem volt hiba, csak kihasználatlan adat). Opcionális, nem mert az
író valaha kihagyná (mindig legalább üres tömböt küld), hanem mert egy **C2.11a előtti** app-verzió
által írt, még App Group-ban lévő snapshot-nak nincs ilyen kulcsa, és egy hiányzó kötelező mező
az egész dekódolást elbuktatná.

Az új `QuickStartRow` (max 2 `Link`, deep-linkkel) **csak a közepes widgetben** jelenik meg — a
kicsi widget 155pt-es négyzete már megtelt a kalória-gyűrűvel + lépés-sorral, és az 53-as doc
§3.3-a is csak "gombsort a top-2 edzéssel" ígért, nem méretenkénti változatot; ugyanaz az
egyszerűsítés, mint amit a C2.11a Androidon is választott (egyetlen fix elrendezés, nem
méretenkénti). Technikailag ez a **pre-iOS-17 többcélpontos widget minta**: a `Link`-ek saját URL-je
felülírja a teljes widgetre beállított `.widgetURL(lifey://today)`-t a saját koppintási
területükön — nincs App Intents/interaktivitás, ami a 24-es doc scope-ján kívül esne.

**Két build-akadály, mindkettő Xcode-projekt-szintű, nem kódhiba:**

1. **Az új `ShortcutsChannel.swift` fájl nem volt hozzáadva a Runner cél tagságához** — ez a
   fájlrendszerre írt, de Xcode-on kívül létrehozott Swift-fájlok ismert csapdája (lásd a 24-es
   doc Phase 0/2 checklist-jei ugyanerre). Mivel ez a session Xcode-dal/Ruby `xcodeproj` gem-mel
   rendelkező Mac-en fut, **szkriptelve** oldottam meg (nem manuálisan Xcode-ban): a fájl
   hozzáadva a `Runner` csoporthoz és a `Runner` target `Sources` build-fázisához. A
   `project.pbxproj` diffje ezen kívül csak a gem ábécérendbe rendezését tartalmazza, funkcionális
   változás nélkül.
2. **`UIApplicationShortcutIcon.IconType` nem ismeri a `.generic` esetet** — fordítási hiba,
   javítva `icon: nil`-re (ld. fent).

**Dart-oldali egysoros bővítés, amit a saját korábbi doc-megjegyzése előre bejelentett**:
`AppShortcutsService.isAvailable` alapértéke `Platform.isAndroid` → `Platform.isAndroid ||
Platform.isIOS` — a class doksija C2.11a óta szó szerint ezt írta elő ("so C2.11b can widen this
to iOS once its native side exists").

**Build-ellenőrzés:** `xcodebuild -workspace Runner.xcworkspace -scheme LifeyWidgets -sdk
iphonesimulator build` — **BUILD SUCCEEDED** (ez a séma a `Runner` célt is felépíti függőségként,
tehát az `AppDelegate.swift`/`ShortcutsChannel.swift` is lefordult). `flutter analyze` teljes
projektre tiszta. A négy érintett Dart-teszt (`app_shortcuts_service_test.dart`,
`widget_snapshot_writer_test.dart`) mind zöld — ezek nem változtak, csak megerősítik, hogy az
`isAvailable`-bővítés nem tört el semmit (mindkét teszt explicit `isAvailable:` paramétert ad át,
nem az alapértékre támaszkodik).

**Amit ez a lépés szándékosan nem tett meg:** eszközön/szimulátoron futtatott végpróbát (app-ikon
hosszú nyomás → shortcut lista → koppintás → edzés indul; widget-gomb koppintás) — a felhasználó
kérésére, ugyanúgy, mint C2.10b-nél. Ezzel a **C2 iteráció mind a 13 lépése kész** (C2.1–C2.11b) —
csak a saját eszközön futó vizuális/interakciós végpróba maradt nyitva mindkét Mac-lépésnél
(C2.10b, C2.11b).
lépése.

---

## C3.1 kész (2026-08-12) — Backend: repository-lekérdezések + `StatisticsResponse` additív bővítés

**Párhuzamosan a C2.10b/C2.11b Mac-es munkájával** — tisztán backend (Spring Boot), semmi közös
felszín a mobil-natív munkával, ezért ugyanabban az ablakban haladhatott.

**A meglévő mezők jelentése és értéke tényleg nem változott** (D-C3.1): `workoutCount` továbbra is
"összes edzés", ugyanaz a Spring Data derived query
(`countByUserIdAndDeletedAtIsNullAndStartedAtGreaterThanEqual`) számolja, ugyanazokkal a
paraméterekkel. Az öt új mező (D-C3.2) tisztán additív a `StatisticsResponse` recordban:

```java
public record StatisticsResponse(
        Double totalCalories, Double totalProtein, Double totalCarbs, Double totalFat,
        Integer workoutCount, Double latestWeight, Double totalWater,
        int strengthWorkoutCount, int cardioWorkoutCount, int movingMinutes,
        double totalDistanceMeters, double totalElevationGainMeters
) {}
```

**A `strengthWorkoutCount` levezetett, nem lekérdezett** — csak egy új repository-metódus kell
(`countByUserIdAndDeletedAtIsNullAndStartedAtGreaterThanEqualAndSessionKind(..., CARDIO)`), a
strength-szám `workoutCount - cardioWorkoutCount`, mivel a `SessionKind` enumnak pontosan két
értéke van és minden session-nek pontosan az egyike (a mező `nullable = false`). Egy lekérdezéssel
kevesebb, mint egy naiv "mindkét fajtát külön megszámolom" megoldás.

**`distanceMeters`/`elevationGainMeters` a `CardioDetails` táblán élnek, nem a
`WorkoutSession`-ön** (docs/cardio/52 §2.2 — hibrid tárolás, a `moving_seconds` viszont a
`WorkoutSession`-ön van közvetlenül) — a Σ-lekérdezéseknek ezért `join w.cardioDetails c`-t kell
tenniük, ami a house-style `sum*Since` JPQL-mintát követi (`MealRepository`/`WaterEntryRepository`):
`coalesce(sum(...), 0)`, hogy üres eredményhalmazon a primitív `long`/`double` visszatérési típus
sose `null`-ra unboxoljon. A `moving_seconds` összegzés nem szűr `sessionKind`-ra — mivel
STRENGTH session-nél a mező mindig `null`, a `sum` már eleve csak a cardio sorokat számolja (a
SQL/JPQL `sum` kihagyja a null-okat).

**A `StatisticsResponse` konstruktor pozicionális** — a bővítés a Java record kanonikus
konstruktorát is bővíti, tehát minden meglévő hívóhelyet frissíteni kellett (1 valódi + 7 teszt):
`StatisticsServiceImpl`, `StatisticsControllerTest` (×3), `TrainerClientDataControllerTest` (×4).
Egyik sem szemantikai változás, csak a trailing paraméterek pótlása.

**Tesztek, három szinten:**
- `StatisticsServiceImplTest` — a meglévő `stubAggregates` 4-argumentumos overloadja megmaradt
  (a 4 régi teszt változatlan), egy új 8-argumentumos verzió is stubolja az új
  repository-hívásokat. Két új teszt: `cardioBreakdown_addsNewFieldsWithoutChangingOldOnes`
  (vegyes adathalmazon a **régi mezők bitre azonosak**, ez a kész-ha), és
  `cardioBreakdown_isZeroForAPurelyStrengthHistory` (a régi 4-argumentumos hívás nullázza az
  összes új mezőt).
- `StatisticsControllerTest`/`TrainerClientDataControllerTest` — a 7 hívóhely frissítve, a
  `daily_returnsOk` teszt kapott `jsonPath`-asszerciókat az öt új JSON-mezőre is.
- `WorkoutSessionStatisticsQueriesRepositoryTest` (új fájl, a `WorkoutSessionKindFilterRepositoryTest`
  mintáját követve) — **valódi Postgres Testcontainers-szel**, mert a `CardioDetails`-join
  helyességét egy mockolt repository-teszt nem tudja ellenőrizni. Vegyes adathalmaz: 1 STRENGTH +
  2 CARDIO (ablakon belül) + 1 CARDIO (ablakon kívül, `from` előtt) + 1 puhán törölt CARDIO
  (ablakon belül) — a két utóbbi egyike sem jelenhet meg egyik összegben/számban sem. Külön teszt
  az üres eredményhalmaz `coalesce`-ára (jövőbeli `from`), hogy a primitív visszatérési típus
  sose dobjon NPE-t unboxoláskor.

**Eredmény:** `./mvnw compile`/`test-compile` tiszta; a teljes `./mvnw test` **702/702 zöld**
(693 + 9 nettó új: 4 repository-teszt új fájlban, 2 új `StatisticsServiceImplTest`, 3 bővített
JSON-asszerció a meglévő controller-tesztekben nem számít újnak), 0 bukás, 0 hiba.

**Következő:** `C3.2` — Mobil: `StatMetric` bővítés + `weightedAverage` aggregációs típus +
`effectiveMinutes` szabály (Q-D4 már eldöntve, lásd §1.2) — vagy folytatás Mac-en C2.10b/C2.11b-vel.

---

## C2.7 kiegészítés (2026-08-12) — Cardio belépési pont a `TemplatePickerScreen`-en (felfedezhetőségi javítás)

**A probléma, valódi felhasználói visszajelzésből**: a "+ Log" FAB **hosszú nyomása** nyitja a
gyorsindító lapot (cardio + erősítő vegyesen), a **sima koppintása** viszont a változatlan, tisztán
erősítő `TemplatePickerScreen`-t — és semmi vizuális jel nincs azon a képernyőn, hogy egy hosszú
nyomás mást csinál. Cardio indítása így egy fel nem fedezhető gesztuson múlt.

**A megoldás nem egy új gesztus, hanem egy új, koppintható ajtó ugyanoda.** A
`TemplatePickerScreen` ("Choose template") az "Empty workout" alá kapott egy "Cardio" csempét,
ami a már meglévő `ActivityPickerScreen`-re navigál (a hosszú nyomás → gyorsindító lap → "Összes
edzéstípus" sor végállomása) — tehát **nem duplikál** semmilyen cardio-indítási logikát, csak egy
második, koppintással elérhető utat nyit ugyanoda. A hosszú nyomás megmarad (gyorsabb út annak, aki
már tudja), de a felfedezhetőség többé nem függ tőle.

**A csempe-widget megosztott, nem duplikált**: az "Empty workout" saját `_EmptyWorkoutTile`-ja
általánosodott `_PickerActionTile`-lá (icon/szín/cím/alcím paraméterezve) — ugyanaz a vizuális forma
szolgálja ki mindkét belépési pontot, egy helyen karbantartva.

**Két új l10n-kulcs** (`cardioWorkoutTileLabel`/`cardioWorkoutTileSubtitle`, HU+EN) — a
`cardioSectionLabel` ("CARDIO", csupa nagybetűs szekció-fejléc) nem volt újrahasználható egy
Title Case csempe-címhez.

**Eredmény:** `flutter analyze` (teljes projekt) tiszta; a `test/features/workouts/presentation/`
alatti tesztek (204) mind zöldek — `TemplatePickerScreen`-nek eddig sem volt dedikált tesztje,
ez a lépés sem ad neki (a navigáció maga `ActivityPickerScreen`-re mutat, aminek megvan a saját
tesztje). **Élő eszközön/emulátoron nem lett vizuálisan ellenőrizve** — a jelenlegi eszközkészlet
nem tud Flutter mobil előnézetet futtatni; a felhasználó saját debug buildjén tudja ellenőrizni.

---

## C2.8 kiegészítés (2026-08-12) — a cardio-összegzés vissza gombja a Sessions fülre ugrik

**A probléma, ismét élő tesztelésből**: `CardioSessionScreen._finish()` `pushReplacement`-tel
cseréli le magát `CardioSummaryScreen`-re — helyesen, hiszen a futó képernyőnek nincs mit mutatnia
befejezés után. A vissza gomb viszont ezután azt mutatta, ami **a `CardioSessionScreen` alatt már
ott volt a navigator-veremben** — ami a gyorsindítás sok belépési pontja miatt (FAB hosszú nyomás
bármelyik shell-fülről, `ActivityPickerScreen`, C2.11a/b deep-link/shortcut/widget) szinte sosem a
Workouts képernyő Sessions füle, hanem amit a felhasználó épp nézett edzéskezdéskor (pl. Dashboard).

**A megoldás: a shell állapotát a befejezéskor állítjuk be, nem a vissza gombnál.** Amíg a
`CardioSummaryScreen` még a képernyőn van, a mögötte lévő shell láthatatlan — ezért `_finish()`
ekkor (nem a pop pillanatában) két dolgot állít be:
- `context.go('/workouts')` — a shell aktív alsó-navigációs füle Workouts lesz.
- egy új, apró `workoutsSessionsTabRequestProvider` (`workouts_screen.dart`, `Notifier<int>`
  számláló, nem bool — `ref.listen` csak *változásra* tüzel, egy második kérés is új értéket
  igényel) — ezt a `WorkoutsScreen` `build()`-je figyeli, és ha tüzel, `_tabController.animateTo(0)`-t
  hív, vagyis a belső "Sessions/Templates/Exercises" pill-válogatót is Sessionsre állítja, még akkor
  is, ha az `IndexedStack` miatt élő `WorkoutsScreen`-példány korábban másik al-fülön állt.

**Miért nem globális `CardioSummaryScreen`-viselkedés, hanem csak a friss befejezés ága**: a
`CardioSummaryScreen` egy **régebbi**, már befejezett cardio session megtekintésekor is megnyílik
(pl. a Sessions listából koppintva) — ott a sima `pop()` már ma is helyesen oda visz vissza, ahonnan
jöttek (lehet az Dashboard egy "legutóbbi edzések" kártyája is). A javítás ezért kizárólag
`_finish()`-ben ül, nem a `CardioSummaryScreen` widgetben — a megtekintés-ág érintetlen marad.

**Teszt-védelem, ami majdnem törött volna**: mind a négy `cardio_session_screen*_test.dart` fájl
saját, router nélküli (`MaterialApp`, nem `MaterialApp.router`) `_pump` segédfüggvénnyel dolgozik —
`context.go(...)` egy ilyen host-ban `GoError`-ral dobna. A tényleges kódban ezért
`GoRouter.maybeOf(context) != null` őrzi a hívást: a valódi appban (mindig van router) változatlan
a viselkedés, a router nélküli tesztekben csendes no-op — a `workoutsSessionsTabRequestProvider`
számláló-bővítése viszont routertől függetlenül lefut, ez külön tesztelve is van.

**Tesztek:** `cardio_session_screen_test.dart` +1 (`finishing requests the Workouts screen jump
back to its Sessions sub-tab`) — a provider értékét `ProviderScope.containerOf` olvassa ki a
befejezés előtt/után, a `context.go` natív végrehajtását (ami valódi `GoRouter`-t igényelne) nem
teszteli közvetlenül, csak a `GoRouter.maybeOf` őrzőn keresztül közvetve (a meglévő
finish-tesztek továbbra is zöldek maradtak router nélkül is).

**Eredmény:** `flutter analyze` (teljes projekt) tiszta; a 4 `cardio_session_screen*_test.dart`
fájl mind zöld (beleértve az új tesztet); a teljes `flutter test` **840/843 zöld**, a 3 bukás a
már ismert, cardión kívüli `chat_repository_test.dart` Windows-fájlzár-flake.

**Következő:** `C3.2` — Mobil: `StatMetric` bővítés + `weightedAverage` aggregációs típus +
`effectiveMinutes` szabály (Q-D4 már eldöntve, lásd §1.2).

---

## C3.2 kész (2026-08-12) — Mobil: `StatMetric` bővítés + `weightedAverage` + `effectiveMinutes`

**Tisztán mobil, backend/Dart-modell nélkül** — a statisztika-képernyő a `WorkoutSession`-lista
helyi (Drift-alapú) forrásaiból számol mindent, ugyanúgy, mint eddig is (`workoutMinutes`,
`workoutCount`, `activeCalories`); a C3.1-ben bővített backend `StatisticsResponse`-t a mobil
oldal ehhez a képernyőhöz **nem is olvassa** — az más felületeké (dashboard bontás-sor, edzői heti
riport), nem ennek a lépésnek a dolga.

**Hat új `StatMetric`** (56 §3 táblázata szerint): `cardioDistance`, `cardioMovingMinutes`,
`cardioElevationGain`, `cardioAvgPace`, `maxHeartRate`, `cardioSessions` — mind
`stat_metric.dart`-ban, saját címkével/mértékegységgel/aggregációval. Szándékosan **nem**
`strengthWorkoutCount`/`cardioWorkoutCount` duplikátumok a meglévő `workoutCount` mellé (D-C3.4,
az a C3.3 fajta-szűrőjének dolga) — ez a hat az, ami **csak** cardiónál létezik.

**`StatAggregationType.weightedAverage`** — új enum-érték, D-C3.6: Σ idő / Σ táv, nem az egyes
session-ek saját tempójának számtani átlaga (egy 1 km-es kocogás és egy 20 km-es futam nem
számíthat egyenlő súllyal). A `_cardioAvgPacePoints` (`stat_chart_data.dart`) két párhuzamos
napi-összeg map-et épít (mozgásidő, táv), és csak a végén oszt — egy nap csak akkor kap pontot, ha
legalább egy session-nek van valódi (`> 0`) távja aznap, így nullával osztás fizikailag nem
történhet meg, és egy "semmi használható" nap egyszerűen **hiányzik** a sorozatból, nem egy hamis
0:00/km pontként jelenik meg (D-C3.5 szellemében, bár maga a hiány-kezelés UI-ja C3.3 dolga).
**Szándékosan kizárja a túrázást** a DISTANCE családból — az 56 §3 zárójele ("futás, séta")
kifejezetten csak ezt a kettőt nevezi meg, a túra tempója pihenő/fotó-megállók miatt nem egy
értelmes "milyen gyors voltam" szám.

**`effectiveMinutes` (D-C3.3), a kész-ha szó szerinti "bitre azonos" próbája**: a
`WorkoutSession.effectiveDuration` gettert (a C2.1-es élő cardio munkából, eddig kihasználatlanul)
köti be mind `stat_chart_data.dart` `_sessionPoints`-ja, mind `weekly_recap.dart`
`WeeklyRecap.compute`-ja — a `finishedAt?.difference(startedAt)` bruttó számítás helyett. Mivel
`movingSeconds` STRENGTH session-nél sosem áll be, `effectiveDuration` ugyanoda esik vissza, mint a
régi kód — **bitre azonos**, tesztben is bizonyítva.

**A `maxHeartRate` `average` aggregációja trükk nélkül működik**: a `_maxHeartRatePoints` minden
napra a nap **maximumát** teszi be pontnak (nem átlagot); az `average` felirat innentől arra
utal, amit a képernyő generikus Sum/Average/Min/Max összesítő rétege (`stat_summary_data.dart`,
amit ez a lépés **nem** módosított) magától csinál a napi pontokkal — "napi maximumok átlaga" (56
§3) ingyen adódik, mert a napi pont maga már a helyes maximum.

**Amit szándékosan nem oldott meg ez a lépés** (a `_summarize` réteg metrika-agnosztikus marad):
egy `weightedAverage` metrika "Sum"/"Average" KPI-kártyája a képernyő tetején a **napi már helyesen
súlyozott pontok** feletti sima számtani átlagot/összeget mutatja, nem egy elméletileg tiszta,
teljes-időszakra súlyozott értéket — ugyanaz a már meglévő, el nem hallgatott kompromisszum, mint
amit a `weight` metrika "Sum" kártyája is képvisel ma (testsúlyok összege sem értelmes szám, mégis
megjelenik). Konzisztens a képernyő meglévő viselkedésével, nem ad hozzá új, máshol nem létező
speciális esetet.

**Mértékegység, szándékosan nem `UnitSystem`-tudatos**: km/m fixen, ugyanúgy, ahogy `weight`/`water`
is fixen kg/L-ben jelenik meg ezen a képernyőn ma — a statisztika-képernyő sosem volt
mértékegység-váltó-tudatos, és ezt a hat új metrikát kiemelni ez alól nagyobb, következetlen
változás lett volna, mint amit a C3.2 kért.

**A tempó saját formázást kapott**: `_formatValue` most `cardioAvgPace`-re M:SS formátumot ad
("5:23 /km"), nem a képernyő általános tizedesjegyes formázását — ez illeszkedik
`CardioFormatter.pace` már bevett konvenciójához a cardio-képernyőkön, ahelyett hogy egy idegen
"5.4 /km" jelenne meg itt.

**11 új l10n-kulcs** (6 metrika-címke + 4 mértékegység + a pace-egység átírása "min/km"-ről
"/km"-re, hogy M:SS formátum után illeszkedjen), HU+EN.

**Tesztek:** `stat_chart_data_test.dart` (+11: 6 fajta-specifikus lekérdezés, a súlyozott tempó 3
esete — súlyozott vs. naiv átlag, túra kizárva, nullával osztás elkerülve —, a napi maximum-e a
pulzus, plusz egy `availableStatMetricsProvider` cardio-teszt), `weekly_recap_test.dart` (+1,
D-C3.3 a heti visszatekintőben). A meglévő `workoutMinutes`/`availableStatMetricsProvider`
tesztek (tisztán erősítő adathalmazon) változtatás nélkül zöldek maradtak — ez maga a "bitre
azonos" regresszió-bizonyíték.

**Eredmény:** `flutter analyze` (teljes projekt) tiszta; a teljes `flutter test` **851/854 zöld**
(840 + 11 nettó új: 10 `stat_chart_data_test.dart`, 1 `weekly_recap_test.dart`), a 3 bukás a már
ismert, cardión kívüli `chat_repository_test.dart` Windows-fájlzár-flake.

**Következő:** `C3.3` — Statisztika-képernyő: fajta-szűrő (D-C3.4 SegmentedButton: Mind/Erősítő/
Cardio) + a hat új cardio-metrika felvétele a képernyő pickerébe + hiány-kezelés (D-C3.5), **M21**,
**M22** — vagy folytatás Mac-en, ha C2.10b/C2.11b még nincs kész.

---

## C3.3 kész (2026-08-12) — Statisztika-képernyő: fajta-szűrő + cardio-metrikák + hiány-kezelés

**A három alrészből kettő már gyakorlatilag megvolt a C3.2 óta** — csak most vált nyilvánvalóvá:

- **"cardio-metrikák a képernyőn"**: a hat új `StatMetric` a `_StatsMetricButton` picker
  `for (final m in StatMetric.values) if (pickableMetrics.contains(m))` ciklusán keresztül **már
  C3.2 óta** megjelenik, mihelyt van hozzá adat (`availableStatMetricsProvider` már ott bővült) —
  ehhez a lépéshez nem kellett új kód.
- **"hiány-kezelés" (D-C3.5, "üres nap ≠ 0 pont")**: a C3.2-es pont-építő függvények (`_sessionPoints`,
  `_cardioAvgPacePoints`, `_maxHeartRatePoints`) soha nem írnak 0-s pontot egy adat nélküli napra —
  egyszerűen kihagyják. A teljes tartományra üres eredmény a meglévő `EmptyView`-t mutatja. A C3.2
  saját tesztjei (pl. "a day with only zero/missing distance is absent") már bizonyítják ezt.

**Amit ez a lépés ténylegesen épített: a fajta-szűrő (D-C3.4).** Új `StatKindFilter` enum
(`all`/`strength`/`cardio`) + `StatKindFilterController`, és egy valódi `SegmentedButton` a
képernyő tetején (nem egy harmadik popup-chip a meglévő kettő mellé — D-C3.4 kifejezetten
`SegmentedButton`-t kér, és ez **mindig látható** kell legyen, hogy egy üres cardio-nézetből
(M22) egy koppintással vissza lehessen lépni "Mind"-ra vagy "Erősítő"-re). Három meglévő l10n-kulcs
(`allFilterLabel`/`activityTypeStrength`/`sessionKindCardioLabel`) újrahasznosítva, egy sem új.

**A szűrő az "edzés jellegű" metrikákat (workoutCount/workoutMinutes/activeCalories) újra-skálázza**,
nem csak megjeleníti/elrejti őket — `_filterByKind` a session-listát fajtára szűkíti *mielőtt* a
napi összegzés lefut, így "Erősítő" alatt a `workoutCount` tényleg csak az erősítő session-eket
számolja, "Cardio" alatt csak a cardiókat. A hat cardio-only metrika (amik eleve csak cardio
session-t tartalmaznak) "Erősítő" alatt egyszerűen semmit sem mutatnak — nincs értelmes
"erősítő cardio-táv" szám. Az `availableStatMetricsProvider` **ugyanazt a szűrt session-listát**
használja minden predikátumhoz, így a hat cardio-only metrika a pickerből is eltűnik "Erősítő"
alatt, plusz redundáns explicit `kindFilter` guard nélkül — a már szűrt lista magától kizárja őket.

**Amit szándékosan nem épített meg** (a mockup gazdagsága, nem az L-szintű döntés): az M21 mockup
egy jóval gazdagabb dashboard (3 mini-összegző csempe, aktivitás-színes napi oszlopok, külön
tempó- és szintemelkedés-grafikon fix layoutban), és az M22 üres állapot fajta-specifikus
"3 hete fociztál utoljára, 1:10 játékidő, átl. 146 bpm" szöveget mutat. A tényleges D-C3.4 szöveg
csak egy 3-utas `SegmentedButton`-t ír elő, a D-C3.5 csak azt, hogy hiányzó nap ≠ 0 pont — ez a
lépés pontosan ezt építette, a meglévő általános (nem fajta-specifikus) `EmptyView`-t és a meglévő
egy-metrika-egy-diagram elrendezést megtartva, ugyanaz a fegyelem, mint C2.10a-nál és a C2.7
felfedezhetőségi kiegészítésénél.

**Tesztek:** `stat_chart_data_test.dart` (+5, `StatKindFilter` csoport: Mind változatlan
viselkedés, Erősítő/Cardio újra-skálázás mindkét irányban, egy cardio-only metrika "Erősítő" alatt
teljesen üres, `availableStatMetricsProvider` "Erősítő" alatt kizárja mind a hat cardio-only
metrikát), `statistics_screen_test.dart` (+1, a `SegmentedButton` alapértéke "Mind", koppintásra
vált). A meglévő három screen-teszt (EmptyView/chart+KPI/ErrorView) változtatás nélkül zöld maradt.

**Eredmény:** `flutter analyze` (teljes projekt) tiszta; a teljes `flutter test` **856/858 zöld**
(851 + 6 nettó új: 5 `stat_chart_data_test.dart`, 1 `statistics_screen_test.dart` — a
Windows-fájlzár-flake ezúttal csak 2-t a `chat_repository_test.dart` 3 ismert bukásából).

**Következő:** `C3.4` — Dashboard bontás-sor + heti visszatekintő + **streak-küszöb** (15 perc
mozgásidő) — vagy folytatás Mac-en, ha C2.10b/C2.11b még nincs kész.

---

## C3.4 kész (2026-08-12) — Dashboard bontás-sor + heti visszatekintő táv + streak-küszöb

**Három, egymástól független alrész.** A kész-ha kifejezetten csak az egyikről szól ("A küszöb
egyetlen konstans, tesztelve") — a streak-küszöb a mérhető elfogadási kritérium, a másik kettő a
lépés-sor saját leírásából jött, de nincs hozzájuk mérőszám.

### Streak-küszöb (a tényleges kész-ha)

**A felfedezés, ami átalakította a feladatot**: a kódbázisban **korábban nem létezett semmiféle
"edzés streak" fogalom** — a `Streak`/`StreakMetric` csak kalóriát/lépést/vizet ismert, és a
`streaksProvider` sosem olvasott `WorkoutSession`-t. A [51 §8 Q1](51-cardio-overview-plan.md)
szabály ("≥ 15 perc mozgásidőtől vagy STRENGTH session") bevezetése ezért nem egy meglévő szűrő
finomítása volt, hanem egy új `StreakMetric.workout` felépítése a nulláról.

- **`workoutStreakMovingSecondsThreshold = 900`** (`streaks_provider.dart`) — egyetlen top-level
  konstans, nem `UserSettings`-mező, pontosan a [quick_start_options_provider.dart](../../mobile/lib/features/workouts/application/quick_start_options_provider.dart)-ban
  már bevett "named constant, nem beállítás" mintát követve.
- **Feltétel nélküli, nem `settings.dailyXGoal != null` mögé zárva** — a másik hárommal
  ellentétben ez mindig fut, hiszen Q1 kifejezetten kimondja: "Nem beállítás".
- **Egy nap akkor számít, ha VAGY van rajta STRENGTH session, VAGY egy cardio session
  mozgásideje eléri a küszöböt** — `_meetsWorkoutStreak` a `movingSeconds`-t nézi, nem a bruttó
  időt (ugyanaz a D-C3.3 elv, mint mindenhol máshol).
- **Előre aggregált nap→bool map, nem nyers session-lista a meglévő `_computeStreak<T>`-nek** —
  ez a megosztott segédfüggvény minden meglévő forrásnál (kalória/lépés/víz) pontosan egy
  bejegyzést tételez fel naponta; egy nap **több** session-je (pl. egy rövid, nem-számító cardio
  + egy erősítő ugyanazon a napon) a `todayMet`-et **felülírná**, nem VAGY-olná, ha nyersen
  kapná meg őket. A `workoutMetByDay` előzetes VAGY-olása ezt elkerüli anélkül, hogy a másik három
  streak működő logikájához hozzá kellett volna nyúlni.
- **Két kimerítő `switch` frissült** (`streak_chip_row.dart`, `weekly_recap_screen.dart`) — az
  új enum-érték miatt a fordító kikényszerítette mindkettőt, de a recap-képernyő "Célok" szekciója
  szándékosan **nem** kapott új sort az edzés-streaknek (az nem cél, nincs `workoutGoalSet`
  mezője) — a dashboard meglévő `StreakChipRow`-ja viszont feltétel nélkül mutatja, mert az
  minden `streaksProvider`-elemen végigmegy, nem csak a beállított célokon.

### Dashboard bontás-sor + ikonos lista

**A doc szövege egy nem létező UI-elem "alá" helyezné a sort** — "Az „edzések" szám alá" —, de a
dashboard **sosem** jelenítette meg a `workoutCount`-ot saját kártyaként (kiszámolva volt,
sehol nem olvasva). Mivel ehhez a lépéshez nincs mockup-keret sem, a legközelebbi értelmes hely
mellette döntöttem: a "Legutóbbi edzések" szekciócím **alá**, halk `labelSmall` stílusban,
csak ha `workoutCount > 0`. A szöveg a meglévő `activityTypeStrength`/`sessionKindCardioLabel`
feliratokat fűzi össze (" · "-tal), nem egy új összetett ICU-string — nincs "N erősítő/M cardio"
mondat máshol a kódbázisban, amit újra tudtam volna hasznosítani, de az egyes szavak igen.

**Az ikonos lista a már bevett `ActivityChip`/muscle-group-badge kettősséget veszi át**
(`sessions_tab.dart` ugyanezt csinálja) — `_WorkoutTile` mostantól `ActivityChip`-et rajzol
cardiónál, a régi erősítő-badge-et (kiemelve `_StrengthBadge`-be) máshol. Egy melléklet, amit a
puszta "ikonos" kérés önmagában felfedett: a gyakorlat-sor korábban `'—'`-t mutatott minden
cardio session-nél (nincs gyakorlatnév) — ez most az aktivitás címkéjére (`activityTypeLabel`)
vált, hogy ne látszódjon egy értelmetlen kötőjel minden cardio tile-on.

**Amit tudatosan nem javítottam**: `_WorkoutTile._statsLine` a **bruttó** időt mutatja
(`finishedAt - startedAt`), nem a D-C3.3 mozgásidő-szabályt — ugyanaz a hiba, amit a
statisztika/heti-visszatekintő oldalán C3.2 már kijavított, de ezen a konkrét dashboard-csempén
nem volt C3.4 explicit feladata, és egy önmagában is jó méretű, külön diffet érdemelne.

### Heti visszatekintő — heti cardio-táv sor

**`weeklyCardioDistanceMeters`**, ugyanazzal a DISTANCE+MACHINE családi szűréssel, mint a
`stat_chart_data.dart` `cardioDistance` metrikája (D-C3.7: egy közös definíció) — `null`, nem 0,
ha nem volt a héten minősítő táv (D-C3.5 "hiányzó, nem nulla" elve). A recap-képernyőn a
meglévő szám+perc sor mellé, harmadik elemként jelenik meg, csak ha nem null.

**Tesztek:** `streaks_provider_test.dart` (+5, workout-streak csoport: STRENGTH mindig számít,
cardio a küszöb alatt/pontosan a küszöbön, két session ugyanazon a napon VAGY-ol, a küszöb
konstans-értéke), plusz 5 meglévő teszt frissítve `.single`-ről metrika-szerinti szűrésre (mivel
mostantól mindig van egy plusz workout-streak elem a listában). `weekly_recap_test.dart` (+5,
heti táv csoport). `dashboard_controller_test.dart` (**új fájl** — a dashboard funkciónak eddig
egyáltalán nem volt tesztje; ez a C3.4 által ténylegesen módosított logikára szorítkozik, nem
próbálja utólag lefedni a kalória/fehérje/víz számítást, amit ez a lépés nem érintett).

**Eredmény:** `flutter analyze` (teljes projekt) tiszta; a teljes `flutter test` **869/872 zöld**
(15 nettó új teszt), a 3 bukás a már ismert, cardión kívüli `chat_repository_test.dart`
Windows-fájlzár-flake.

**Következő:** `C3.5` — PR-motor cardio-ága (leghosszabb táv / mozgásidő / szintemelkedés) +
edzői heti riport bővítés — vagy folytatás Mac-en, ha C2.10b/C2.11b még nincs kész. Ezzel a C3
mobil-oldali statisztika-munka (C3.1–C3.4) kész.

---

## C3.5 kész (2026-08-12) — PR-motor cardio-ága + edzői heti riport bővítés

**Két, egymástól teljesen független fél** — a mobil PR-motor és a backend edzői heti riport —,
ugyanúgy, ahogy a kész-ha is csak az elsőt méri ("Cardio nem termel erősítő PR-t és fordítva").
A kettőt párhuzamos felderítő ügynökök térképezték fel előre.

### A felfedezés, ami leegyszerűsítette a fél feladatot

**A "cardio nem termel erősítő PR-t" irány már eleve, szerkezetileg igaz volt** — a
`personal_record.dart`/`getPrBaseline` az `exercise_sets` Drift-táblát joinolja, aminek egy
cardio session sosem ír sort (minden cardio-mentési útvonal `sets: const []`-tal hív). Ezt a
[53 §0.1] és a [59 C0.5] audit már korábban megállapította és dokumentálta — nem volt hozzá
javítandó kód, és nem kapott új regressziós tesztet sem: a védelem a séma szintjén van, nem egy
futásidejű ágban, amit egy teszt megvédhetne a jövőbeli sérüléstől anélkül, hogy magát a sémát
is védené (ahhoz Drift-szintű teszt kellene, ami már létezik más C1-es lépések alól).

**A tényleges munka a fordított irány**: egy vadonatúj, `personal_record.dart`-tól **teljesen
különálló** cardio-motor felépítése, mert az erősítő motor szett/ismétlés-alapú (`PrSet`,
`(weight, reps, performedAt)`), a cardio-rekordok pedig session-szintű mennyiségek (táv,
mozgásidő, szintemelkedés) — nem ugyanaz az adatalak, nem lehet ráépíteni.

### Mobil: `cardio_personal_record.dart` (új fájl)

- **`CardioPrType`** — pontosan a [56 §5.2] három típusa: `longestDistance` (DISTANCE + MACHINE
  család együtt — futás/gyaloglás/túrázás/szobabicikli **egy közös** rekordként, nem
  aktivitás-típusonként külön, ugyanúgy, ahogy a `stat_chart_data.dart` `cardioDistance`
  metrikája is összevonja őket), `longestMovingTime` (minden család, hiszen minden cardio
  session mér mozgásidőt), `greatestElevationGain` (csak DISTANCE család — a szobabicikli nem
  emelkedik, még ha az oszlop létezik is rá). Gyorsított 1/5/10 km és a kerékpáros kJ-összteljesítmény
  tudatosan kimaradt (C6/C7, D-C3.8 — GPS-track kell hozzájuk, amit az app még nem rögzít).
- **`CardioPrBaseline`/`detectCardioPrs`** — 1:1 tükrözi az erősítő motor
  `PrBaseline`/`detectPrs` alakját (szigorúan-nagyobb szemantika, üres baseline sosem termel
  rekordot), de a bemenete `WorkoutSession`, nem `PrSet`. Egy session csak akkor számít
  baseline-nak vagy jelöltnek, ha `isCardio && finishedAt != null` — egy még futó élő session
  `movingSeconds`-mezője csak egy checkpoint (a valódi élő érték `liveMovingSeconds`-ban van),
  ezért kizárva, a mobil felderítő ügynök által javasolt konvenció szerint.
- **Baseline-forrás**: nincs új Drift-lekérdezés — a `workoutSessionControllerProvider` már
  memóriában tartja a teljes session-listát (`watchAll()`), ezt szűröm Dart-oldalon a jelenlegi
  session `clientId`-jét kizárva, ugyanazt az elvet követve, amit a `watchByKind` doksija is
  kimond ("egyetlen hely gyűjti össze egy session gyakorlatait/szettjeit/cardióját").

### Mobil: UI-felszín

**A doc szövege az erősítő `WorkoutSuccessDialog`-ot nevezi meg jövőbeli mintaként, de az
`ExerciseBlock`-okra épül és konfetti-dialógusként cascade-eli a több chipet** — ez nem 1:1
map-elhető egy cardio sessionre, ahol legfeljebb 1-3 rekord dől meg egyszerre, és a
`cardio_summary_screen.dart` egész hangneme amúgy is nyugodtabb (read-only carry-over, nincs
"gimmick" — lásd a képernyő saját class-doksiját). Emiatt egy **saját, egyszerűbb sáv-widget**
(`_NewRecordBanner`) mellett döntöttem: trófea-ikon + amber szín (ugyanaz a `0xFFD8B35A`, mint
az erősítő `_prBadge`-é, vizuális konzisztencia kedvéért), egy sorban felsorolva a megdőlt
típusokat. Ez a `CardioSummaryScreen` fejléc alá kerül, csak akkor jelenik meg, ha
`newRecords` nem üres.

**`newRecords` alapértéke `const []`** — a `CardioSessionScreen._finish()` a friss befejezéskor
számítja ki és adja át (`detectCardioPrs` + a fentebb leírt baseline), az
`open_workout_screens.dart` (egy már lezárt session újranyitása) viszont sosem ad át semmit, így
a sáv csak az élő befejezés pillanatában jelenik meg — egy régi session újbóli megnyitása nem
"ünnepli újra" ugyanazt a rekordot.

### Backend: edzői heti riport bővítés

- **`WeeklyTrainerReport.ClientWeekSummary`** additívan bővült: `strengthWorkouts`,
  `cardioWorkouts`, `cardioDistanceMeters`. `strengthWorkouts` levezetett
  (`completedWorkouts - cardioWorkouts`), nem külön lekérdezett — ugyanaz a minta, mint a C3.1
  `StatisticsServiceImpl`-jében.
- **Két új, korlátozott tartományú repository-lekérdezés** (`WorkoutSessionRepository`):
  `...FinishedAtIsNotNullAndSessionKind` (a meglévő, korlátozott `completedWorkouts`-lekérdezés
  `SessionKind`-dal bővített párja) és `sumDistanceMetersBetweenForCompleted`. **Tudatosan
  `finishedAt is not null`-lal szűrve**, eltérően a C3.1 nyitott végű `sumDistanceMetersSince`-től
  (ami a statisztika-képernyő "X óta" nyitott összegeihez kell, és szándékosan beleszámít egy még
  futó session felgyűlt távját is) — egy már lezárult riport-hét közepén "még folyó" session
  gyakorlatilag egy elhagyott/be nem fejezett session, amit ugyanúgy kizárok, mint ahogy a
  meglévő `completedWorkouts` is kizárja a saját, "elért eredmény, nem tempó-mutató" jellege miatt.
  Ez azt is biztosítja, hogy a bontás-sor számai pontosan összeadódjanak a fejléc `completedWorkouts`
  számával.
- **`WeeklyReportFormatting.summarize()`**: új sor, `"{strength} strength · {cardio} cardio ·
  {km} km"` alakban (`mail.weekly-report.cardio-breakdown-line`, HU/EN mindkettőben), **csak
  akkor jelenik meg, ha `cardioWorkouts() > 0`** — egy tisztán erősítős ügyfélnél a bontás
  semmi újat nem mondana a már meglévő workouts-sor fölött, csak zajt jelentene.
- **Nem a mail-sablonfájlokban** történt a változtatás — a `weekly_report_row_{hu,en}.{html,txt}`
  csak `{{clientName}}`/`{{summary}}` tokent ismer, a `{{summary}}` tartalmát Java-oldalon,
  string-összefűzéssel építi a `WeeklyReportFormatting`, ahogy eddig is.

### Tesztek

- **`cardio_personal_record_test.dart`** (új fájl, 14 teszt) — a `personal_record_test.dart`
  stílusát követve: baseline-építés családi szűréssel, STRENGTH/be nem fejezett session teljes
  kizárása, több típus egyidejű megdőlése, "nincs baseline → nincs rekord" él-eset.
- **`cardio_summary_screen_test.dart`** (+2 teszt) — a sáv megjelenik `newRecords`-szal, és nem
  jelenik meg nélküle (a "régi session újranyitása" eset szimulációja).
- **`WeeklyReportServiceImplTest`** (+1 teszt, plusz a meglévő zéró-aktivitás teszt kiegészítve) —
  `strengthWorkouts = completedWorkouts - cardioWorkouts` számítás.
- **`WeeklyReportFormattingTest`** (+2 teszt, a többi 8 pozíciós konstruktorhívása frissítve az
  új mezőkkel) — a bontás-sor megjelenik cardióval, és hiányzik cardio nélkül; HU/EN szöveg is
  ellenőrizve.
- **`ResendMailServiceTest`** — a `sampleReport()` konstruktorhívása frissítve.
- **`WorkoutSessionWeeklyReportQueriesRepositoryTest`** (új fájl, valódi Postgres/Testcontainers,
  a meglévő `WorkoutSessionStatisticsQueriesRepositoryTest` stílusát követve) — a két új
  korlátozott lekérdezés: csak a befejezett, tartományon belüli cardio session-ök számítanak
  bele, a soft-deletelt és a be nem fejezett sorok nem.
- **`MailMessagesKeysConsistencyTest`** — automatikusan zöld maradt, mivel az új kulcs mindkét
  `mail_{en,hu}.properties`-be bekerült.

**Eredmény:** mobil `flutter analyze` (érintett fájlok) tiszta; a teljes `flutter test`
**888 teszt, 16 nettó új** (14 + 2, pontosan a fenti két új/bővített fájlból), a 3 bukás a már
ismert, cardión kívüli `chat_repository_test.dart` Windows-fájlzár-flake. Backend: teljes
`./mvnw test` **708/708 zöld**, 0 hiba.

**Következő:** C4a (GPS/útvonal) vagy C5 (óra) — vagy folytatás Mac-en C2.10b/C2.11b-n, ha azok
még nincsenek kész.

---

## C1w.1 kész (2026-08-12) — web `types.ts` bővítés

Az első web-oldali cardio-lépés — tisztán típus-bővítés, nulla viselkedésváltozás, ahogy a
kész-ha is kéri.

**`web/src/features/workouts/types.ts`**:
- `SESSION_KINDS`/`SessionKind` (`STRENGTH`/`CARDIO`) és `ACTIVITY_TYPES`/`ActivityType` union
  típus a mobil `activity_type.dart` kódlistájával megegyező hét értékkel (`RUNNING`, `WALKING`,
  `HIKING`, `INDOOR_BIKE`, `BASKETBALL`, `FOOTBALL`, `OTHER_CARDIO`) — bitre a backend
  `ActivityType` enumja szerint.
- Új `CardioDetailsResponse`/`CardioDetailsRequest` és `CardioSplitResponse`/`CardioSplitRequest`
  interfészek, mezőnként 1:1 a backend `CardioDetailsResponse`/`Request` és
  `CardioSplitResponse`/`Request` rekordjaival (a request oldalon minden mező opcionális, ahogy a
  backend DTO-ban is csak a `@PositiveOrZero`/`@Min`/`@Max` védi őket, nem a nullability).
- `WorkoutSessionResponse` additívan bővült: `sessionKind` (nem opcionális — a backend "sosem
  null" garanciáját tükrözi), `activityType`, `movingSeconds`, `cardio`, `splits`. A többi mező
  (és a web típusnak eddig is hiányzó, response-only mezői, pl. `scheduledFor`/`updatedAt`)
  érintetlen — a web types.ts sosem volt 1:1 tükre a backend DTO-nak, csak a ténylegesen
  felhasznált mezőket vitte át, ezt a mintát követtem.
- `WorkoutSessionRequest` ugyanezekkel a mezőkkel bővült, mind opcionálisan (`sessionKind?`,
  `activityType?`, `movingSeconds?`, `cardio?`, `splits?`) — egy régi kérés-építő (pl.
  `SessionsView.tsx` induló `create()` hívása, `SessionLogger.tsx` `buildRequest()`-je) ezek
  nélkül is fordul, mert egyik mező sem kötelező.

**API-réteg**: `web/src/features/workouts/api.ts` nem igényelt módosítást — a `workoutSessionApi`
metódusai generikusan a `WorkoutSessionResponse`/`Request` típuson keresztül engedik át a JSON-t,
a bővített típus automatikusan "átengedi az új mezőket", nincs kézzel felsorolt mezőlista, amit
frissíteni kellene.

**Egyetlen érintett hívóhely**: `aggregate.test.ts` egy kézzel felépített
`WorkoutSessionResponse[]` fixture-t tartalmazott a régi (öt mezővel rövidebb) alakban — ez a
`sessionKind` nem-opcionális mezője miatt már nem fordult volna. Az öt új mezővel kiegészítve
(`sessionKind: "STRENGTH"`, a többi `null`/`[]`) — ez nem funkcionális változás, csak a fixture
igazítása az új, teljesebb típushoz.

**Ellenőrzés:** `npx tsc --noEmit` a teljes projekten tiszta; `npx eslint` a két érintett fájlon
tiszta; a teljes `npx vitest run` **168/168 zöld** (17 tesztfájl, nulla regresszió).

**Következő:** `C1w.2` — web `ActivityChip` komponens a web design-rendszer tokenjeivel (a mobil
`ActivityChip` párja) + a `SessionsView` kártya `kind`-elágazása.

---

## C1w.2 kész (2026-08-12) — web `ActivityChip` + `SessionsView` kind-elágazás

**Három új fájl** a `web/src/features/workouts/` alatt, a mobil `activity_type.dart` +
`activity_chip.dart` páros web-megfelelője:

- **`activityType.ts`** — `activityFamilyOf`, `activityTypeIcon`, `activityTypeColor`. Az
  ikon-térkép bitre a W01 frame szerint (`directions_run`, `directions_walk`, `hiking`,
  `pedal_bike`, `sports_basketball`, `sports_soccer`, `fitness_center`, `bolt` az `OTHER_CARDIO`/
  ismeretlen ágra). A színek nem hex-értékek, hanem a `globals.css`-ben **már létező**
  `--metric-*`/`--tertiary` CSS-változók — a W01 frame minden egyes chip-színe pontosan egy
  meglévő metrika-tokennel egyezik (pl. futás = `--metric-kcal`, gyaloglás = `--metric-steps`,
  túrázás = `--tertiary`), így a light/dark témaváltás **automatikus**, nincs `BuildContext`-szerű
  elágazás, amit a mobil `activityTypeColor`-nak kézzel kellett megoldania.
- **`cardioFormat.ts`** — `formatDistanceKm` (locale-érzékeny, `Intl.NumberFormat` a HU
  vessző-tizedesjelhez), `formatDuration` (m:ss / h:mm:ss), `formatPace` (perc:mp /km, `null` 0
  vagy negatív távon). Csak metrikus — a webnek (a mobillal ellentétben) még nincs
  mértékegység-váltója, ezért ez a mobil `CardioFormatter`-nek csak a ténylegesen szükséges
  részhalmaza, nem 1:1 másolat.
- **`components/ActivityChip.tsx`** — két méret (24 px lista-sor, 40 px részletnézet-fejléc,
  ahogy a W01 jegyzete mondja: "a weben csak két méret kell, mert nincs csempe és nincs
  értesítés"). A háttér-fedés **flat 16% mindkét témában** — ez a W01 frame jegyzetében explicit
  eltérés a mobil 14% sötét / 16% világos szabályától ("egyetlen szabályt kell fejben tartani").

**`SessionsView.tsx` `SessionRow` `kind`-elágazása** (W3 hívóhely a 58-as tervben):
- Cím: `STRENGTH`-nél változatlan (`templateName` → gyakorlatnevek → fallback-szöveg lánc),
  `CARDIO`-nál az aktivitás lokalizált neve (`workouts.activityTypes.*`, új ARB-szerű kulcsok
  EN/HU-ban, a `muscleGroups`/`equipmentTypes` mintáját követve) — ez zárja a doc által
  megnevezett üres-cím hibát (a `session.exercises` egy cardio session-nél mindig üres, tehát a
  régi `exNames || fallback` lánc sosem talált volna értelmes címet).
- Alcím: családfüggő `cardioSummaryLine()` — DISTANCE: táv · időtartam · tempó; MACHINE:
  időtartam · táv · átlag watt; GAME: mozgásidő · bruttó idő · átlagpulzus. Minden rész csak akkor
  jelenik meg, ha van hozzá adat (nincs megtévesztő "0,00 km" vagy "0 szett" — ez utóbbi egyébként
  már eddig is védve volt a meglévő `sets.length > 0` őrrel, csak a cím-ág hiányzott). A duplikált
  `cardioSummaryLine(session)`-hívást egyetlen `summaryLine` konstansra vontam össze a sorban.
- `ActivityChip` csak a cardio ágon jelenik meg a cím előtt; az erősítő sor vizuálisan
  változatlan (`flex items-center gap-3` becsomagolás, de a chip feltételes renderelése miatt a
  strength-ágon egyszerűen nincs ott).

**Két új ARB-szerű i18n kulcscsoport** (`en.json`/`hu.json`, `workouts` névtér): `activityTypes.*`
(hét kód + `STRENGTH`, a mobil ARB HU/EN szövegeivel egyezően) és két lapos kulcs, `movingTime`/
`totalTime` — a design 12. szekciójának hivatalos rövid HU/EN pár-választása ("mozgásidő"/"moving
time", "bruttó idő"/"total time"), nem az általam kitalált "playing time"/"gross time" szöveg.

**Tesztek** (`activityType.test.ts` +8, `cardioFormat.test.ts` +6 — a webes suite először nem
`.test.ts` konvenciót lát cardio-logikára): a `formatPace`/`formatDuration` tesztadatai szándékosan
a W02 frame saját számait használják (8420 m / 2716 s → "5:23 /km"), így a teszt egyúttal azt is
igazolja, hogy a formázó **pontosan** a mockup számait adja vissza, nem csak plauzibilis
kerekítést. `SessionsView`/`SessionRow`-hoz nem készült komponens-teszt — a `vitest.config.ts`
`environment: "node"` és `include: ["src/**/*.test.ts"]` (nem `.tsx`) jelzi, hogy a web-projekt
eddig kizárólag tiszta logikát tesztel, nincs jsdom/React Testing Library bekötve; új
komponens-teszt infrastruktúra bevezetése túlment volna ennek a lépésnek a keretein.

**Ellenőrzés:** `npx tsc --noEmit` és `npx eslint` (mind a négy érintett/új fájlon) tiszta. Teljes
`npx vitest run`: **182/182 zöld** (19 fájl, 168 régi + 14 új). Böngészős ellenőrzés: a Next.js dev
szerver elindítva, a `/workouts` route (ami a `SessionsView`/`ActivityChip`/`activityType.ts`/
`cardioFormat.ts` teljes láncot betölti) **200**-zal fordult, nulla szerver- vagy konzolhiba — a
valódi bejelentkezés + cardio session-adat (backend indítás, teszt-user, seedelt cardio rekord)
ehhez a lépéshez nem volt elérhető ebben a sandboxban, ezért a vizuális (pixel-szintű) egyezés a
W01/W02 frame-mel **nincs** böngészőben leellenőrizve, csak a típus-/logika-szintű helyesség.

**Következő:** `C1w.3` — **`SessionLogger` `kind`-kapu + olvasó cardio részletnézet** +
útvonal-SVG — ez a legfontosabb C1w tétel: egy cardio session megnyitása ma még a szett-logolót
nyitná meg (üres állapotban), ezt kell egy csak-olvasható részletnézetre cserélni.

---

## C1w.3 kész (2026-08-12) — `SessionLogger` kind-kapu + olvasó cardio részletnézet

**A `kind`-kapu** (`SessionsView.tsx` aktív-session ág): `active.sessionKind === "CARDIO"` esetén
`CardioSessionDetail`, egyébként a meglévő `SessionLogger` — a "vissza a történelemhez" gomb és a
körülötte lévő váz változatlan, csak a belső komponens vált. Mivel a `SessionRow.onOpen` (C1w.2
óta) minden session típusra ugyanazt az `setActiveId(s.id)`-t hívja, egy cardio sor megnyitása
mostantól ide fut be, nem a szett-logolóba — ez zárja a lépés kész-ha feltételét.

**Tudatos, dokumentált scope-szűkítés az útvonal-SVG-re**: a lépés címe említi, de **nem
épült meg**. Az ok ugyanaz, amit a mobil `CardioSummaryScreen` saját class-doksija már kimond:
*"GPS doesn't exist anywhere in the app before C4a, so no cardio session has a route to show yet,
live or logged."* — a `cardio.routePolyline` mező létezik a DTO-ban (C1.4 óta), de **soha nem lesz
kitöltve** semmilyen ma létező session-nél, mert a kódolás formátumát maga a C4a.6 lépés
("`RoutePainter`") fogja eldönteni. Egy polyline-dekódert most megírni találgatás lenne egy még
el nem döntött formátumra — ehelyett a döntést és a munkát C4a.6-ra hagytam, ugyanígy tett a
mobil is ugyanezen indokkal. Ugyanez vonatkozik a **split-táblázatra** is (W03 frame mutatja, de a
mobil `CardioSummaryScreen` explicit módon **nem** rendereli — "the GPS route, splits, and
elevation profile are C4a.6's job") — a splitek is GPS-ből számolódnak, tehát ma egyetlen
session-nek sincs split-adata.

**Három új fájl a `web/src/features/workouts/` alatt:**
- **`cardioTiles.ts`** — `buildCardioTiles(session, t, locale)`, tiszta függvény (nincs React/DOM
  függőség), ami a családfüggő metrika-csempéket építi. **Nem** a W03 desktop-mockup teljes
  metrika-rácsát + zóna-sávját + split-táblázatát követi, hanem bitre a mobil
  `CardioSummaryScreen._metricSections` mezőválasztását — ugyanaz a session ugyanazokat a
  mezőket mutatja mindkét platformon (pl. a GAME családnál a mobil **csak egy** időtartam-csempét
  mutat "játékidő" címkével, movingSeconds-t vagy ennek hiányában bruttó időt, **nem** két külön
  csempét mozgás-/bruttó időre — ez eltér attól, amit a C1w.2-es `SessionsView` sor-összegzője
  mutat, de az szándékos: a sor a W02 frame-et követi, a részletnézet a mobil tényleges
  `CardioSummaryScreen`-jét).
- **`components/CardioSessionDetail.tsx`** — a renderelő héj: fejléc (`ActivityChip` 40px +
  aktivitás-név + dátum + RPE-jelvény, ha van + "Csak olvasható" lakat-jelvény, ami a
  [D-W.2](58-cardio-web-plan.md) döntést teszi láthatóvá), opcionális `feedbackNote` szövegsáv,
  majd a csempék `grid grid-cols-2 sm:grid-cols-3`-ban, a meglévő megosztott `StatCard`
  komponensen keresztül (nem új csempe-stílus — a dashboard/statisztika ugyanezt a komponenst
  használja, csak itt `icon`/`color`/`label`/`value` propokkal hívva).
- **`cardioTiles.test.ts`** (12 teszt) — a családonkénti mezőválasztást fedi, beleértve az M11
  "nincs távforrás → csak időtartam" szabályt, a 0 méteres táv "nincs megtévesztő 0,00 km" esetét,
  és a duration-fallback láncot (`movingSeconds` → bruttó span → `—`, ha egyik sincs). A tesztek
  identitás-fordítóval futnak (`t = (key) => key`), hogy a label-kulcsokat, ne a fordított
  szöveget ellenőrizzék — a fordítás helyessége a JSON-fájlok felelőssége, nem ezé a tesztfájlé.

**Nincs szerkesztés** (D-W.2 explicit tiltása): a `CardioSessionDetail` sehol nem hív
`workoutSessionApi.update`-et, nincs RPE-szelektor, nincs jegyzet-mező — csak megjeleníti, ami
már a session-ben van. Ez a mobil `CardioSummaryScreen`-től eltér (az ott szerkeszthető), de a
weben ez **szándékos** platform-különbség, nem hiányosság.

**Új i18n kulcsok** (`en.json`/`hu.json`, `workouts` névtér): `readOnly` +
`cardio{Duration,Distance,Pace,ElevationGain,MovingTime,PlayingTime,AvgWatts,AvgCadence,
Resistance,DeviceCalories,Venue,VenueIndoor,VenueOutdoor,Intensity,Score}Label`-szerű kulcsok,
a mobil ARB HU/EN szövegeivel egyezően (`distanceFieldLabel`, `movingTimeLabel` stb. párjai) —
normál esetben írva, nem csupa nagybetűvel, mert a `StatCard` a labelSmall-stílust (ALL CAPS,
`text-label-sm`) CSS-transzformként adja hozzá, nem a stringbe sütve.

**Ellenőrzés:** `npx tsc --noEmit` és `npx eslint` (mind az öt érintett/új fájlon) tiszta. Teljes
`npx vitest run`: **194/194 zöld** (20 fájl, 182 régi + 12 új). Böngészős ellenőrzés: a Next.js dev
szerver `/workouts` route-ja (ami a teljes új láncot — `CardioSessionDetail`, `cardioTiles`,
`SessionsView` kind-kapu — betölti) **200**-zal fordult, nulla szerver-/konzolhiba. Mint a
C1w.2-nél, a valódi böngészős megnyitás (bejelentkezett felhasználó, létező cardio session,
kattintás a sorra) ehhez a lépéshez sem volt elérhető ebben a sandboxban (nincs futó backend +
seedelt teszt-user) — ezt a `cardioTiles.test.ts` 12 teszte fedi logika-szinten.

**Következő:** `C1w.4` — edzői kliens-nézet (`ClientWorkoutsTab`) + naptár-előnézet
(`CalendarSessionPeek`) `kind`-elágazása, `recommendation.ts` cardio-szűrő, `progress.ts`
regressziós teszt. Ezzel lezárul a teljes C1w iteráció.

---

## C1w.4 kész (2026-08-12) — edzői nézet, `recommendation.ts` fix, `progress.ts` védőháló

Négy külön fél, mindegyik a maga módján zárult — az egyik valódi bug volt, az egyik hamis
riasztásnak bizonyult vizsgálat után.

### `CalendarSessionPeek.tsx` — **megvizsgálva, nem érintett** (a doc W4-es tétele téves feltevés volt)

A backendet végigkövetve: egy naptár-"occurrence" ([`WorkoutScheduleServiceImpl.toCalendarResponse`](../../backend/src/main/java/com/lifey/trainer/service/WorkoutScheduleServiceImpl.java))
egy **előre létrehozott, sablonhoz kötött** `WorkoutSession` sor (`schedule.setClientTemplate(...)`
+ `occurrence.setTemplate(clientTemplate)` a `createSchedule`-ben) — és mivel cardióra V1-ben
nincs sablon ([51 §1.1](51-cardio-overview-plan.md), a C0.4 jegyzete is megerősíti), egy
ütemezett occurrence **strukturálisan sosem lehet cardio**. A `TrainerCalendarSessionResponse` DTO
ezt tükrözi is: nincs rajta `sessionKind`/`activityType` mező, tehát nincs is mit elágaztatni.
A `templateName ?? "unnamedTemplate"` fallback, amit a doc problémásnak jelölt, valós STRENGTH-
edzéseknél fut (pl. egy törölt sablon), cardiónál soha — ez a **doc W4-es sora téves feltevés
volt**, nem egy fel nem fedezett hiba. Nincs kódmódosítás ebben a fájlban.

### `recommendation.ts` — **valódi hiba, javítva** (ugyanaz a minta, mint a mobil C0.5)

`predictNextTemplateId` a `.slice(0, 10)`-et a null-`templateId` szűrés **előtt** futtatta — egy
cardio session is kap `finishedAt`-et, tehát a "legutóbbi 10 befejezett" ablakba belefért volna,
kiszorítva a valódi (nem-null `templateId`-jű) jeleket, mielőtt azok egyáltalán szóba kerülhettek
volna. **Bitre ugyanaz a hiba**, amit a mobil `recommended_template_provider.dart` a C0.5-ben
javított (`.take(10)` a `.whereType<String>()` után, nem előtte). A javítás: a null-szűrés fut
előbb, a `.slice(0, 10)` utána. **A doc saját javaslata** (`kind === 'STRENGTH'` explicit szűrő)
**feleslegesnek bizonyult**: mivel egy cardio session `templateId`-je szerkezetileg mindig `null`
(nincs cardio sablon), a null-szűrés önmagában strukturálisan kizár minden cardio session-t —
pontosan ugyanaz a felismerés, mint a C0.5 PR-motor felénél ("a kizárás szerkezeti, védőháló
nélkül is helyes").

Új `recommendation.test.ts` (5 teszt, **a webes projekt első tesztje ehhez a fájlhoz**) — a
legfontosabb köztük a regressziós eset: egy valódi 6-elemű A/B ciklus + 8 cardio session zaj a
lista elején. **Igazolva a javítás előtti kóddal is** (ideiglenesen visszaállítva, lefuttatva,
majd visszajavítva): a régi kód `null`-t adott volna vissza, az új a helyes (zaj nélkülivel
azonos) javaslatot.

### `progress.ts` — **nincs kódmódosítás, csak védőháló** (a doc pontosan ezt kérte)

`previousSets` a `s.sets.some(set => ...)` szűrőn keresztül eleve kizár minden cardio session-t
(egy cardio session `sets`-je mindig `[]`, [52 §3.3](52-cardio-domain-backend-plan.md)) — ugyanaz
a szerkezeti védelem, mint fent. **Ezt nem feltételeztem, hanem leteszteltem** (a doc explicit
kérése): új `progress.test.ts` (5 teszt) — cardio session a történelemben nem termel hamis
"előző szettet", tisztán cardio történelem üres listát ad, és `computeWorkoutProgress` pontszáma
byte-azonos cardio-zajjal és anélkül.

### `ClientWorkoutsTab.tsx` **+ `ClientOverviewTab.tsx`** — a valódi W2-es hiba, **két helyen**

A doc csak a `ClientWorkoutsTab.tsx`-et nevezte meg, de a felderítés során kiderült: az edzői
"Áttekintés" fül `ClientOverviewTab.tsx`-ben lévő "Legutóbbi edzések" kártyája **bitre ugyanazt a
hibát** hordozza (`s.exercises[0]?.exerciseName ?? t("freeWorkout")` cím + `sessionSummary`
"{count} gyakorlat · {volume} kg volumen" alcím) — egy cardio session itt is "Free workout · 0
exercises · 0 kg volume"-ként jelent volna meg. Mivel a kész-ha ("az edző nem lát 0 gyakorlat/0 kg
volumen cardio edzést") nem egyetlen fájlra szól, mindkettőt javítottam.

Mindkét helyen ugyanaz a minta: `isCardio = s.sessionKind === "CARDIO"` elágazás,
- **cím**: `ClientOverviewTab`-ban az aktivitás-név váltja a gyakorlatnév/`freeWorkout`-fallbacket
  (itt a cím volt a hibás rész); `ClientWorkoutsTab`-ban a cím már eddig is a dátum/idő volt,
  változatlan marad,
- **alcím**: mindkét helyen az új, megosztott `buildCardioSummaryLine()` váltja a
  "gyakorlat/volumen" szöveget,
- **jelvény**: a meglévő `templateName`-pill mintáját követve, cardiónál egy aktivitás-szín/-ikon
  pill jelenik meg helyette (kölcsönösen kizáróak — cardiónak sosem lehet `templateName`-je).

**`ClientWorkoutsTab.tsx` legördítve** is kapott bővítést: a korábban teljesen üres (0 gyakorlat,
tehát semmi) kibontott panel most a meglévő, C1w.3-ban épített `buildCardioTiles()`-t hívja, és
kompakt chipekként (`label: érték`) mutatja a családfüggő metrikákat — újrahasznosított,
már tesztelt logika, nem új üzleti szabály.

### Megosztott kód — `cardioSummaryLine.ts` kiemelve

A C1w.2-ben a `SessionsView.tsx`-be írt `cardioSummaryLine` most **három helyen** kellett volna
(a sor, és a két edzői kártya) — ez lépte át azt a pontot, ahol a másolás rosszabb, mint a
kiemelés. Kiemeltem `cardioSummaryLine.ts`-be (`buildCardioSummaryLine(session, t, locale)`), a
`SessionsView.tsx` a saját nested függvényét eldobta, és mindhárom hívó ugyanazt hívja. Új,
dedikált `cardioSummaryLine.test.ts` (8 teszt) — korábban ez a logika csak közvetve, a
`cardioFormat`-teszteken keresztül volt lefedve; most a családonkénti összeállítás (beleértve a
W02 mockup pontos számait: "8.42 km · 45:16 · 5:23 /km") saját tesztet kapott.

### Ellenőrzés

`npx tsc --noEmit` és `npx eslint` (mind a kilenc érintett/új fájlon) tiszta. Teljes
`npx vitest run`: **212/212 zöld** (23 fájl, 194 régi + 18 új: 5 `recommendation.test.ts` + 5
`progress.test.ts` + 8 `cardioSummaryLine.test.ts`). Böngészős ellenőrzés: a Next.js dev szerver
`/workouts` **és** `/admin/clients/1` (ami a `ClientOverviewTab`/`ClientWorkoutsTab` teljes láncát
betölti) mindkettő **200**-zal fordult, nulla szerver-/konzolhiba. Mint az előző lépéseknél, a
valódi bejelentkezett edzői nézet (létező kliens, cardio session) nem volt elérhető ebben a
sandboxban.

**Ezzel a teljes C1w iteráció kész** — `types.ts` bővítés (C1w.1), `ActivityChip` + lista-sor
(C1w.2), olvasó cardio részletnézet (C1w.3), edzői nézet + ajánló/progresszió védőháló (C1w.4).

**Következő:** `C3w.1` (`aggregate.ts` fajta-szűrő + cardio-adatsorok + dashboard-bontás +
paritás-teszt a mobillal, a C3-mal egy időben futtatva) — vagy `C4a`/`C5` a mobil oldalon,
amelyik előbb aktuális.
