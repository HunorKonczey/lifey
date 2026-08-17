# 60 – Cardio sport-specifikumok: fejlesztési terv (C6–C9)

Státusz: **A design kész (2026-08-16), és a teljes C6 — az MF6a mérföldkő — leszállt (2026-08-17).**
A C6.5 watchOS-fele Macen készült el, ezzel a terv egyetlen Mac-es lépése is megvan; a C6.7
statisztika-listája az egyetlen kimaradt darab, mert nincs mit bővíteni
(ld. [§4](#4-c6--futás-specifikum-8-lépés--mf6a)). A sorrend szerint a következő iteráció a **C9 (Játék)**.
A frame-ek: [`design/Lifey Cardio Sport-specifikumok.dc.html`](design/Lifey%20Cardio%20Sport-specifikumok.dc.html),
részletes leírásuk a [61-es docban](61-cardio-sport-specifics-design-prompts.md) — **minden UI-lépés onnan dolgozik.**
Előzmény: az [59](59-cardio-implementation-plan.md)
§10 négy sorban jelöli ki a C6–C9 iterációkat — ez a doc bontja őket **prompt-méretű lépésekre**,
ugyanabban a formában (lépés · fájlok · frame · kész-ha).
Kapcsolódó: [51 §3.2–3.4](51-cardio-overview-plan.md) (metrikakészlet), [52](52-cardio-domain-backend-plan.md) (séma),
[53](53-cardio-mobile-plan.md) (mobil), [54](54-cardio-gps-route-plan.md) (GPS),
[55](55-cardio-watch-plan.md) (óra), [56](56-cardio-statistics-plan.md) (statisztika),
[57](57-cardio-design-prompt.md) (design prompt), [58](58-cardio-web-plan.md) (web),
[61](61-cardio-sport-specifics-design-prompts.md) (**a C6–C9 design leírása**).

> **Mi ez a doc, és mi nem.** Végrehajtási terv. A *miért* a fenti docokban van; itt csak
> hivatkozunk rájuk. **Egy lépés = egy beszélgetés = egy commit** — ha egy lépés nem fér el
> ennyiben, rosszul van vágva.
>
> **Ami a C0–C5-től eltér:** ott az iterációk egymásra épültek, itt **a négy iteráció független**.
> Nincs kötelező sorrend köztük, és bármelyik kihagyható anélkül, hogy a többi sérülne. Ezért itt
> nincs „MF6" egy blokkban: **iterációnként külön szállítható mérföldkő** (MF6a–MF6d).

---

## 1. Kiindulási állapot (mi van már kész)

A C0–C5 leszállt, tehát a sport-specifikumok **nem nulláról indulnak**. Amit építeni lehet rá:

| Ami kész | Hol | Mit ad a C6–C9-nek |
|---|---|---|
| `cardio_details` **összes oszlopa** (kadencia, watt, ellenállás, HR-zónák, box score, venue, formátum, hátizsák nélkül) | `V67__cardio_details.sql` | A C7 és C9 mezőinek **nagy része már létezik** — csak nincs bekötve UI-ba |
| `cardio_splits` tábla + kliens-oldali km-split számítás | `V68__cardio_splits.sql`, `domain/cardio_splits_calculator.dart` | A C6 tempó-diagramja **kész adaton** dolgozik |
| Szűrt GPS-nyomvonal lokálisan (`CardioTrackPoints`), polyline szinkronizálva | `data/cardio_track_point_repository.dart`, `domain/route_encoder.dart` | A C6 legjobb-résztáv és a C8 magasságprofil forrása |
| Split-lista + magasságprofil (leegyszerűsített) az összegzésen | `presentation/cardio_summary_screen.dart` | Bővítendő, nem újraírandó |
| `TimeSeriesChart` (saját festés, nincs `fl_chart`) | `shared/widgets/charts/time_series_chart.dart` | A tempó- és magasságprofil-diagram alapja — **nem kell új chart-függőség** |
| Cardio PR-motor 3 rekordtípussal | `domain/cardio_personal_record.dart` | A C6/C7 új rekordtípusai ugyanide jönnek (a fájl doc-kommentje már utal rájuk) |
| Ellenállás-léptető a MACHINE élő képernyőn | `presentation/cardio_session_screen.dart:1360` | A C7 intervallum-lejátszója mellé kerül |
| Óra-összegzés zónákkal, standalone cardio, pályán/padon szinkron | C5.7a/b | A C9 zóna-panelének **adatforrása kész** |

**Két dolog, ami látszik késznek, de nem az:**

1. **A HR-zóna oszlopok végig-vezetve, de sehol nem jelennek meg** (`hrZone1Seconds` … a
   `pull_engine`-től a domainig megvan, UI nincs) — ez a **C9.1** tényleges munkája.
2. **A magasságprofil az összegzésen ma nem valódi profil**: a polyline nem hordoz időbélyeget,
   ezért a jelenlegi diagram csak a szintemelkedésből rajzolt közelítés
   (`cardio_summary_screen.dart:478` kommentje ezt le is írja). A **C8.3** ezt cseréli le valódi,
   táv-tengelyes profilra a lokális nyomvonalból.

---

## 2. Két blokkoló, amit a kódolás előtt le kell zárni

### 2.1 Design: **FELOLDVA (2026-08-16)** — a C6–C9 canvas elkészült

A sport-specifikus felületek megvannak:
[`design/Lifey Cardio Sport-specifikumok.dc.html`](design/Lifey%20Cardio%20Sport-specifikumok.dc.html)
— **M33–M45** + állapot-kivágatok + világos/angol minták. **A frame-ek részletes leírása
(elrendezés, tokenek, állapotok, indoklás) a [61-es docban](61-cardio-sport-specifics-design-prompts.md)
§1–§5 — a UI-lépések onnan dolgoznak, nem a canvas HTML-jéből.**

Amit a design menet közben eldöntött, és ezzel megszűnt blokkolónak lenni: a **split-sor mélysége**
(táv + tempó + szint, pulzus nélkül), a **splitek nem szerkeszthetők** kézzel, az **intervallum
három intenzitás-fokozattal** megy, a **box score rejtve indul** egyszeri felajánlással, és a
**zóna-panel minden típusra** vonatkozik, csak a sorrendje családfüggő. A teljes lista, a design
indoklásaival: [61 §6](61-cardio-sport-specifics-design-prompts.md).

*(Eredeti állapot, a kör előtt: a canvas csak M01–M32-t fedte le, a sport-specifikumokra egyetlen
frame sem volt az M16 — túra-magasságprofil — kivételével.)*

A `x.0` design-lépések ezzel **lezárva**; a prompt-napló és a leszállított design leírása egyaránt
a [61-es docban](61-cardio-sport-specifics-design-prompts.md) van.

| Iteráció | Leszállított frame-ek | Részletes leírás |
|---|---|---|
| C6 | **M33** tempó-diagram + split-lista · **M34** legjobb résztávok · **M35** km-visszajelzés lap · **M36** több rekord = egy ünneplés | [61 §2](61-cardio-sport-specifics-design-prompts.md#2-c6--futás--m33m36) |
| C7 | **M37** intervallum-szerkesztő · **M38** lejátszó az M05-ön · **M39** összmunka + szakaszok + kétoldalas kalória-kártya | [61 §3](61-cardio-sport-specifics-design-prompts.md#3-c7--szobabicikli--m37m39) |
| C8 | **M40** valódi magasságprofil (hézag-sáv, csúcs, readout) · **M41** útpont-jelölés · **M42** terep + hátizsák + időjárás + útpont-lista | [61 §4](61-cardio-sport-specifics-design-prompts.md#4-c8--túra--m40m42) |
| C9 | **M43** zóna-panel · **M44** box score léptető · **M45** formátum/helyszín/kültéri mód | [61 §5](61-cardio-sport-specifics-design-prompts.md#5-c9--játék--m43m45) |

### 2.2 Nyitott döntések — a design után

A designer nyolc kérdést adott vissza javaslattal ([61 §6](61-cardio-sport-specifics-design-prompts.md)),
és közben hármat le is zárt. Ami **még döntést igényel**:

| # | Kérdés | Blokkolja | A design javaslata |
|---|---|---|---|
| **Q-D1** ✅ | Split-mélység | – | **Eldöntve designban:** táv + tempó + szint, **pulzus nélkül** (négy szám 390 px-en 10,5 px-es tipográfiát kényszerítene). Kézi split-javítás **nincs**; a session-táv szerkesztésekor a splitek **arányosan újraszámolódnak** |
| **Q-D2** ✅ | A box score alapból látszik-e | – | **Eldöntve designban (M44):** rejtve, egyszeri felajánlással, véglegesen elutasíthatóan |
| **Q-C6.1** ✅ | Hangos (beszélt) km-visszajelzés | – | **Eldöntve designban (M35):** most nem épül, a helye szaggatott „hamarosan" sorként megvan. Rezgés + rövid csengő igen |
| **Q-D3** | Az intervallum cél-intenzitás skálája | C7.4 | **Három fokozat**; ha a gép ad wattot, opcionális watt-sáv ugyanabban a sorban („kemény · 200–230 W") |
| **Q-D4** | Hang a szakaszváltásra | C7.5 | **Legyen, kikapcsolhatóan** (a bicikli mellett zene szól, a rezgést a kormánytartó elnyeli) — az M35 kapcsolópár-mintájával |
| **Q-C7.1** | Az intervallum-terv külön entitás-e | C7.1 | Külön entitás (`cardio_interval_plans`) — nem designkérdés, ld. D-C7.1 |
| **Q-D6** | A max magasság hova tartozik | C8.3/C8.5 | **Mindkettő** (profil-marker + metrika-rács) — a degradált nézetben csak a rács marad |
| **Q-C8.1** | Időjárás-forrás (külső API vs. kézi) | C8.6 | **A design nem dönti el** — a kártya és a „nincs adat" állapot kész (M42). Javaslat változatlanul: külső API, külön utolsó lépésként |
| **Q-D5** | Útpont-címke utólag | C8.4 (V2) | V1-ben nincs beviteli mező; a címke a **következő körre**, az összegzés listáján helyben szerkeszthetően. Élőben **soha** ne kelljen gépelni |
| **Q-D7** | A zóna-panel minden cardióhoz? | C9.1 | **Igen**, ahol van zóna-adat — egy komponens; a **sorrend** típusfüggő (DISTANCE: splitek után, GAME: a domináns szám után) |
| **Q-D8 / Q-C9.1** | Sprint-szám kültéri GAME-nél | C9.4 | **Most ne.** Ha bekerül: egy szám a rácsban („14 sprint"), nem diagram |

---

## 3. Sorrend

Nincs kemény függés a négy iteráció között. Az ajánlott sorrend **érték/költség** alapján:

| Sorrend | Iteráció | Miért itt |
|---|---|---|
| 1. | **C6 – Futás** | A legnagyobb felhasználói érték, a legtöbb adat **már megvan** (splitek, nyomvonal), és a design minden kérdését lezárta — nincs mire várni |
| 2. | **C9 – Játék** | A legolcsóbb: minden oszlop létezik, az óra már küld zónát — szinte tiszta UI-munka |
| 3. | **C7 – Bicikli** | A legnagyobb új felület (intervallum-motor: új tábla, új szerkesztő, új lejátszó) |
| 4. | **C8 – Túra** | Külső API-döntést és új számítási képletet (GAP) igényel |

**Nyitott döntést egyik sem vár** a C6 és a C9 közül: a Q-D1/Q-D2/Q-C6.1 eldőlt a designban. A C7 a Q-D3/Q-D4-re, a C8 a Q-C8.1-re vár — de mindkettőnél csak az érintett lépés (C7.4/C7.5, C8.6), a többi indulhat.

### 3.1 Mérföldkövek

| MF | Mit lát a felhasználó | Lépések |
|---|---|---|
| **MF6a** | Futás után tempó-diagram, splitek, legjobb 1/5/10 km, futás-PR-ok, km-visszajelzés futás közben | C6.0–C6.7 |
| **MF6b** | Meccs után pulzuszóna-eloszlás, opcionális box score, formátum/helyszín; kültéren táv | C9.0–C9.5 |
| **MF6c** | Szobabiciklin strukturált intervallum-edzés, összmunka (kJ), külön gép-kalória | C7.0–C7.6 |
| **MF6d** | Túrán valódi magasságprofil, útpontok, GAP, hátizsák-súly, időjárás | C8.0–C8.6 |

### 3.2 Platform

**A 30 lépésből egyetlen egy igényel Mac-et: a C6.5 watchOS-fele.** Minden más Windowson
fejleszthető és tesztelhető — a backend (Java/Maven), a teljes Flutter/Dart réteg és a **Wear OS**
natív oldala (Kotlin/Compose) is.

| Lépés | Platform | Miért |
|---|---|---|
| **C6.5** | **megosztott** | A kadencia megjelenítése az órán natív munka mindkét platformon: a **Wear OS fele Windowson** megy, a **watchOS fele Mac-et igényel** (SwiftUI, `mobile/ios/LifeyWatch/`) — ugyanaz a vágás, mint a C5.7a/b-nél. **Állapot (2026-08-17): mindkét fél kész — a watchOS-fél Macen leszállt** |
| **C9.1** | Windows | A zóna-panel **tiszta Dart**: a zóna-adatot az óra a C5.7 óta már küldi, itt csak megjelenítés van *(korábban tévesen Mac-esként szerepelt)* |
| minden más C6–C9 lépés | Windows | Backend-migrációk, Drift/repository, Flutter UI, saját festésű diagramok |

**Eszközös próba** (nem fejlesztőgép, hanem készülék kell hozzá): a **C7.5** intervallum-lejátszó
30+ perces háttér-drift próbája — Android telefonon Windowsról elvégezhető, iOS-en Mac kell.

A teljes, C0–C9-re kiterjedő platform-mátrix és a besorolás szabálya:
[59 §2.2](59-cardio-implementation-plan.md).

---

## 4. C6 — Futás-specifikum (8 lépés) · MF6a

**Függés:** C4a (nyomvonal), Q-D1.

| # | Lépés | Fájlok | Frame | Kész-ha |
|---|---|---|---|---|
| **C6.0** ✅ | Design: futás-frame-ek | [61 §2](61-cardio-sport-specifics-design-prompts.md#2-c6--futás--m33m36) | **M33–M36** | **Kész (2026-08-16)** — a canvasban M33–M36 + állapot-kivágatok + M33 light/EN minta |
| **C6.1** ✅ | Backend: **V69** — `cardio_details` + `best_1k_seconds`, `best_5k_seconds`, `best_10k_seconds`; DTO + mapper + validáció (nem-negatív, `best_1k ≤ best_5k ≤ best_10k`) | `db/migration/V69__cardio_best_efforts.sql`, `session/cardio/CardioDetails.java`, `session/dto/CardioDetailsRequest.java`, `CardioDetailsResponse.java`, `WorkoutSessionMapper.java`, `session/service/WorkoutSessionServiceImpl.java` | – | **Kész (2026-08-16)** — a mezők nullable-ok, a régi kliens payloadja változatlanul átmegy és a hiányzó érték `null`, nem 0; a monotonitást a service **páronként** ellenőrzi (a hiányzó 5 km-es sem enged át lehetetlen 1k/10k párost) → 400, a `cardio_details_best_efforts_monotonic_ck` pedig DB-szintű háló |
| **C6.2** ✅ | Mobil domain: `best_effort_calculator.dart` — **csúszóablak** a szűrt nyomvonalon 1/5/10 km-re, interpolált ablakhatárral (a `cardio_splits_calculator.dart` mintájára) | `features/workouts/domain/best_effort_calculator.dart` (új) | – | **Kész (2026-08-16)** — 10 unit-teszt: ritka nyomvonal · szünet a nyomvonalban (60 s alatt nem hézag, és az idejét az ablak megfizeti) · a session rövidebb az ablaknál → `null` · GPS-hézag → a nyomvonal ott **kettévágódik** (a §4.3-as 60 s-os küszöbbel, ugyanaz a szabály, mint a `route_encoder`-ben), így az ablak nem nyúlhat át rajta · a 10 km-es sosem gyorsabb tempójú, mint az 1 km-es |
| **C6.3** ✅ | Zárás-bekötés: a best-effort ugyanott számolódik, ahol a splitek; drift-oszlopok + repository + payload + `pull_engine` | `core/local_db/tables/workout_session_tables.dart` (+ **drift séma 37**), `data/workout_session_repository.dart`, `domain/workout_session.dart`, `presentation/cardio_session_screen.dart`, `core/sync/pull_engine.dart` | – | **Kész (2026-08-16)** — a `_finish()` ugyanabból a `trail`-ből és ugyanabban az outbox-írásban számolja, mint a spliteket; a három érték a drift-soron, a payloadon és a pullon is átmegy; 1 km alatti futásnál mindhárom `null`, nem 0 (widget-teszt). A `workout_session_controller` nem igényelt változást — a `CardioMetrics` már végig-vezette a mezőket |
| **C6.4** ✅ | Összegzés: **tempó-oszlopdiagram** (nem terület — ld. [61 §2](61-cardio-sport-specifics-design-prompts.md)) + split-sor **táv + tempó + szint** mélységgel | `presentation/cardio_summary_screen.dart`, `shared/widgets/charts/pace_bar_chart.dart` (új), `l10n/` | **M33** | **Kész (2026-08-16)** — a diagram és a lista ugyanazt a `session.splits`-et kapja (teszt hasonlítja a kettőt); a kiválasztás **egy állapot a képernyőn**, ezért a sor és az oszlop együtt világít; 1 splitnél nincs diagram; a részleges utolsó split **szürkén megjelenik, de kimarad az értékelésből** (skála, átlagvonal, „leggyorsabb" felirat) — ld. a lenti megjegyzést. Szintadat nélkül a kártya **egyszer** mondja ki, nem soronként üres oszlop |
| **C6.5** ✅ | **Kadencia** bekötése: óráról érkező `avgCadence`/`maxCadence` megjelenítése (csak futásnál), Wear OS + watchOS oldal | `presentation/cardio_summary_screen.dart`, `android/wear/.../ExerciseService.kt`, `mobile/ios/LifeyWatch/WorkoutManager.swift`, `StandaloneSessionPayload.swift` | **M33** | **Kész (2026-08-17)** — a telefon-fél és a **Wear OS-fél** aznap, a **watchOS-fél** ugyanaznap Macen: a futás-összegzés `spm`-ben mutatja a kadenciát, és csak akkor, ha a szenzor tényleg küldte; séta/túra sosem, a szobabicikli `rpm`-je változatlan. A watchOS-oldal **nem talált kész kadencia-adattípust** a HealthKitben, ezért lépésszámból származtat — ld. a lenti megjegyzést |
| **C6.6** ✅ | **Km-visszajelzés** futás közben: rezgés + rövid csengő külön kapcsolóval; a beszélt sor **szaggatott, „hamarosan”** állapotban | `application/km_cue_controller.dart` (új), `application/km_cue_preferences.dart` (új), `presentation/widgets/cardio_session_settings_sheet.dart` (az `auto_pause_settings_sheet` átnevezve+bővítve), `presentation/cardio_session_screen.dart`, `l10n/` | **M35** | **Kész (2026-08-17)** — **auto-pause alatt nem üt** (teszt: 500 m után auto-szünet, majd 660 m sodródás → egyetlen jelzés sem); a beszélt sor **szaggatott kerettel, kapcsoló nélkül**; a lap a mértékegységet **magyarázza, nem állítja**. A háttér/zárolt képernyő **szerkezetileg adott** (a jelzés a GPS-fix-folyamról jön, aminek már van háttér-kézbesítése), de **eszközön nincs próbálva**. A csengő a platform saját hangja — ld. a lenti megjegyzést |
| **C6.7** ✅ | **Futás-PR-ok**: `CardioPrType` bővítés `fastest1k` / `fastest5k` / `fastest10k` + baseline + **egy** ünneplő dialógus + statisztika-lista | `domain/cardio_personal_record.dart`, `presentation/cardio_summary_screen.dart`, `presentation/cardio_session_screen.dart`, `l10n/` | **M34**, **M36** | **Kész (2026-08-17)** — csak futás termel ilyen PR-t (séta/túra a baseline-ba sem kerül be, teszt); **négy rekord = egy dialógus, egy haptika, egy lista**, soronként az előző értékkel és dátummal; a nem létező résztávok **egyáltalán nem** jelennek meg. A statisztika-lista **elmaradt** — ld. a lenti megjegyzést |

> ### ✅ C6.5 — a watchOS-fél leszállt (2026-08-17, Macen)
>
> **A telefon- és Wear OS-oldal** (aznap korábban): `cardio_summary_screen.dart` — a futás
> metrika-rácsa `spm`-ben mutatja a kadenciát, kizárólag `RUNNING`-nál és kizárólag ha érkezett
> érték; `ExerciseService.kt` — `DataType.STEPS_PER_MINUTE_STATS`, **csak `RUNNING`-ra kérve**, az
> átlag és a max a záró `cardio` JSON-be `avgCadence`/`maxCadence` kulcsokkal. A merge-út nem
> igényelt változtatást: a `CardioMetrics.fromJson` + `mergedWithWatchMeasurement` már végig-vezette
> a két mezőt — ezt teszt is rögzíti (`cardio_metrics_watch_merge_test.dart`), és ezzel a kulcsnevek
> **mindkét óra-platform felé** le vannak szegezve.
>
> *(A terv `application/watch_session_merge.dart`-ot sorolt fel; az a fájl a STRENGTH gyakorlat/
> szett-egyeztetésé, a cardio-metrikák nem érintik.)*
>
> **A watchOS-fél** (`WorkoutManager.swift`, `StandaloneSessionPayload.swift`) — és egy meglepetés,
> amit a terv rosszul feltételezett: **a HealthKitben nincs futó-kadencia adattípus.** A
> `HKQuantityTypeIdentifier` kerékpáros oldala kapott egyet (`.cyclingCadence`), a futó oldal csak
> lépéshosszt, teljesítményt, sebességet és a két formametrikát — `.runningCadence` nem létezik,
> tehát a Wear OS-en készen kapott átlag/max párt itt **származtatni kell** a `HKLiveWorkoutBuilder`
> által gyűjtött lépésszámból (`.stepCount`, ami a futó konfiguráció alapértelmezett gyűjtött
> típusai közt sincs benne — explicit `enableCollection(for:predicate:)` kell hozzá).
>
> A származtatás **csúszó, legalább 10 másodperces ablakokkal** megy (`cadenceWindowSeconds`):
> a **max** a leggyorsabb lezárt ablak, az **átlag** pedig időarányosan súlyozott az összes lezárt
> ablakon (össz-lépés / össz-másodperc), nem az ablakütemek számtani közepe. A 10 s azért kell, mert
> a HealthKit apró adagokban adja a lépésmintákat, és egy-két másodpercen a lépésszám durván
> kvantál: 1 s alatt 3 lépés = 180 spm, 4 lépés = 240 — a nyers tikkenkénti ütem olyan számot írna a
> `maxCadence`-be, amit a futó soha nem futott. Szünetnél a nyitott ablak **eldobódik** (a
> `HKWorkoutSessionDelegate` állapotváltásán), különben az álldogálás lassú futásként pontozódna.
> A folyamathalál utáni visszaállás (`recoverStandaloneSessionIfNeeded`) az átlagot a visszakapott
> builder kumulált lépésszámából + `elapsedTime`-jából **újraveti** — ugyanaz a néma-hiba védelem,
> mint a C5.7b távolságánál; a max ilyenkor a visszaállás utáni ablakokból indul újra.
>
> A **`RUNNING`-gate** a `HKWorkoutConfiguration.activityType == .running`-on ül, nem a
> `cardioActivityType` sztringen: telefon-vezérelt session-nél az utóbbi még `nil` lehet, amikor a
> `startSession` fut (a `PhoneConnector` kontextusa később is érkezhet). Séta/túra/bicikli/játék így
> **nem is kér lépésszámot**, ugyanaz a vágás, mint Wear OS-en.
>
> **Egy néma hibát menet közben javítani kellett:** a `requestAuthorizationIfNeeded()` eddig csak a
> pulzust és az aktív kalóriát kérte olvasásra — a **távolság-típusok nem szerepeltek benne**, pedig
> a C5.7b `cardioSummaryPayload()`-ja azokat olvassa vissza a builderből. A HealthKit a soha nem kért
> olvasási típusra **nem hibázik, hanem hallgat**, tehát ez nem elszállt, csak örökre üres mezőt
> jelentett volna — és mivel a kadencia ugyanabban a blokkban utazik (`guard … let lastDistanceMeters`),
> a kadenciát is megette volna. A `distanceWalkingRunning`, `distanceCycling` és az új `stepCount`
> most mind a `typesToRead`-ben van. Ennek ára, hogy a HealthKit **egyszer újra megkérdezi** az
> engedélyeket a következő indításnál — ez az elvárt viselkedés új adattípusnál.
>
> **Fordítás:** a `LifeyWatch` target lefordítva a watchOS szimulátorra
> (`xcodebuild -project Runner.xcodeproj -target LifeyWatch -sdk watchsimulator` → BUILD SUCCEEDED),
> plusz `swiftc -typecheck` a teljes `LifeyWatch/` forráskészletre. A `cardio_metrics_watch_merge_test.dart`
> zöld — a Swift most írt kulcsnevei ugyanazok, amiket az a teszt leszegez.
>
> *(Buktató a Mac-es indulásnál: a `LifeyWatch` **séma** a `Runner` targeten keresztül a
> Flutter-buildet is meghajtja, az pedig elhasalt a gépen lévő elavult, gitignore-olt
> drift-generáltakon — `app_database.g.dart`-ból hiányzott a C6.3 séma 37 `best1k/5k/10kSeconds`
> hármasa. Nem repó-hiba, csak friss checkout: egy `dart run build_runner build` rendezi.)*
>
> ### ⏳ C6.7 — a „statisztika-lista" ELMARADT (nincs mit bővíteni)
>
> A lépés fájllistája `features/statistics/application/stat_summary_data.dart`-ot említ, de **abban
> nincs rekord-lista**: az a fájl a kiválasztott metrika/tartomány diagram-pontjait összegzi (összeg,
> átlag, min, max, trend). A **statisztika-képernyőn ma egyáltalán nincs PR-lista** — se cardio, se
> erősítő —, tehát nem bővítésről lenne szó, hanem egy új felületről; az **nem fér ebbe a lépésbe**,
> és a design sem ad rá frame-et (az M34 az *összegzésre* való). A rekordok tehát **az összegzésen
> látszanak** (legjobb-résztávok kártya + a meglévő rekord-sáv), a statisztikai lista külön tétel.
>
> **Amit a C6.7 megvalósítása eldöntött:**
> - A `CardioPrBaseline` mostantól **értéket és dátumot** tárol típusonként (`CardioPrBest`), mert az
>   M36 sorai a lecserélt rekordot dátummal nevezik meg. A régi olvasó getterek (`maxDistanceMeters`
>   stb.) megmaradtak, így a korábbi hívók változatlanok.
> - Az M34 „hol volt" alcíme (**„a 7,1–8,1 km szakaszon"**) **nem valósult meg**: a C6.1 séma csak a
>   *másodperceket* tárolja, az ablak kezdő-offsetjét nem — az külön oszlop(ok) és migráció lenne.
>   Helyette az M36 saját alcíme szerepel: **„a nyomvonalon számolva"**. Ha kell, a `computeBestEfforts`
>   könnyen visszaadhatná az offsetet is, de tárolni kell hozzá.
> - Az M36 **„Összegzés megnyitása"** gombja kimaradt: a dialógus *az összegzésen* nyílik, nincs hova
>   navigálnia. Egy gomb maradt (Bezárás).
> - A résztávok **méter-alapúak maradnak mérföldes profilon is** (1/5/10 km), mert a rekord maga van
>   így definiálva (`best_1k_seconds`); a *tempó* viszont a profil egységében jelenik meg.
> - A rekord-sor **borostyán pirulája a felirat sorába került**, nem az idő mellé: 360 px-en az idő +
>   pirula + tempó nem fér ki egy sorba (a widget-teszt 400 px-en tényleges overflow-t fogott), és egy
>   levágott rekord-idő rosszabb, mint egy sorral lejjebb tett pirula.
>
> **C6.6 — a csengő a platform saját hangja.** A rezgés teljes értékű (`HapticFeedback`, két rövid
> koppintás az M35 szerint). A **hang** viszont `SystemSound.play(SystemSoundType.alert)` — a platform
> beépített figyelmeztető hangja, **nem** csomagolt hangminta. Az M35 szövege („Rövid csengő, **a zene
> alatt**”) saját mintát ír le, ami a zene alá keveredik: ahhoz audio-session kategória és
> lejátszó-csomag kell (`audioplayers`/`just_audio`), a `CLAUDE.md` viszont tiltja az indoklás nélküli
> új függőséget — **ez a döntés nem ezé a lépésé**. A kapcsoló és a teljes vezetékezés kész: ha a
> csomag bekerül, csak a `_playKmCue()` hang-ága cserélődik.
>
> **Amit a C6.6 megvalósítása még eldöntött:**
> - A lap **átnevezve** `AutoPauseSettingsSheet` → **`CardioSessionSettingsSheet`**: az M35 szerint az
>   auto-pause **ebben a lapban** az első sor, tehát a lap két dologról szól — nem helyes az egyikről
>   elnevezni.
> - A szekció-fejléc **`TÁV-VISSZAJELZÉS`**, nem „kilométer-visszajelzés”: mérföldes profilnál a
>   kilométeres fejléc hazudna. Hogy melyik van érvényben, azt a lap záró magyarázó sora mondja ki.
> - A jelzés a **teljes DISTANCE-családra** vonatkozik (séta/túra is), nem csak futásra: a lépés címe
>   futást mond, de semmi nem futás-specifikus benne — szemben a kadenciával (C6.5), ahol a megkötés
>   indokolt.
> - A **háttér/zárolt képernyő** szerkezetileg adott (a jelzés a GPS-fix-folyamról jön, aminek a C4a.5
>   óta van háttér-kézbesítése), de **eszközön nincs próbálva** — widget-tesztből nem igazolható.
>
> **C6.4 — a részleges split kezelése.** A fenti kész-ha „nem kap oszlopot"-ot mond, a
> [61 §2 M33](61-cardio-sport-specifics-design-prompts.md) viszont „**szürke** (`3C3E32`) és nem kap
> saját oszlopot **az értékelésben**". A megvalósítás a 61-est követi (a §1 szerint a UI-lépések
> onnan dolgoznak, és a design színt is ad neki — amit csak kirajzolt oszlopnak lehet adni): a
> részleges sáv **látszik**, de nem kerül be a skálába, az átlagvonalba és a „leggyorsabb" feliratba.
> Ez a lényegi védelem: a 200 m-es maradék a *legrövidebb idő* a listában, tehát pontozva ő lenne a
> futás „leggyorsabb szakasza", és minden valódi kilométert összenyomna.
>
> **A `PACE` fejléc helyett `PACE PER SPLIT`:** ugyanezen a képernyőn a metrika-rács már címkéz egy
> „PACE" értéket (a session átlagtempóját), és két azonos fejléc ugyanazt a számot ígérné kétszer.
> A mértékegység az alatta lévő átlag-soron látszik.

**Elfogadás (MF6a)**

- [x] Egy 7 km-es futás után a „legjobb 5 km" **nem** az átlagtempóból számolt érték ([56 D-C3.8](56-cardio-statistics-plan.md)) — `best_effort_calculator_test.dart`: a csúszóablak a leggyorsabb szakaszt találja meg, nem az átlagot
- [x] A tempó-diagram és a split-lista minden során ugyanaz a tempó szerepel — a kettő **ugyanazt a `session.splits`-et** kapja (`cardio_summary_screen_test.dart` összehasonlítja)
- [x] GPS nélküli (futópad) futás minden C6-felülete elrejtve, nem üres kártyaként látszik — nyomvonal nélkül nincs diagram/split-kártya, best-effort nélkül nincs résztáv-kártya (tesztek)
- [x] Erősítő session nem termel futás-PR-t, és fordítva — `cardio_personal_record_test.dart`; a két PR-motor szerkezetileg külön ([59](59-cardio-implementation-plan.md) C3.5)

---

## 5. C9 — Játék-specifikum (6 lépés) · MF6b

**Függés:** C5 (a zónák az óráról jönnek), Q-D2.
**Backend-munka nincs** — a `cardio_details` GAME-oszlopai és a HR-zóna oszlopok a V67-ben már
léteznek, a DTO végig-vezeti őket. Ez a legolcsóbb iteráció.

| # | Lépés | Fájlok | Frame | Kész-ha |
|---|---|---|---|---|
| **C9.0** ✅ | Design: játék-frame-ek | [61 §5](61-cardio-sport-specifics-design-prompts.md#5-c9--játék--m43m45) | **M43–M45** | **Kész (2026-08-16)** — a canvasban M43–M45 + állapot-kivágatok + M43 light/EN minta |
| **C9.1** | **Pulzuszóna-panel**: 22 px halmozott sáv + „kemény / kiegyensúlyozott / könnyű meccs" chip + 5 sor (zóna · név · idő · %) a meglévő `hrZone1..5Seconds`-ből | `presentation/cardio_summary_screen.dart`, `core/format/cardio_formatter.dart`, `l10n/` | **M43** | **Egy komponens minden cardio-típusra** (Q-D7), csak a helye családfüggő: DISTANCE-nál a splitek után, GAME-nél a domináns szám után. Az öt zóna összege **sosem haladja meg a bruttó időt** (őr + teszt); adat nélkül a panel **eltűnik**, részlegesnél a hiányzó rész sraffozott; a **szám mindig teljes kontrasztú**, a szín csak a címkén és a kis sávon |
| **C9.2** | **Box score léptető** (pont/gól · gólpassz · lepattanó) az élő GAME képernyőn a Q-D2 szerint: alapból rejtve, egyszeri felajánlással; az összegzésen és a kézi lapon szerkeszthető | `presentation/cardio_session_screen.dart:1386` (a ma szándékosan üres GAME-elrendezés), `presentation/cardio_summary_screen.dart`, `presentation/log_cardio_sheet.dart` | **M44** | A felajánlás **egyszer** jelenik meg és megjegyzi a választ; a léptetőt a **jobb alsó „Box” kör** nyitja, és **6 s tétlenség után magától becsukódik**; a `+` **1,4× szélesebb**, mint a `−`; a pályán/padon kapcsoló mérete és helye **nem változik**; a léptető nem nyúl a `movingSeconds`-hoz; kosár 3, foci 2 oszlop |
| **C9.3** | **Formátum + helyszín** választó: `gameFormat` (5v5 / kispálya / edzés / meccs) és `venue` a gyorsindításnál és az összegzésen | `presentation/quick_start_sheet.dart`, `presentation/activity_picker_screen.dart`, `presentation/cardio_summary_screen.dart`, `l10n/` | **M45** | A lap **nem blokkolja az indítást** (minden mezőnek van alapértéke: a legutóbbi választás); a formátum-választó **2×2 segmented** (magyarul egy sorban nem fér ki); a `venue` továbbra is **egy** helyről vezérli a GPS-t és a watch `locationType`-ot (C5.2) |
| **C9.4** | **Kültéri GPS-mód** GAME-hez: opt-in `venue == OUTDOOR` esetén táv-rögzítés (+ sprint-szám, ha a Q-C9.1 eldőlt) | `application/` GPS-vezérlés, `presentation/cardio_session_screen.dart`, `domain/track_filter.dart` | **M45** | Teremben **nincs GPS-sor, nincs engedélykérés, és az összegzésen sincs táv** — „nem letiltva, hanem nem létezik” (akku-teszt); kültéren a kapcsoló alatt ott a **mit kapok / mit nem** ígéret, mert a tempó hiányát itt kell kimondani ([51 §3.4](51-cardio-overview-plan.md)) |
| **C9.5** | Statisztika: zóna-idő mint metrika + a GAME-fajta szűrése | `features/statistics/application/stat_chart_data.dart`, `stat_summary_data.dart` | – | A meglévő `StatMetric` értékek számai **bitre változatlanok** (regressziós teszt, [59 §11](59-cardio-implementation-plan.md)) |

**Elfogadás (MF6b)**

- [ ] Óra nélküli meccs is teljesen használható (zóna-panel nélkül), semmi nem üres folt
- [ ] A box score kikapcsolható és a kikapcsolt állapot marad
- [ ] Termi meccs alatt nulla GPS-fogyasztás

---

## 6. C7 — Szobabicikli-specifikum (7 lépés) · MF6c

**Függés:** C2 (élő cardio), Q-C7.1. GPS-től **független** — C4a nélkül is szállítható.

### D-C7.1 — Az intervallum-terv külön entitás, a végrehajtás pedig a `cardio_splits`-be megy

A **terv** (újrahasznosítható, felhasználóhoz kötött: „4×4 perc kemény / 3 perc könnyű") saját
tábla. A **végrehajtás** viszont nem érdemel harmadik táblát: a `cardio_splits` már pont ezt a
formát tárolja (index + időtartam), csak egy típus- és egy watt-oszlop hiányzik belőle. Ezzel az
összegzés split-listája **változtatás nélkül** meg tudja jeleníteni az intervallumokat is.

| # | Lépés | Fájlok | Frame | Kész-ha |
|---|---|---|---|---|
| **C7.0** ✅ | Design: bicikli-frame-ek | [61 §3](61-cardio-sport-specifics-design-prompts.md#3-c7--szobabicikli--m37m39) | **M37–M39** | **Kész (2026-08-16)** — a canvasban M37–M39 + állapot-kivágatok + M38 light/EN minta |
| **C7.1** | Backend: **V70** — `cardio_interval_plans` + `cardio_interval_steps` (felhasználóhoz kötve, CLAUDE.md), plusz `cardio_splits` + `split_type` (`DISTANCE` \| `INTERVAL`) és `avg_watts` | `db/migration/V70__*.sql`, `session/cardio/`, `session/dto/CardioSplitRequest.java`, `CardioSplitResponse.java` | – | A meglévő splitek `DISTANCE`-ra migrálódnak; a C6 split-listája **változatlanul működik** (teszt) |
| **C7.2** | Backend: terv-CRUD végpont + delta-sync bekötés | `session/cardio/`, `session/service/WorkoutSessionServiceImpl.java` vagy új `cardio/interval/` csomag, Postman | – | A terv törlése **nem** törli a vele futott session-öket; minden terv szigorúan user-scope-os (teszt idegen userrel) |
| **C7.3** | Mobil adatréteg: drift-táblák + repository + outbox a tervekhez | `core/local_db/tables/`, `features/workouts/data/`, `core/sync/pull_engine.dart` | – | Terv offline létrehozható és átszinkronizál; a `STRENGTH` payload továbbra is bájtra azonos |
| **C7.4** | **Intervallum-szerkesztő** UI (szakaszok: idő + cél-intenzitás, ismétlés, mentés névvel) | `presentation/interval_plan_editor_screen.dart` (új), `l10n/` | **M37** | Egy 4×(4+3) perces terv 6 koppintásból összeáll; a teljes hossz élőben látszik |
| **C7.5** | **Lejátszó** az élő MACHINE képernyőn: szakasz-számláló, visszaszámláló, „utána” előnézet, kemény szakasznál **felső gradiens**, 3–2–1 haptika, kikapcsolható hang | `presentation/cardio_session_screen.dart`, `application/interval_player_controller.dart` (új) | **M38** | A lejátszó a **C2 időzítőjén** ül (hosszú, 30+ perces eszközös próba); **a szakasz órája a szünettel együtt áll meg**; a mozgásidő 96→82 px, az ellenállás-léptető nem mozdul; terv nélkül a képernyő **bitre az M05**; a végrehajtott szakaszok `INTERVAL`-splitként mentődnek |
| **C7.6** | Teljesítmény/kadencia mezők élőben + **összmunka (kJ)** származtatva + **gép-kalória külön mezőben** | `presentation/cardio_session_screen.dart`, `presentation/log_cardio_sheet.dart`, `core/format/cardio_formatter.dart`, `presentation/cardio_summary_screen.dart` | **M39** | Az összmunka `avg_watts × moving_seconds / 1000` és **nincs tárolva** ([51 §3.3](51-cardio-overview-plan.md)); a kalória **egy kártya két oldala** (aktív = teljes kontraszt, gép = másodlagos tónus, közte vonal) — két külön kártya tiltott, mert egyenrangúnak látszanának; a gép-kalória **soha nem adódik hozzá** az aktív kalóriához ([51 Q4](51-cardio-overview-plan.md)) — külön teszt |
| **C7.7** | PR: **legnagyobb összmunka (kJ)** rekordtípus | `domain/cardio_personal_record.dart`, `features/statistics/` | – | Csak MACHINE-család; watt-adat nélküli session nem dönt rekordot ([56 §5.2](56-cardio-statistics-plan.md)) |

**Elfogadás (MF6c)**

- [ ] Egy mentett intervallum-terv újraindítható, és kétszer futtatva két külön session lesz
- [ ] A gép-kalória sehol nem növeli a napi aktív kalóriát
- [ ] Intervallum nélkül a MACHINE képernyő pontosan a mai marad (regressziós widget-teszt)

---

## 7. C8 — Túra-specifikum (7 lépés) · MF6d

**Függés:** C4a (nyomvonal), Q-C8.1.

| # | Lépés | Fájlok | Frame | Kész-ha |
|---|---|---|---|---|
| **C8.0** ✅ | Design: túra-frame-ek (az M16-ból kiindulva) | [61 §4](61-cardio-sport-specifics-design-prompts.md#4-c8--túra--m40m42) | **M40–M42** | **Kész (2026-08-16)** — a canvasban M40–M42 + állapot-kivágatok + M42 light/EN minta |
| **C8.1** | Backend: **V71** — `cardio_details` + `backpack_weight_kg`, `avg_gap_seconds_per_km`, `weather_temp_c`, `weather_wind_kph`, `weather_condition`; új `cardio_waypoints` tábla (session, index, lat, lng, altitude, label) | `db/migration/V71__*.sql`, `session/cardio/`, `session/dto/` | – | A `cardio_waypoints` a polyline-nal **azonos adatvédelmi szinten** van (a nyers pontok maradnak lokálisak, [52 D-C1.2](52-cardio-domain-backend-plan.md)) — a doc-komment ezt kimondja |
| **C8.2** | **GAP** (emelkedés-normált tempó) domain-számítás + a képlet rögzítése az [56](56-cardio-statistics-plan.md)-ban | `features/workouts/domain/grade_adjusted_pace.dart` (új), `docs/cardio/56-cardio-statistics-plan.md` | – | Sík terepen a GAP **megegyezik** a nyers tempóval (teszt); a képlet egy helyen él, és a komment a docra hivatkozik |
| **C8.3** | **Valódi magasságprofil**: a lokális nyomvonalból, kumulált táv-tengellyel — a mai közelítés cseréje; nyomvonal hiányában (törölt pontok) a régi, egyszerűsített nézetre esik vissza | `presentation/cardio_summary_screen.dart:455-505`, `data/cardio_track_point_repository.dart`, `application/track_point_maintenance.dart` | **M40** | A hézag **arányos szélességű sáv** (szaggatott határ, `C49A6C` 9%), nem interpolált vonal; a csúcs marker + felirat; a kiválasztott pont **ejtővonal + három számos readout a kártya alján** (nem lebegő tooltip); a nyers pontok törlése után **„EGYSZERŰSÍTETT”** profil marad, nem üres hely |
| **C8.4** | **Útpont-jelölés**: gomb az élő képernyőn (címke nélkül, egy koppintás), megjelenítés az összegzésen és a `RoutePainter`-en | `presentation/cardio_session_screen.dart`, `presentation/widgets/route_painter.dart`, `presentation/cardio_summary_screen.dart` | **M41** | A gomb **88 px magas, teljes szélességű hasáb**, a befejezés-gesztus sávja **fölött**; a visszajelzés a számokat mutatja (táv · magasság · idő), **4 s után eltűnik**, „Vissza”-val visszavonható; GPS nélkül **nem tűnik el, hanem nem elérhető** (koppintásra M25 nyílik); 50+ útpont sem lassítja a rajzolást |
| **C8.5** | **Max magasság** + **hátizsák-súly** mező + hatása a kalória-becslésre | `presentation/log_cardio_sheet.dart`, `presentation/cardio_summary_screen.dart`, kalória-becslés helye | **M42** | A hátizsák-súly csak túránál látszik; **óráról jött kalória esetén a becslés nem írja felül** ([51 R8](51-cardio-overview-plan.md)) |
| **C8.6** | **Időjárás-pillanatkép** a Q-C8.1 döntése szerint, induláskor rögzítve | `features/workouts/data/` (új forrás), `presentation/cardio_summary_screen.dart` | **M42** | Hálózati hiba/megtagadott helymeghatározás esetén a mezők üresek maradnak, és **az edzés indulása nem késik** — időkorlát + tesztelt hibaág |
| **C8.7** | PR-bővítés: **max magasság** + statisztika-metrika | `domain/cardio_personal_record.dart`, `features/statistics/application/stat_chart_data.dart` | – | A meglévő statisztikai számok változatlanok (regressziós teszt) |

**Elfogadás (MF6d)**

- [ ] Egy túra magasságprofilja a valós táv mentén rajzolódik, a GPS-hézag látszik
- [ ] A GAP sosem „javít" lefelé sík terepen
- [ ] Az időjárás-lépés kihagyásával a C8 többi része teljes értékű marad

---

## 8. Web (58) — mit lát ebből a webes olvasó nézet

A [58-as terv](58-cardio-web-plan.md) a C6–C9-et **nem tárgyalja**. A web olvasó marad, és a
sport-specifikumok nagy része szinkronizált adat, tehát megjeleníthető — de ez **külön, opcionális
lépés iterációnként**, és egyik MF6a–d elfogadásának sem feltétele:

| Lépés | Tartalom |
|---|---|
| **C6w** | Split-lista + legjobb résztávok a webes session-részletben |
| **C7w** | Intervallum-splitek + összmunka (a **szerkesztő nem** — webről cardio nem indítható, [58 D-W.1](58-cardio-web-plan.md)) |
| **C8w** | Magasságprofil + útpontok az útvonal-SVG-n |
| **C9w** | Zóna-eloszlás + box score |

**Ajánlás:** a webet **egyben**, a négy iteráció után érdemes áthúzni (egy beszélgetés), nem
iterációnként — az `aggregate.ts` paritás-tesztje ([56 ST11](56-cardio-statistics-plan.md)) csak a
statisztikai számokra vonatkozik, a megjelenítés nem érinti.

---

## 9. Kockázati ellenőrzőpontok (ahol a hiba **néma**)

Ugyanaz az elv, mint az [59 §11](59-cardio-implementation-plan.md)-ben: itt nem hibaüzenet lesz,
hanem rossz szám.

| Hol | Mi a néma hiba | Ellenőrzőpont |
|---|---|---|
| C6.2 | A csúszóablak átnyúl egy GPS-hézagon → **irreális „legjobb 5 km"**, ami örökre benne marad a PR-listában | Kötelező teszt hézagos nyomvonalon; az ablak érvénytelen, ha bármelyik szegmense hosszabb, mint a szűrő tűrése ([54 §3](54-cardio-gps-route-plan.md)) |
| C6.3 / C7.6 | Az új cardio-mező változása nem bumpolja a session `updatedAt`-jét → **soha nem szinkronizál** | Ugyanaz a teszt-minta, mint C1.4/C1.5-nél ([52 §4](52-cardio-domain-backend-plan.md)) |
| C7.5 | Az intervallum-lejátszó saját időzítőt indít → háttérben elcsúszik a mérés idejétől | Hosszú eszközös próba; a lejátszó ideje **a session mozgásidejéből** származik, nem `Timer.periodic`-ból |
| C7.6 | A gép-kalória belecsúszik az aktív kalóriába → **dupla kalória** a napi összegben | Külön teszt: gép-kalóriás session után a napi aktív kalória változatlan ([51 Q4](51-cardio-overview-plan.md)) |
| C8.2 | Rossz GAP-képlet → a túra-PR-ok és a tempó-statisztika csendben eltolódik | Fix bemenet → fix elvárt érték tesztek; sík terepen azonosság |
| C9.1 | A zóna-másodpercek összege > bruttó idő (óra + telefon kétszer ír) | Őr a merge-ben ([55 R8](55-cardio-watch-plan.md) forrás-szabály) + teszt |

---

## 10. Összefoglaló

| Iteráció | Lépések | Ebből design | Backend-migráció | Mérföldkő |
|---|---|---|---|---|
| **C6** Futás | 8 | 1 ✅ (M33–M36) | V69 | MF6a |
| **C9** Játék | 6 | 1 ✅ (M43–M45) | – | MF6b |
| **C7** Bicikli | 8 | 1 ✅ (M37–M39) | V70 | MF6c |
| **C8** Túra | 8 | 1 ✅ (M40–M42) | V71 | MF6d |
| *(opcionális)* web | 4 | – | – | – |

**Összesen 30 lépés** (26 mobil/backend + 4 design), plusz 4 opcionális webes.
**A négy design-lépés lezárva** — a leszállított frame-ek leírása a
[61-es docban](61-cardio-sport-specifics-design-prompts.md).
Platform: **29 lépés Windowson**, **egyetlen egy igényel Mac-et** (a C6.5 watchOS-fele — **2026-08-17
óta ez is kész**), és **egy igényel hosszú eszközös próbát** (C7.5) — ld. [§3.2](#32-platform).

**Ami tudatosan kimarad ebből a docból** ([51 §5](51-cardio-overview-plan.md) szerint): a gép
kijelzőjének OCR-/fotó-alapú beolvasása (C7 „megfontolható" tétele), a teljes cardio-edzésterv, a
C4b valódi térképcsempe, és a webről indítás.

**Kezdésre javasolt:** a `C9` design-körének lefuttatása a [61 §4](61-cardio-sport-specifics-design-prompts.md#4--c90--játék-specifikum-m43m45)
prompttal (a legolcsóbb iteráció), mellette párhuzamosan a Q-D1 döntés a C6-hoz. Backend-oldalról a
`C6.1` (V69) a design-körtől függetlenül elindítható.
