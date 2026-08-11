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
| Q-D4 | A kézzel szerkesztett metrika egyenrangú-e a mérttel a heti összesítésben | **C3.2** |

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
| **C2.2** | DISTANCE elrendezés + a **„nincs távforrás”** ág (domináns szám időre vált) | Windows | **M04**, **M11** | A domináns szám a [57 §2](57-cardio-design-prompt.md) szabálya szerint vált; nincs „0,00 km” nagy helyen |
| **C2.3** | MACHINE elrendezés | Windows | **M05** | Kadencia/teljesítmény/ellenállás bevihető menet közben |
| **C2.4** | GAME elrendezés + **pályán/padon kapcsoló** (a `movingSeconds` csak „pályán” nő) | Windows | **M06**, **M07** | A játékidő és a bruttó idő külön viselkedik (teszt); *(Q-D2 döntés kell a pontszámlálóhoz)* |
| **C2.5** | Szünet-állapotok (kézi vs. **auto-pause vizuálisan elkülönítve**) + befejezés húzással | Windows | **M08**, **M09**, **M12** | Az auto-pause más, mint a kézi; a befejezés koppintásra **nem** történik meg |
| **C2.6** | `activity_ranking.dart` — recency-súlyozott rangsor (21 napos felezés), tisztán tesztelhető | Windows | – | Felezés, döntetlen-feloldás, hidegindítás, vegyes lista mind tesztelve ([53 §3.4](53-cardio-mobile-plan.md)) |
| **C2.7** | Gyorsindító lap a FAB hosszú nyomására + „Összes” aktivitás-választó | Windows | **M01**, **M02**, **M03** | Hosszú nyomás + egy koppintás = fut az edzés, köztes képernyő nélkül |
| **C2.8** | Összegzés-képernyő (útvonal nélküli változat) + RPE + kézi szerkesztés „szerkesztve” jelöléssel | Windows | **M15**, **M14** | A szerkesztett érték felülírja a mértet, és jelölve marad ([51 R8](51-cardio-overview-plan.md)) |
| **C2.9** | `WorkoutSessionState` `kind`+`cardio` bővítés (előformázott stringek, epoch-alapú idő) | Windows | – | Régi natív build a `STRENGTH` ágra esik vissza, nem törik |
| **C2.10a** | Android tartós értesítés cardio-layout | Windows | **M25** | Nem „0 szett” látszik az Android értesítésben; frissítés csak változásra |
| **C2.10b** | iOS Live Activity + Dynamic Island cardio-layout | **Mac** | **M23**, **M24** | Nem „0 szett” látszik a zárolási képernyőn / Dynamic Islanden; frissítés ≤ 5 mp és csak változásra (ActivityKit-kvóta) |
| **C2.11a** | Deep-link route (`go_router`) + Android dinamikus app-shortcutok (`ShortcutManager`, natív híd) + Android kezdőképernyő-widget gombok | Windows | **M29** | Android app-ikon hosszú nyomásából / widgetből **egy** gesztussal indul az edzés; a route C2.11b-nek is kész célpont |
| **C2.11b** | iOS dinamikus app-shortcutok (`UIApplicationShortcutItem`, natív híd) + iOS kezdőképernyő-widget gombok | **Mac** | **M29** | iOS app-ikon hosszú nyomásából / widgetből **egy** gesztussal indul az edzés |

---

## 6. C3 — Statisztika (5 lépés) · MF4

| # | Lépés | Frame | Kész-ha |
|---|---|---|---|
| **C3.1** | Backend: repository-lekérdezések + `StatisticsResponse` additív bővítés | – | A meglévő mezők értéke **változatlan** rögzített adathalmazon (teszt) |
| **C3.2** | Mobil: `StatMetric` bővítés + **`weightedAverage`** aggregációs típus + `effectiveMinutes` szabály | – | A tempó távval súlyozott, 0 távon nem oszt nullával; erősítőnél a régi perc-szabály bitre azonos *(Q-D4 döntés kell)* |
| **C3.3** | Statisztika-képernyő: fajta-szűrő + cardio-metrikák + hiány-kezelés | **M21**, **M22** | Üres nap ≠ 0 pont ([56 D-C3.5](56-cardio-statistics-plan.md)) |
| **C3.4** | Dashboard bontás-sor + heti visszatekintő + **streak-küszöb** (15 perc mozgásidő) | – | A küszöb egyetlen konstans, tesztelve |
| **C3.5** | PR-motor cardio-ága (leghosszabb táv / mozgásidő / szintemelkedés) + edzői heti riport bővítés | – | Cardio nem termel erősítő PR-t és fordítva |

---

## 7. C1w / C3w — Web (5 lépés) · MF4

| # | Lépés | Frame | Kész-ha |
|---|---|---|---|
| **C1w.1** | `types.ts` + API-réteg átengedi az új mezőket | – | Típusok fordulnak, semmi más nem változik |
| **C1w.2** | Web `ActivityChip` + lista-sor `kind`-elágazás | **W01**, **W02** | Nincs üres cím és „· 0 szett” |
| **C1w.3** | **`SessionLogger` `kind`-kapu + olvasó cardio részletnézet** + útvonal-SVG | W02-ből származtatva | Cardio session megnyitása **nem** nyit szett-logolót ([58 W1](58-cardio-web-plan.md)) |
| **C1w.4** | Edzői kliens-nézet + naptár-előnézet `kind`-elágazása; `recommendation.ts` szűrő; `progress.ts` regressziós teszt | – | Az edző nem lát „0 gyakorlat / 0 kg volumen” cardio edzést ([58 W2](58-cardio-web-plan.md)) |
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

**Következő:** `C2.2` — DISTANCE elrendezés a `CardioSessionScreen`-en, a „nincs távforrás” ág
(a domináns szám időre vált), M04/M11 szerint.
