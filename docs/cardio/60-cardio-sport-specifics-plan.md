# 60 – Cardio sport-specifikumok: fejlesztési terv (C6–C9)

Státusz: **A design kész (2026-08-16), és két iteráció leszállt (2026-08-17): a teljes C6 (MF6a)
és a teljes C9 (MF6b).**
A C6.5 watchOS-fele Macen készült el, ezzel a terv egyetlen Mac-es lépése is megvan; a C6.7
statisztika-listája az egyetlen kimaradt darab, mert nincs mit bővíteni
(ld. [§4](#4-c6--futás-specifikum-8-lépés--mf6a)). A hátralévő iterációk: **C7 (bicikli)** és **C8 (túra)**.
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

1. ~~**A HR-zóna oszlopok végig-vezetve, de sehol nem jelennek meg**~~ — **megoldva a C9.1-ben
   (2026-08-17):** a `hrZone1..5Seconds` most az M43 zóna-paneljén jelenik meg, mindhárom
   cardio-családon.
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
| **Q-D3** ✅ | Az intervallum cél-intenzitás skálája | – | **Eldöntve (2026-08-17): három fokozat, watt-sáv nélkül.** Gépfüggetlen, tehát a terv újrahasznosítható. A watt-sáv kimarad, amíg nincs élő watt-forrás (BLE-trainert az app nem párosít, a watt kézzel beírt érték — [51 §3.3](51-cardio-overview-plan.md)): olyan célt írna elő, amit a lejátszó semmivel nem tud összemérni, és a legtöbb szakaszon üres mező maradna |
| **Q-D4** ✅ | Hang a szakaszváltásra | – | **Eldöntve (2026-08-17): legyen, kikapcsolhatóan, a platform saját hangjával** (`SystemSound`), az M35 kapcsolópár-mintájával — **új audio-függőség nélkül**. Ugyanaz a megoldás, mint a C6.6 km-csengőjénél; ha később mégis bejön egy lejátszó-csomag, a két hely egyszerre cserélhető |
| **Q-C7.1** ✅ | Az intervallum-terv külön entitás-e | – | **Már eldöntve a D-C7.1-ben** (ugyanennek a docnak a §6-a): külön entitás (`cardio_interval_plans`), a végrehajtás a `cardio_splits`-be. Nem designkérdés, és valójában sosem volt nyitva — ez a tábla listázta tévesen pipa nélkül |
| **Q-D6** | A max magasság hova tartozik | C8.3/C8.5 | **Mindkettő** (profil-marker + metrika-rács) — a degradált nézetben csak a rács marad |
| **Q-C8.1** ✅ | Időjárás-forrás (külső API vs. kézi) | – | **Eldöntve (2026-08-19): kézi bevitel, külső API nélkül.** Nincs API-kulcs, nincs hálózati függőség, nincs backend-proxy — pont az a fajta egyszerűség, amit az app eddig is követett (a táv, a gép-kalória, a hátizsák-súly mind kézzel szerkeszthető, [51 R8](51-cardio-overview-plan.md)). Az időjárás **ugyanígy egy sima szerkeszthető mező** a hátizsák-súly mellett — nem induláskor rögzített „pillanatkép", mert az egy capture-at-start folyamatot igényelne (mikor kérdezzük meg, mi van, ha a user elfelejti); a legegyszerűbb az, ha bármikor megadható/módosítható, ugyanazzal a „kézzel" jelvénnyel, amit a többi kézi mező is visel. A **„nincs adat" állapot** (M42 `cloud_off`) ettől függetlenül megmarad — csak most azt jelenti, hogy a user még nem adta meg, nem hogy a hívás elhasalt |
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

**Nyitott döntést egyik sem vár** a C6 és a C9 közül: a Q-D1/Q-D2/Q-C6.1 eldőlt a designban. **A C7 sem vár már**: a Q-D3/Q-D4 eldőlt (2026-08-17), a Q-C7.1 pedig sosem volt nyitva. **A C8 sem vár már**: a Q-C8.1 eldőlt (2026-08-19) — mind a 8 lépése indulhat.

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
> **C9.5 — Z4+Z5, nem összes zóna-idő; és nincs negyedik szűrő-fokozat.**
> A lépés „zóna-idő mint metrika" sora egy metrikát kér. **Az öt zóna összege együtt körülbelül maga
> a session**, amit a `cardioMovingMinutes` már diagramra tesz — abból új információ nem születik. Az
> a kérdés, amire egy zóna-diagram válaszol, az „mennyi kemény munkát végeztem a héten", és az a
> **Z4+Z5**. A metrika ezért `cardioHardZoneMinutes` („Küszöb feletti idő").
>
> **„A GAME-fajta szűrése" nem egy negyedik szűrő-fokozat.** A `StatKindFilter` saját doc-kommentje
> kimondottan kizárja („Never a fourth, finer-grained per-`kActivityTypes` option" — az a `SessionsTab`
> listaszűrőjének a dolga, és a design M21/M22-je egy háromállású SegmentedButton). A GAME itt máshogy
> „szűrődik": ez az **első metrika, amihez egy meccs a sajátjából ad valamit**. Egy meccsnek nincs
> távja, szintje és tempója — zóna-ideje viszont van, tehát ez a metrika **családtól függetlenül**
> minden cardiót számol, és `strength` szűrő alatt — mint minden cardio-only metrika — nem jelenik meg.
>
> **Amit a megvalósítás eldöntött:**
> - A metrika a **`HrZoneBreakdown`-on keresztül** olvas, nem közvetlenül a két oszlopból: így a
>   diagram ugyanazt a vágást kapja, mint a C9.1 panelje. Egy olyan sor, ahol az óra és a telefon is
>   írt zónát, több időt adhat, mint a session hossza (§9) — vágás nélkül ez **csendben felfújná** egy
>   hét edzés-terhelését. Külön teszt: 90 perc zóna egy 60 perces session-ön nem ad 60 percnél többet.
> - A **nulla valódi válasz**, a hiányzó adat nem: egy könnyű edzés, amiben mértük a zónákat, de nem
>   volt küszöb feletti idő, **0-t** rajzol; egy zóna-adat nélküli session **nem szerepel** a napi
>   összegben.
> - A metrika a **szív színét** kapja (`mc.heart`), nem a cardio-narancsot: pulzus-metrika.
> - A picker csak akkor ajánlja fel, ha **van** zóna-adat — különben egy lapos semmit rajzoló metrika
>   ülne a listában a felhasználók többségénél.
>
> **C9.4 — az akku-garancia egy feltétel egy helyen, és a meccs nem kap tempót.**
> A „teremben nincs rádió" nem szabály, amit minden hívási helyen be kell tartani, hanem **egy
> getter**: `_tracksLocation` (DISTANCE-család, **vagy** kültéri GAME opt-innel). Ezt kérdezi a
> `_syncPositionTracking`, és ez dönti el, hogy elindul-e egyáltalán az `availability`-feliratkozás —
> vagyis teremben **nincs engedélykérés sem**, nem csak rádió nincs. Teszt számolja: egy termi
> meccs **nulla** `availability` és **nulla** `positionStream` hívást csinál, még akkor is, ha a
> kültéri opt-in bekapcsolva maradt egy korábbi meccsről (a `recordsDistance` a `venue`-ra is szűr).
>
> **Amit a megvalósítás eldöntött:**
> - **A meccs távot és útvonalat kap, de semmit, ami tempóból származik.** A záró pipeline GAME-nél
>   **nem számol km-splitet és nem számol best-effortot** — nem kiszámolja és elrejti, hanem meg sem
>   próbálja: km-split egy kosárpályán semmit nem ír le. A `PACE` csempe sem jelenik meg a
>   GAME-összegzésen, mert az M45 GPS-ígérete pont ezt mondja ki előre („Tempót nem"), és ha utólag
>   mégis ott lenne, az ígéret hazudott volna.
> - **Az útvonal-rajz ingyen jött**: az összegzés route-hőse eddig is csak a polyline létére szűrt,
>   nem családra — így a kültéri meccs a térképét is megkapja, ahogy az ígéret mondja.
> - **`track_filter.dart` GAME-profil**: ugyanaz a pontosság- és sebesség-plafon, mint futásnál,
>   szándékosan — egy meccs sprintek sorozata, egy lassabb sebesség-kapu épp a rögzítendő mozgást
>   dobná el.
> - **Az élő GAME képernyőn nincs táv-csempe**: sem az M07, sem az M43 nem rajzol egyet, a mérés
>   pedig így is megy — a szám az összegzésen jelenik meg. A widget-teszt ezért a **záró írásból**
>   olvassa ki a távot, nem a képernyőről.
> - A `_startLocationPipeline()` kiemelése azért történt, hogy a kültéri GAME **pontosan** a
>   DISTANCE-utat használja, ne egy párhuzamosat, ami idővel elcsúszhat tőle.
> - **Sprint-szám nincs** (Q-D8/Q-C9.1: „Most ne.").
>
> **C9.3 — a GPS-sor a C9.4-re maradt, és az indítási út megváltozott.**
> Az M45 négy blokkot ír le; ez a lépés az elsőt kettőt szállítja (**formátum 2×2**, **helyszín**),
> a **GPS-sort és a „mit kapok / mit nem" ígéretet nem**: az a szabadtéri táv-rögzítés kapcsolója,
> ami a **C9.4** tárgya (ott meg is épült). Kapcsolót kitenni a mögötte lévő viselkedés nélkül üres
> ígéret lenne, ezért a C9.3-ban még nem volt ott.
>
> **Amit a megvalósítás eldöntött:**
> - **A GAME-indítás mostantól a lapon megy át** — eddig a koppintás azonnal indított. A lap viszont
>   **előre kitöltve** nyílik a legutóbbi meccs válaszaival (`GameSetupPreferences`), tehát aki minden
>   héten ugyanazt az 5v5-öt játssza ugyanabban a teremben, egyetlen extra koppintással indul. Ez
>   **viselkedés-változás**, ezért egy meglévő teszt („tapping a cardio row starts that activity
>   immediately") átíródott: a DISTANCE-út változatlan, a GAME-út a lapon keresztül vezet.
> - **A lap elhúzása nem indít semmit.** Egy félig látott beállítással induló meccs rosszabb, mint
>   egy nem induló: a „nem blokkolja" azt jelenti, hogy *egy koppintással átléphető*, nem azt, hogy
>   megkerülhetetlen.
> - A `venue` **egyetlen helye** ez a lap: innen kerül a `cardio_details`-be a session létrejöttekor,
>   és onnan olvassa a telefon GPS-e és a `startWorkout` a watch `locationType`-jához (C5.2) — nincs
>   második vezérlő, ami eltérhetne tőle.
> - A `startCardioSession` mostantól **kaphat `CardioMetrics`-et** a létrehozáshoz. Enélkül a
>   formátum/helyszín csak egy második, közvetlenül utána futó írásból kerülhetett volna a sorba —
>   két írás egy létrehozásra, aminek a második el is hasalhat.
> - Az **összegzésen ugyanazok a widgetek** szerkesztik a két mezőt, mint az indító lapon
>   (`GameFormatSelector` / `GameVenueSelector`), hogy a két felület ne tudjon eltérni.
>
> **C9.2 — két lappangó hibát is javítani kellett hozzá.**
> A léptető az első GAME-hívó a `updateLiveCardioMetrics` **teljes-csere** írásán, és ez két
> korábban néma lyukat világított meg:
> 1. Az élő képernyő `_updateCardioMetrics`-e nem vitte tovább a **`venue`-t és az `intensity`-t** —
>    egy koppintás a léptetőn letörölte volna a meccs helyszínét és intenzitását. Eddig lappangó
>    volt, mert GAME-en semmi nem hívta ezt a metódust (a táv/kadencia/watt/ellenállás mind
>    DISTANCE/MACHINE).
> 2. Az összegzés `_persistCardio`-ja nem vitte tovább a **best-effortokat és a HR-zónákat** — a táv
>    szerkesztése törölte volna a C6.3 óta tárolt legjobb résztávokat és a C9.1 zóna-adatát. Ez
>    **valódi, szállítható hiba volt a C6.3 óta**; a route-ra már volt teszt ugyanerre a mintára, a
>    két újabb adatcsoportra nem. Most mindkettőre van.
>
> **Amit a megvalósítás eldöntött:**
> - A léptető **deltát** jelent (+1/−1), nem kész számot: két koppintás egy kereten belül különben
>   mindkettő „a build-időbeli érték + 1"-et számolna, és **egy kosár elveszne**. Teszt fedi.
> - A **„Box" kör a tálca jobb alsó sarkába** került, a széles „Meccs szünet" sáv mellé — ugyanabba a
>   pozícióba, ahol a DISTANCE-elrendezés `trailing` köre már ül. A pályán/padon kapcsoló mérete és
>   helye **bitre változatlan** (teszt hasonlítja a `Rect`-jét nyitott és zárt panellel).
> - A felajánlás **kártya a törzsben, nem dialógus**: egy modális ablak futó meccs fölött pont az,
>   amit a rejtve-indulás elkerülni akar.
> - Az **elutasítás véglegesen megjegyződik**, de a „Box" kör megmarad — az M44 rejtett alapállapota
>   szerint („csak a »Box« kör látszik"), tehát aki meggondolja magát, eléri. Amit az ígéret tilt, az
>   az **újbóli kérdezés**, nem a funkció elérése.
> - A **kézi lap ugyanezt a komponenst** használja a korábbi saját, egyoszlopos pont-léptető helyett:
>   így a focis kétoszlopos vágás is egy helyen él, nem kettőben.
> - A felajánló kártya gombsora **`Wrap`**, nem `Row`: 400 px-en angol szöveggel túlcsordult (a
>   widget-teszt fogta meg), és egy elvágott „többé nem kérdezzük" ígéret a legrosszabb, amit levágni
>   lehet.
>
> **C9.1 — az őr két helyen ül, és a modell nem a formatterben van.**
> A §9-es néma hiba („a zóna-másodpercek összege > bruttó idő, mert az óra és a telefon is ír")
> **két ponton** van elzárva. (1) A **merge-ben**: a `mergedWithWatchMeasurement` a zóna-ötöst
> mostantól **egy blokként** veszi át — akinek már van bármelyik zóna-oszlopa, az mind az ötöt
> megtartja. Mezőnkénti `??`-fal egy telefon-mért Z1 mellé kerülhetett volna egy óra-mért Z2–Z5
> *ugyanazon session más méréséből*, és az öt együtt több időt adott volna, mint a session hossza —
> a sávnál szélesebb sáv és „112% a zónában", anélkül hogy az adatból kiderülne, melyik fele hibás.
> (2) A **modellben**: a `HrZoneBreakdown` a bruttó időre **vág**, és `exceedsGross` flaggel jelzi az
> ellentmondást, hogy teszt elkaphassa, ne pedig csendben átskálázza.
>
> **A modell `domain/hr_zone_breakdown.dart`-ban van, nem a `cardio_formatter.dart`-ban** (amit a
> lépés fájllistája említ): az intenzitás-osztályozás, a vágás és a részleges-lefedettség számítás
> tesztelhető logika, nem formázás — a formatter végül nem is igényelt változtatást.
>
> **Amit a megvalósítás eldöntött:**
> - Az **intenzitás-küszöbök** szándékosan egyszerűek: a mért idő ≥33%-a küszöb felett = kemény,
>   <10% = könnyű, közte kiegyensúlyozott. Profil-bemenet és becslés nincs — pont amit az M43 záró
>   sora ígér („Becslés nincs").
> - A chip a **mért** időt olvassa, nem a session hosszát: 10 perc mérés, mind maximumon, egy órás
>   meccsen **„kemény meccs"** + „a meccs 17%-a" — nem hígítjuk „könnyűre" azzal, amit nem mértünk.
> - **Mind az öt sor megjelenik**, a nulla másodperceseket is beleértve: az, hogy egy zónában nem
>   volt idő, információ, nem üres sor. A **szám ilyenkor is teljes kontrasztú**.
> - A zóna-színek **a widgetben, lokálisan** vannak definiálva (hideg→meleg ötös rampa): az
>   `AppMetricColors` egy-egy metrika *identitása*, ez viszont skála — csak együtt van értelme.
> - Elhelyezés a Q-D7 szerint: **DISTANCE** a splitek után, **GAME** közvetlenül a domináns szám
>   után (meccsen a zóna-eloszlás *maga* a történet, ezért megelőzi a helyszín/intenzitás rácsot),
>   **MACHINE** a „nincs útvonal" kártya után.
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
| **C9.1** ✅ | **Pulzuszóna-panel**: 22 px halmozott sáv + „kemény / kiegyensúlyozott / könnyű meccs" chip + 5 sor (zóna · név · idő · %) a meglévő `hrZone1..5Seconds`-ből | `domain/hr_zone_breakdown.dart` (új), `presentation/widgets/hr_zone_panel.dart` (új), `presentation/cardio_summary_screen.dart`, `domain/workout_session.dart` (merge-őr), `l10n/` | **M43** | **Kész (2026-08-17)** — **Egy komponens minden cardio-típusra** (Q-D7), csak a helye családfüggő: DISTANCE-nál a splitek után, GAME-nél a domináns szám után. Az öt zóna összege **sosem haladja meg a bruttó időt** (őr + teszt); adat nélkül a panel **eltűnik**, részlegesnél a hiányzó rész sraffozott; a **szám mindig teljes kontrasztú**, a szín csak a címkén és a kis sávon |
| **C9.2** ✅ | **Box score léptető** (pont/gól · gólpassz · lepattanó) az élő GAME képernyőn a Q-D2 szerint: alapból rejtve, egyszeri felajánlással; az összegzésen és a kézi lapon szerkeszthető | `presentation/cardio_session_screen.dart:1386` (a ma szándékosan üres GAME-elrendezés), `presentation/cardio_summary_screen.dart`, `presentation/log_cardio_sheet.dart` | **M44** | **Kész (2026-08-17)** — a felajánlás **egyszer** jelenik meg és megjegyzi a választ; a léptetőt a **jobb alsó „Box” kör** nyitja, és **6 s tétlenség után magától becsukódik**; a `+` **1,4× szélesebb**, mint a `−`; a pályán/padon kapcsoló mérete és helye **nem változik**; a léptető nem nyúl a `movingSeconds`-hoz; kosár 3, foci 2 oszlop |
| **C9.3** ✅ | **Formátum + helyszín** választó: `gameFormat` (5v5 / kispálya / edzés / meccs) és `venue` a gyorsindításnál és az összegzésen | `presentation/quick_start_sheet.dart`, `presentation/activity_picker_screen.dart`, `presentation/cardio_summary_screen.dart`, `l10n/` | **M45** | **Kész (2026-08-17)** — a lap **nem blokkolja az indítást** (minden mezőnek van alapértéke: a legutóbbi választás); a formátum-választó **2×2 segmented** (magyarul egy sorban nem fér ki); a `venue` továbbra is **egy** helyről vezérli a GPS-t és a watch `locationType`-ot (C5.2) |
| **C9.4** ✅ | **Kültéri GPS-mód** GAME-hez: opt-in `venue == OUTDOOR` esetén táv-rögzítés (+ sprint-szám, ha a Q-C9.1 eldőlt) | `application/` GPS-vezérlés, `presentation/cardio_session_screen.dart`, `domain/track_filter.dart` | **M45** | **Kész (2026-08-17)** — teremben **nincs GPS-sor, nincs engedélykérés, és az összegzésen sincs táv** — „nem letiltva, hanem nem létezik” (akku-teszt); kültéren a kapcsoló alatt ott a **mit kapok / mit nem** ígéret, mert a tempó hiányát itt kell kimondani ([51 §3.4](51-cardio-overview-plan.md)) |
| **C9.5** ✅ | Statisztika: zóna-idő mint metrika + a GAME-fajta szűrése | `features/statistics/application/stat_chart_data.dart`, `stat_summary_data.dart` | – | **Kész (2026-08-17)** — a meglévő `StatMetric` értékek számai **bitre változatlanok**: a `stat_chart_data_test.dart` 35 meglévő esete változtatás nélkül zöld, ez maga a regressziós háló ([59 §11](59-cardio-implementation-plan.md)) |

**Elfogadás (MF6b)**

- [x] Óra nélküli meccs is teljesen használható (zóna-panel nélkül), semmi nem üres folt — zóna-adat nélkül a panel **eltűnik** (C9.1 tesztjei), a box score és a formátum/helyszín órától független
- [x] A box score kikapcsolható és a kikapcsolt állapot marad — a felajánlás elutasítása **véglegesen** megjegyződik (C9.2 tesztjei); a „Box" kör marad, ha valaki meggondolja magát
- [x] Termi meccs alatt nulla GPS-fogyasztás — teszt **számolja**: nulla `availability`- és nulla `positionStream`-hívás, akkor is, ha a kültéri opt-in bekapcsolva maradt (C9.4)

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
| **C7.1** ✅ | Backend: **V70** — `cardio_interval_plans` + `cardio_interval_steps` (felhasználóhoz kötve, CLAUDE.md), plusz `cardio_splits` + `split_type` (`DISTANCE` \| `INTERVAL`) és `avg_watts` | `db/migration/V70__cardio_interval_plans.sql`, `session/cardio/` (+`interval/`), `session/dto/CardioSplitRequest.java`, `CardioSplitResponse.java` | – | **Kész (2026-08-19)** — a `split_type` oszlop **defaultja `DISTANCE`**, így a meglévő sorok maguktól migrálódnak és a `splitType` nélkül küldő kliens is pontosan a mait kapja (`CardioSplitTypeMigrationTest`, `WorkoutSessionServiceImplTest`). A `distance_meters` csak az INTERVAL-nak lett nullozható — DISTANCE-nál DB-constraint követeli (`cardio_splits_distance_required_ck`). A **szakasz intenzitása a splitre kerül**, nem a tervről olvassuk vissza: a terv szerkeszthető és törölhető, egy utólag átcímkézett összegzés hazudna. A lépések egy szinten ágyazódnak (REPEAT-be nem kerülhet REPEAT — `cardio_interval_steps_shape_ck`), és a gyerek-lépés összetett kulccsal van a saját tervéhez kötve (`cardio_interval_steps_parent_fk`) |
| **C7.2** ✅ | Backend: terv-CRUD végpont + delta-sync bekötés | `session/cardio/interval/` (controller, repository, mapper, `service/`, `dto/`), `docs/postman/` | – | **Kész (2026-08-19)** — `/api/v1/cardio-interval-plans` CRUD + `?updatedSince=` delta-feed (fix `updatedAt,id` sorrend, tombstone-nal), a `workout-templates` mintájára. **A terv törlése soft delete**, és semmit nem visz magával: session→terv hivatkozás nincs is (D-C7.1), ezt külön teszt bizonyítja egy INTERVAL-splites session-nel. **User-scope**: minden olvasó és író út `findBy...AndUserId`-n megy, idegen userrel a findById/update/delete mind 404 és a delta-feed üres (`CardioIntervalPlanCrudIntegrationTest`). A kérés **fa alakú** (a szerkesztő alakja), a tárolás lapos — a szakasz-shape ellenőrzése a service-ben is megvan, hogy tiszta 400 legyen a nyers constraint-hiba helyett |
| **C7.3** ✅ | Mobil adatréteg: drift-táblák + repository + outbox a tervekhez | `core/local_db/tables/cardio_interval_plan_tables.dart`, `core/local_db/app_database.dart` (V38), `core/sync/entity_sync_config.dart`, `core/sync/pull_engine.dart`, `features/workouts/{domain,data}/cardio_interval_plan*.dart` | – | **Kész (2026-08-19)** — drift **V38**: két új, üres tábla (a lépések fából laposra, sibling-enkénti `stepIndex`-szel, mint a backenden). A terv a szokásos offline úton megy: helyi írás → outbox (`cardio_interval_plan` entitástípus, `/cardio-interval-plans`), a **teljes fa egy payloadban** — a lépéseknek nincs saját szinkronjuk, ezért minden pull **cserél minden lépést** (a step-only szerkesztés is bumpolja a terv `updatedAt`-jét). A törlés a többi entitáséval azonos: nem szinkronizált tervnél helyben törlünk, szinkronizáltnál a sorok maradnak (a listából rejtve), amíg a szerver vissza nem igazolja. **Függő írású sort a pull sosem ír felül** (teszt). A `STRENGTH` payload érintetlen: a session-repository egy sorral sem változott, a meglévő bájtra-azonos regressziós teszt zöld |
| **C7.4** ✅ | **Intervallum-szerkesztő** UI (szakaszok: idő + cél-intenzitás, ismétlés, mentés névvel) | `presentation/interval_plan_editor_screen.dart` (új), `application/cardio_interval_plan_controller.dart` (új), `l10n/` (30 kulcs, hu+en) | **M37** | **Kész (2026-08-19)** — a 4×(4+3) **egy koppintás**: az „Ismétlés” gomb kész blokkot ad (×4, 4:00 kemény + 3:00 könnyű), az üres állapot „Kezdj a 4×4-tel” ajánlata pedig a teljes 38:00-s tervet egy koppintásból. A fejléc három száma (teljes hossz · szakasz · **kemény idő**) minden szerkesztésre azonnal frissül — widget-teszt tapogatja végig. A blokk alján ott a saját számtana (`4 × 7:00 = 28:00`), a számláló helyben szerkeszt (−/×4/+, 99-ig, mint a V70 constraint), a blokk **összecsukható** egy soros összefoglalóra. A szakasz-lapon időtartam-stepper (15 mp-es lépés) + három fokozat egy borostyán-hue három telítettségén. **Belépési pont még nincs**: a szerkesztő a C7.5 MACHINE-folyamatából nyílik majd (a „Mentés és indítás” már most visszaadja a hívónak, hogy induljon-e a session) |
| **C7.5** ⏳ | **Lejátszó** az élő MACHINE képernyőn: szakasz-számláló, visszaszámláló, „utána” előnézet, kemény szakasznál **felső gradiens**, 3–2–1 haptika, kikapcsolható hang | `presentation/cardio_session_screen.dart`, `application/interval_player_controller.dart` (új), `application/interval_cue_preferences.dart` (új), `presentation/widgets/interval_plan_picker_sheet.dart` (új), `widgets/cardio_session_settings_sheet.dart`, `quick_start_sheet.dart`, `open_workout_screens.dart`, `local_db/` (V39), `data/workout_session_repository.dart`, `core/sync/pull_engine.dart`, `l10n/` | **M38** | **Kód kész (2026-08-19), eszközös próba még hátra.** A lejátszó **saját órát nem indít**: minden állapota a session `movingSeconds`-éből számolt függvény, ezért a szakasz órája a szünettel együtt áll meg (unit-teszt hajtja végig, és a képernyő-teszt is állítja) — ez a §9-ben nevesített kockázat kiiktatása. A mozgásidő **96→82 px** csak terv mellett, az ellenállás-léptető nem mozdul, **terv nélkül a képernyő bitre az M05** (regressziós teszt: nincs számláló, nincs Léptet-kör). A végrehajtott szakaszok **`INTERVAL`-splitként** mentődnek — a menet közben félbehagyott szakasz is, annyi másodperccel, amennyit kapott; a splitek összege a mozgásidő. A jobb alsó kör terv mellett **„Léptet”**, ugyanott, ugyanakkora. **Terv-választás a start előtt** (a C9.3 meccs-sheet mintájára) — ez adja meg a C7.4 szerkesztőjének a belépési pontját is; az elvetett sheet nem indít semmit. **Eszközös próba (30+ perc, valódi géppel) még nem futott** — a haptika/hang és a háttérbe tett app viselkedése csak ott dől el |
| **C7.6** ✅ | Teljesítmény/kadencia mezők élőben + **összmunka (kJ)** származtatva + **gép-kalória külön mezőben** | `core/format/cardio_formatter.dart`, `presentation/cardio_summary_screen.dart`, `l10n/` | **M39** | **Kész (2026-08-19)** — az összmunka `avgWatts × movingSeconds / 1000`, **tárolva sehol**: egy elmentett példány csak ellentmondani tudna a két számnak, amiből jön (pl. ha az átlagwattot utólag javítják) — a formula unit-tesztelve, a javított átlaggal együtt mozgó esettel. **Watt nélkül nincs 0 kJ**: marad az M15 mozgásidő-kártyája (a frame saját „watt-adat nélkül" állapota), watt mellett az összmunka viszi a főhelyet és a mozgásidő a rácsba kerül — de sosem tűnik el. A kalória **egy kártya két oldala, közte vonal**: bal az aktív (kalória-narancs, ez számít a napi keretbe), jobb a gép kijelzése (másodlagos tónus, tájékoztató) + a lábjegyzet, hogy miért nem adjuk össze. **A gép-kalória sehol nem adódik hozzá**: a summary-teszt kimondottan azt állítja, hogy a 486+612=1098 a képernyőn semmilyen alakban nem jelenik meg, a statisztika-teszt pedig hogy a napi aktív kalória 486 marad. Az **INTERVALLUM-SZAKASZOK** kártya a futás km-splitjeinek sorformáját viszi, csak balra a szakasz intenzitása áll a kilométer helyett és a sáv hossza az intenzitást mutatja; 6 sor fölött összecsukva. **Eltérés a frame-től:** a fejléc-chip szakasz-számot ír (`10 szakasz`), nem a terv alakját (`4×(4+3)`) — session→terv hivatkozás nincs (D-C7.1), és a végrehajtásból visszafejtett alak egy kihagyott szakasz után hazudna. A **live képernyő és a `log_cardio_sheet` nem változott**: a watt/kadencia/ellenállás/gép-kalória mezők a C2.3 és C3 óta megvannak és szerkeszthetők |
| **C7.7** ✅ | PR: **legnagyobb összmunka (kJ)** rekordtípus | `domain/cardio_personal_record.dart`, `presentation/cardio_summary_screen.dart`, `l10n/` | – | **Kész (2026-08-19)** — `CardioPrType.greatestTotalWork`, csak MACHINE-családra (`appliesTo`), értéke `CardioFormatter.totalWorkKj`-vel származtatva — watt-adat nélküli session `null`-t ad, ez **sem tervet nem indít, sem rekordot nem dönt** (teszt: egy watt nélküli menet a legbőkezűbb baseline mellett sem üt rekordot). A meglévő `CardioPrBaseline`/`detectCardioPrs` gépezet változtatás nélkül fogadta be — a típus felvétele az `enum`-ba magával hozta a baseline-mezőt, a getter, a jobbik-érték összehasonlítást. Az ünneplő dialógus és a rekord-sáv is automatikusan megkapta (kJ-formázás hozzáadva). **A `features/statistics/` a fájllistában félrevezető** — a C6.7 már leszögezte (ld. a docban ott lévő jegyzetet), hogy a statisztika-képernyőn ma nincs PR-lista, se cardio, se erősítő; a rekord az összegzésen (banner + dialógus) látszik, ahogy eddig is |

**Elfogadás (MF6c)**

- [ ] Egy mentett intervallum-terv újraindítható, és kétszer futtatva két külön session lesz
- [ ] A gép-kalória sehol nem növeli a napi aktív kalóriát
- [ ] Intervallum nélkül a MACHINE képernyő pontosan a mai marad (regressziós widget-teszt)

---

## 7. C8 — Túra-specifikum (7 lépés) · MF6d

**Függés:** C4a (nyomvonal). A Q-C8.1 eldőlt (2026-08-19) — ld. lent.

| # | Lépés | Fájlok | Frame | Kész-ha |
|---|---|---|---|---|
| **C8.0** ✅ | Design: túra-frame-ek (az M16-ból kiindulva) | [61 §4](61-cardio-sport-specifics-design-prompts.md#4-c8--túra--m40m42) | **M40–M42** | **Kész (2026-08-16)** — a canvasban M40–M42 + állapot-kivágatok + M42 light/EN minta |
| **C8.1** ✅ | Backend: **V71** — `cardio_details` + `backpack_weight_kg`, `avg_gap_seconds_per_km`, `weather_temp_c`, `weather_wind_kph`, `weather_condition`; új `cardio_waypoints` tábla (session, index, lat, lng, altitude, label) | `db/migration/V71__cardio_hike_fields.sql`, `session/cardio/{CardioWaypoint,CardioDetails}.java`, `session/dto/CardioWaypoint{Request,Response}.java`, `session/dto/CardioDetails{Request,Response}.java`, `session/{WorkoutSession,WorkoutSessionMapper}.java`, `session/service/WorkoutSessionServiceImpl.java` | – | **Kész (2026-08-19)** — a `cardio_waypoints` a polyline-nal **azonos adatvédelmi szinten** van (a nyers pontok maradnak lokálisak, [52 D-C1.2](52-cardio-domain-backend-plan.md)); a doc-komment ezt kimondja. **Nincs táv/idő oszlop a waypointon** — azokat a kliens a saját, helyi track-pontjaiból számolja (ugyanabból a forrásból, amiből a magasságprofil is jön), így nincs két hely, ahol ugyanaz a szám eltérhetne. A **súly a Q-C8.1 döntése szerint kézi mező** (nincs API-hívás, nincs időbélyeg) — a `weather_condition` szándékosan **nincs DB-CHECK-kel korlátozva**, ugyanaz a precedens, mint `game_format`/`distance_source` (csak megjelenítést vezérel). A GAP viszont **tárolt oszlop**, nem származtatott érték: a teljes magasságprofilból számol, nem két már meglévő számból (szemben az összmunkával, [60 C7.6](#7-c7--szobabicikli-specifikum-7-lépés--mf6c)). A `weather_temp_c` **előjeles, nincs `PositiveOrZero`** — a téli túrák miatt. Teszt: minden hegyi mező NOT NULL-mentes egy frissen naplózott sessionön; negatív hátizsák-súly/GAP/szél/csapadék DB-CHECK-et bukik; a waypoint `session+index` egyediség és a lekaszkádolt törlés valódi Postgres ellen fut (`CardioHikeFieldsTest`, `CardioWaypointTest`); user-scope-os teljes-csere a service-tesztekben |
| **C8.2** ✅ | **GAP** (emelkedés-normált tempó) domain-számítás + a képlet rögzítése az [56](56-cardio-statistics-plan.md)-ban | `features/workouts/domain/grade_adjusted_pace.dart` (új), `docs/cardio/56-cardio-statistics-plan.md` (D-C3.9, új) | – | **Kész (2026-08-19)** — a képlet Minetti et al. (2002) mért futási energiaköltség-görbéjének ötödfokú polinomja, ±45%-ra klemmelve; szakaszonként sík-egyenértékű távra vált (`C(i)/C(0)`), a session-szintű GAP az összidő / összes sík-egyenértékű táv. **Sík terepen pontosan a nyers tempóval egyezik** (tesztelve — ez a kész-ha). **Az irány elsőre ellenintuitív, ezért külön tesztelve is**: emelkedőn a GAP *gyorsabb* számot ad, mint a nyers tempó (jóváírja az emelkedőt), lejtőn *lassabbat* (leszámítja az „ingyen" sebességet) — kb. -20%-ig, ahol Minetti mért minimuma van; egy nagyon meredek lejtőnél a görbe visszakúszik a sík költség felé (U-alak, saját teszttel bizonyítva). Hiányzó magasságadatú szakasz sík terepnek számít, nem esik ki a nevezőből. A képlet **egyetlen helyen él** — a doc-komment a `docs/cardio/56` D-C3.9-re hivatkozik, nem duplikálja |
| **C8.3** ✅ | **Valódi magasságprofil**: a lokális nyomvonalból, kumulált táv-tengellyel — a mai közelítés cseréje; nyomvonal hiányában (törölt pontok) a régi, egyszerűsített nézetre esik vissza | `domain/elevation_profile.dart` (új), `presentation/widgets/elevation_profile_chart.dart` (új), `presentation/cardio_summary_screen.dart`, `data/cardio_track_point_repository.dart`, `l10n/` | **M40** | **Kész (2026-08-19)** — a profil `initState`-ből, aszinkron épül fel: a session **saját** lokális nyers pontjait (`CardioTrackPointRepository`) ugyanazokon a szűrő-kapukon futtatja át, mint az élő képernyő (`TrackFilterAccumulator`), majd erre a szűrt nyomvonalra épül a kumulált táv-tengely, a hézag-lista és a csúcs — nem a szerveren tárolt, már egyszerűsített polyline-ból. A hézag **arányos szélességű, szaggatott szélű sáv** (a szegmensek végpontjai közti egyenes-táv adja a szélességet, ugyanaz a közelítés, mint a `RoutePainter` szaggatott hídja), 36 px alatt felirat nélkül. A csúcs marker + az alatta lévő „csúcs {magasság} · {táv}” felirat mindig látszik; kiválasztás **koppintásra**, lebegő tooltip helyett ejtővonal + három számos readout (magasság · idáig · eltelt) a kártya alján — a fejléc ilyenkor a szokásos „+N m” helyett egy „kiválasztott pont · {táv}” chipre vált. **Nyers pontok nélkül** (törölve, vagy más eszközön rögzítve) a régi, polyline-alapú közelítésre esik vissza, **„EGYSZERŰSÍTETT”** jelvénnyel — ez a régi kész-ha, változatlanul. A GPS nélküli családok (MACHINE/GAME) **meg sem próbálják** betölteni a track-pontokat (a `_family == distance` őr az `initState`-ben). **Eltérés a tervezett fájllistától:** a domain-logika és a chart saját fájlba került (`elevation_profile.dart`, `elevation_profile_chart.dart`), nem a `cardio_summary_screen.dart`-ba ágyazva — ugyanaz a réteg-bontás, mint a `grade_adjusted_pace.dart`/`hr_zone_panel.dart` mintája; a `track_point_maintenance.dart` érintetlen maradt, a 90 napos törlési szabály már megvolt és ez a lépés nem nyúlt hozzá. A `_splitOnGaps` gap-szétvágás **szándékosan** egy harmadik, privát másolat (a track-filter és a route-encoder után), a kódbázis meglévő precedense szerint |
| **C8.4** ✅ | **Útpont-jelölés**: gomb az élő képernyőn (címke nélkül, egy koppintás), megjelenítés az összegzésen és a `RoutePainter`-en | `domain/workout_session.dart` (`CardioWaypoint`), `domain/waypoint_track_match.dart` (új), `core/local_db/tables/workout_session_tables.dart` (V40), `core/local_db/app_database.dart`, `data/workout_session_repository.dart`, `core/sync/pull_engine.dart`, `core/sync/entity_sync_config.dart`, `application/workout_session_controller.dart`, `presentation/cardio_session_screen.dart`, `presentation/widgets/route_painter.dart`, `presentation/cardio_summary_screen.dart`, `l10n/` | **M41** | **Kész (2026-08-19)** — a gomb **88 px magas, teljes szélességű hasáb**, a futó vezérlő-sor és a befejezés-gesztus sávja **közé** ékelve; koppintásra a session saját legutóbbi GPS-fixéből (`_lastFix`) épül a waypoint, **hozzáfűzve**, sosem felülírva a korábbiakat. A visszajelzés a számokat mutatja (táv · magasság · idő, a session élő értékeiből), **4 s után eltűnik**, „Vissza”-val pontosan az imént jelölt pontot vonja vissza. GPS nélkül a gomb **nem tűnik el, hanem nem elérhető** állapotba vált (koppintásra a meglévő M25 helyengedély-kártya nyílik újra). A `RoutePainter` mindkét képernyőn (élő + összegzés) számozott markert rajzol minden waypointra; 50 waypointtal is kivétel nélkül fut (teszt). Az összegzésen egy **ÚTPONTOK** lista jelenik meg (`_WaypointRow`), soronként sorszám · táv · magasság · idő — a táv/idő a session **saját lokális track-pontjaihoz** legközelebbi ponttal van meghatározva (`matchWaypointsToTrail`, ugyanaz a forrás, mint a C8.3 magasságprofilé), a magasság elsődlegesen a track pontjáé, csak ennek hiányában esik vissza a waypoint saját, szerveren tárolt értékére. **Eltérés a tervezett fájllistától:** a C8.1 csak a backendet építette meg (Q-C8.1 döntés), a mobil adatréteg (drift **V40** tábla, repository teljes-csere, delta-sync, `updateLiveWaypoints`) itt, a C8.4 részeként készült el — ugyanaz a réteg-bontás, mint a `CardioSplit`/`cardio_interval_plan` mintája. **A gomb kizárólag HIKING-nél jelenik meg**, nem az egész DISTANCE családnál — ez összhangban van azzal, hogy a teljes C8 „Túra-specifikum”, és M41 fejléce is kimondottan a „túra képernyőt” nevesíti. **Nem készült el** M41 „mozgásidő · m szint · m tszf.” metrika-sor cseréje az élő képernyőn — ez a kész-ha-ban nem szerepel explicit elvárásként, és természetesebb helye a C8.5 TEREP-blokkjával együtt van |
| **C8.5** ✅ | **Max magasság** + **hátizsák-súly** mező + hatása a kalória-becslésre | `domain/workout_session.dart`, `core/local_db/tables/workout_session_tables.dart` (V41), `core/local_db/app_database.dart`, `data/workout_session_repository.dart`, `core/sync/pull_engine.dart`, `core/format/cardio_formatter.dart`, `presentation/cardio_session_screen.dart`, `presentation/log_cardio_sheet.dart`, `presentation/cardio_summary_screen.dart`, `l10n/` | **M42** | **Kész (2026-08-19), kalória-becslés nélkül — ld. lent.** A **max magasság** ugyanúgy a teljes lokális nyomvonalból számol, egyszer, a `_finish()`-ben (`buildElevationProfile(trail)?.peak`), mint a legjobb résztávok (C6.3) — így túléli a nyers pontok törlését. Megjelenése **Q-D6 szerint mindkét helyen**: a profil-marker már megvolt a C8.3-as diagramban, ez a szám **másik otthona**, ami a degradált (nyomvonal nélküli) nézetben is megmarad — a fő metrika-rácsban jelenik meg, **ugyanolyan adat-jelenlét alapú kapuzással, mint az emelkedés** (nem túra-specifikus, minden DISTANCE tevékenységnél megjelenik, ha van érték). A **hátizsák-súly** viszont **kizárólag túránál látszik** (kész-ha), és a `log_cardio_sheet.dart`-on (utólagos naplózás) és a `cardio_summary_screen.dart`-on (szerkesztés az összegzésen) is bevihető — a szerkesztett-jelvény itt **„kézzel"**, nem „szerkesztve" (M42), mert nincs mért alapérték, amit felülírna. **Eltérés a tervezett fájllistától:** mindkét mező teljes mobil vezérlést igényelt a nullától (domain mező, drift **V41** oszlop, repository, delta-sync, watch-merge) — ugyanaz a helyzet, mint C8.4-nél: a C8.1 csak a backendet építette meg. **A kalória-becslés (a lépés címének második fele) nem készült el** — a felhasználóval egyeztetve (explicit rákérdezés): a kódbázisban sehol nincs kalória-becslő motor (sem MET-tábla, sem testsúly-alapú képlet), és a tervdokumentumokban sincs hozzá rögzített képlet (szemben a GAP-pal, ahol a Minetti-hivatkozás konkrét volt). A kész-ha ezáltal **triviálisan teljesül** (nincs becslés, ami felülírhatna egy órás kalória-adatot) — nyitott kérdésként hagyva a jövőre, ugyanaz a fajta tudatos scope-szűkítés, mint a C8.6 időjárás-forrásé |
| **C8.6** ✅ | **Időjárás mező** (Q-C8.1: kézi bevitel, nincs külső API) — hőmérséklet, szél, csapadék, a hátizsák-súlyéval azonos „kézzel" szerkesztési mintával | `domain/workout_session.dart`, `domain/weather_condition.dart` (új), `core/local_db/tables/workout_session_tables.dart` (V42), `core/local_db/app_database.dart`, `data/workout_session_repository.dart`, `core/sync/pull_engine.dart`, `core/format/cardio_formatter.dart`, `presentation/log_cardio_sheet.dart`, `presentation/cardio_summary_screen.dart`, `l10n/` | **M42** | **Kész (2026-08-20)** — nincs hálózati hívás, tehát nincs mit időzíteni vagy hibakezelni (a régi kész-ha triviálisan teljesül). A négy mező (hőmérséklet, szél, csapadék, `weatherCondition` szabad kód) egy **snapshot**, ezért együtt szerkeszthető, egyetlen lapon (`_editWeather`), nem négy külön `promptNumber`-koppintással, mint a hátizsák-súlynál — a hőmérséklet **előjeles** (téli túrák), ez az egyetlen mező a screenen, ahol a beviteli mező negatív számot is elfogad (`_numericField`/a lap saját `TextFormField`-jei kaptak egy `signed` ágat, mert a meglévő minta ezt korábban sehol nem engedte). A `weatherCondition` egy kódolatlan string (`CLEAR`/`PARTLY_CLOUDY`/`CLOUDY`/`RAIN`/`SNOW`/`WINDY`), a kliens fordítja ikonná (`weather_condition.dart`), ugyanaz a precedens, mint a `gameFormat`. **Megadás nélkül a mező üres marad, nem 0**: a kártya helyén egy koppintható „Nincs időjárás-adat" sor jelenik meg — **eltérés az M42 mockup szövegétől**, ami szerint a kártya „nem jelenik meg" adat nélkül; itt marad egy kompakt, tappelhető sor, hogy egy utólag felfedezett hiányzó időjárás-adat pótolható legyen az összegzésen is, ugyanúgy, mint minden más kézzel bevihető mező ezen a képernyőn. A max magassághoz hasonlóan a kártya **részleges** állapotot is kezel: amelyik érték hiányzik, „—" jelenik meg helyette, a többi nem tolódik el. Csak túránál látszik (kész-ha) |
| **C8.7** ✅ | PR-bővítés: **max magasság** + statisztika-metrika | `domain/cardio_personal_record.dart`, `features/statistics/domain/stat_metric.dart`, `features/statistics/application/stat_chart_data.dart`, `features/statistics/presentation/statistics_screen.dart`, `presentation/cardio_summary_screen.dart`, `l10n/` | – | **Kész (2026-08-20)** — `CardioPrType.greatestMaxAltitude`, DISTANCE család (nem csak túra, ugyanaz a kapuzás, mint `greatestElevationGain`), `CardioFormatter.elevation`-nal formázva az ünneplő dialógusban és a rekord-sávon. A statisztika oldalon `StatMetric.cardioMaxAltitude` **nem összegez** (`greatestElevationGain`/`cardioElevationGain` mintája helyett) — a `maxHeartRate` „napi maximum, majd napok közötti átlag" mintáját követi (`_maxAltitudePoints`), mert egy csúcsmagasság nem összeadható szám: két 750 m-es csúcs egy napon nem lesz együtt 1500 m. A meglévő statisztikai számok **bitre változatlanok** — a `stat_chart_data_test.dart` teljes, korábbi esetlistája módosítás nélkül zöld, ez maga a regressziós háló ([59 §11](59-cardio-implementation-plan.md) mintája, ahogy a C9.5-nél is) |

**Elfogadás (MF6d)**

- [x] Egy túra magasságprofilja a valós táv mentén rajzolódik, a GPS-hézag látszik — kumulált táv-tengely, arányos hézag-sáv (`elevation_profile_test.dart`, C8.3)
- [x] A GAP sosem „javít" lefelé sík terepen — sík terepen bitre a nyers tempóval egyezik (`grade_adjusted_pace_test.dart`, C8.2)
- [x] Az időjárás-lépés kihagyásával a C8 többi része teljes értékű marad — a négy időjárás-mező szerkezetileg független a többi C8-mezőtől (waypoint, GAP, hátizsák, magasságprofil), nincs köztük hivatkozás vagy közös kapu (C8.6)

---

## 8. Web (58) — mit lát ebből a webes olvasó nézet

A [58-as terv](58-cardio-web-plan.md) alapjai (WB1–WB7, WB9) **leszállítva**: session-kind
elágazás (`SessionLogger`, `SessionsView`, `ClientWorkoutsTab`), `ActivityChip`, és egy sík
metrika-rács (`CardioSessionDetail.tsx` + `cardioTiles.ts`). **Két tétel viszont a C6–C9 előtt is
hiányzik**: az útvonal-SVG (**WB8**) és egy split-táblázat — a `CardioSessionDetail.tsx`
doc-kommentje ma azt állítja, hogy a nézet „route-free and split-free", mert C4a (GPS) előtt
íródott; ez azóta elavult ténymegállapítás, csak a kód nem követte. Emiatt a C6–C9 webes
megjelenítése **egy közös alapra épül** (**W0w** lent), és csak utána bontható a mobil-iterációk
mintájára négy szeletre.

A [58-as terv](58-cardio-web-plan.md) a sport-specifikumokat (C6–C9) eredetileg nem tárgyalta —
ez a szakasz bontja **lépésekre**, ugyanabban a formában, mint a §4–§7 (lépés · fájlok · frame ·
kész-ha). A web **olvasó marad** ([58 D-W.2](58-cardio-web-plan.md)): semmi nem lesz újonnan
szerkeszthető, csak megjelenik. Egyik Cxw sem feltétele az MF6a–d mobil-elfogadásának — mind
**opcionális, utólagos** lépés, tetszőleges sorrendben kihagyható.

### Design: nincs önálló web-frame a C6–C9-hez

A [`design/Lifey Cardio Sport-specifikumok.dc.html`](design/Lifey%20Cardio%20Sport-specifikumok.dc.html)
canvas **kizárólag mobil-frame-eket tartalmaz** (M33–M45) — nulla web-frame van benne (ellenőrizve
a fájlban: a szekció-fejlécek Doc 61-re és a C6/C7/C8/C9 mobil-frame-ekre hivatkoznak, web-jelölés
sehol). Az egyetlen web-design, ami a sport-specifikumok köréhez kapcsolódik, a
[58 §6](58-cardio-web-plan.md)-ban leírt **W01** (`ActivityChip`) és **W02** (edzéslista-sor) a
[`design/Lifey Cardio Design.dc.html`](design/Lifey%20Cardio%20Design.dc.html)-ban — ezek már le is
szállítottak (`ActivityChip.tsx`, `SessionsView.tsx` kind-ága).

**A C6w–C9w tehát nem kap kész web-mockupot.** Az alábbi lépések a mobil M33/M39/M40/M43/M45
frame-jeinek *adattartalmát* ültetik át a meglévő web vizuális nyelvbe (`StatCard`-rács,
lista-sorok, [../web/06-design-system-web.md](../web/06-design-system-web.md) tokenjei) — a „Frame"
oszlop lent erre a mobil-frame-re mutat referenciaként, nem egy elkészült web-mockupra.

### W0w — Közös alap: útvonal-SVG + split-táblázat + types bővítés ✅

**Kész (2026-08-20).** Előfeltétele volt mind a négy alábbi iterációnak.

| # | Lépés | Fájlok | Frame (referencia) | Kész-ha |
|---|---|---|---|---|
| W0w.1 ✅ | `types.ts` teljes bővítés: `CardioSplitResponse` + `splitType`/`avgWatts`/`intensity` (+ `distanceMeters` javítva nullozhatóra, INTERVAL-hoz); `CardioDetailsResponse` + `best1kSeconds`/`best5kSeconds`/`best10kSeconds`, `avgGapSecondsPerKm`, `backpackWeightKg`, `weatherTempC`/`weatherWindKph`/`weatherPrecipMm`/`weatherCondition`; új `CardioWaypointResponse`; `WorkoutSessionResponse` + `waypoints` | `web/src/features/workouts/types.ts` | – | **Kész** — a backend DTO-kkal (`CardioSplitResponse.java`, `CardioDetailsResponse.java`, `CardioWaypointResponse.java`) egyeztetve minden mező típusosan elérhető; a hat érintett teszt-fixture (`aggregate.test.ts`, `cardioTiles.test.ts`, `cardioSummaryLine.test.ts`, `progress.test.ts`, `recommendation.test.ts`) `waypoints: []`-sel bővült, `tsc --noEmit` és a teljes suite (233 teszt) zöld |
| W0w.2 ✅ | Útvonal-SVG (**58 WB8**, eddig kimaradt): `route_polyline` dekódolása + `path`-rajzolás, a mobil `RoutePainter` vizuális nyelvével | `web/src/features/workouts/routeGeometry.ts` (új, tiszta dekódolás+vetítés), `routeGeometry.test.ts` (új, 11 teszt), `components/RouteSvg.tsx` (új) | mobil `RoutePainter` ([58 D-W.3](58-cardio-web-plan.md): saját rajz, nem térkép) | **Kész** — a dekódolás bitre a mobil `polyline_codec.dart`/`route_encoder.dart` algoritmusa (delta+zigzag, `;`-vel elválasztott szegmensek egy-egy GPS-hézagnál), Web-Mercator vetítés + bounding-box illesztés margóval, ugyanaz a fit-logika, mint a `RoutePainter._Fit`; nyomvonal nélküli session-nél a komponens `null`-t ad vissza, nem üres keretet; a színek CSS-tokenből jönnek (`var(--primary)`/`var(--surface-container)`/stb.), tehát világos és sötét témában is helyesek |
| W0w.3 ✅ | Split-táblázat, család-semleges alap (index · táv · tempó, **szint csak ha van adat** — a mobil Q-D1 „pulzus nélkül" döntése itt is érvényes) — a C6w/C7w bővíti típus-oszloppal | `web/src/features/workouts/cardioFormat.ts` (+ `formatElevationDelta`, tesztelve), `components/CardioSplitsTable.tsx` (új) | M33 (a split-lista tartalma) | **Kész** — üres `session.splits`-nél a táblázat nem renderel; a sorrend `splitIndex` szerint rendezett; a szint-oszlop csak akkor jelenik meg, ha **legalább egy** split hordoz `elevationDeltaM`-et (mobil C6.4 mintája: egyszer mondja ki, nem soronként üres oszlop) |
| W0w.4 ✅ | `CardioSessionDetail.tsx` doc-komment frissítése + a két új komponens bekötése a család szerinti helyre | `web/src/features/workouts/components/CardioSessionDetail.tsx` | – | **Kész** — a komment már nem állítja, hogy a nézet route-/split-mentes; `RouteSvg` + `CardioSplitsTable` a `DISTANCE` családnál jelenik meg, ha van rá adat (MACHINE/GAME-nél egyik sem, egyelőre — az az C7w/C9w köre); `npx eslint` és `npx tsc --noEmit` tisztán fut a teljes érintett fájlkörön |

**Amit a megvalósítás eldöntött:**
- A dekódolás/vetítés **tiszta függvényekben** él (`routeGeometry.ts`), nem a `.tsx`-ben — a projekt
  meglévő mintáját követve (`cardioTiles.ts`/`cardioFormat.ts`), mert a `vitest.config.ts` csak
  `.test.ts`-t futtat, komponens-tesztelés nincs bekötve; így a nem-triviális logika (delta-dekódolás,
  Mercator-vetítés, bounding-box illesztés) mégis tesztelt marad.
- A `CardioSplitResponse.distanceMeters` mezőt **javítottam** `number`-ről `number | null`-ra — a
  backend már a C7.1 óta nullozhatóvá tette INTERVAL splitekhez (`cardio_splits_distance_required_ck`
  csak DISTANCE-re kényszerít), a web típus ezt eddig tévesen nem tükrözte. Ma minden élő split
  DISTANCE típusú (a C7.5 eszközös próbája még nem futott le), tehát ez most még nem észlelhető hiba,
  csak egy előre bebiztosított típus-pontosság.
- `RouteSvg`/`CardioSplitsTable` **csak `DISTANCE` családnál** kötődik be a `CardioSessionDetail`-be —
  a MACHINE „INTERVALLUM-SZAKASZOK" split-nézete (C7w.1) és a GAME zóna-panel (C9w.1) külön lépés,
  nem ennek a közös alapnak a dolga.

### C6w — Futás: legjobb résztávok + tempó-diagram (M33, M34) ✅

**Kész (2026-08-20).** Függés: W0w.

| # | Lépés | Fájlok | Frame | Kész-ha |
|---|---|---|---|---|
| C6w.1 ✅ | Split-táblázat típus-oszlop nélkül elég futásnál — a W0w.3 tábla közvetlen újrahasznosítása | `CardioSplitsTable.tsx`, `messages/en.json`, `messages/hu.json` | M33 | **Kész (2026-08-20)** — nem igényelt új komponens-kódot: a `CardioSessionDetail` már a W0w.4-ben a teljes `DISTANCE` családra (RUNNING/WALKING/HIKING, `activityFamilyOf` — tesztelve `activityType.test.ts`-ben) beköti a táblázatot, típus-oszlop nélkül, a session mindig km/perc-per-km formátumban (a web szándékosan mértékegység-váltó nélküli, `cardioFormat.ts` doc-kommentje). Az egyetlen tényleges változás: a split-táblázat „Pace" fejléce **„Pace/split"**-re módosult (hu: „Tempó/szakasz") — a metrika-rács külön „Pace" csempéjével való ütközés elkerülésére, ugyanaz a felismerés, mint a mobil C6.4 `PACE PER SPLIT` döntése mögött |
| C6w.2 ✅ | „Legjobb résztávok" kártya (1/5/10 km) — csak ha van érték | `web/src/features/workouts/bestEfforts.ts` (új, tiszta sor-építő), `bestEfforts.test.ts` (új, 4 teszt), `components/BestEffortsCard.tsx` (új) | M34 | **Kész (2026-08-20)** — részleges (csak 1 km-es) session-nél csak az az egy sor látszik, teszttel bizonyítva |
| C6w.3 ✅ | Tempó-oszlopdiagram — **opcionális, elhagyható**: a split-táblázat számszerűen ugyanazt az információt adja, egy diagram csak a mobil vizuális párhuzama | `web/src/features/workouts/paceBarGeometry.ts` (új, tiszta geometria, 1:1 port a mobil `PaceBarGeometry`-ből, 19 teszt), `paceBars.ts` (új, `session.splits` → bar-lista, 5 teszt), `components/PaceBarChart.tsx` (új), `CardioSplitsTable.tsx` (+ opcionális `chart` prop) | M33 | **Kész (2026-08-20)** — épült; ugyanazt a `session.splits`-et kapja, mint a táblázat (`buildPaceBars` a táblázattal azonos `splitIndex`-sorrendet ad, tesztelve); a mobil két néma-hiba-védett szabálya bitre átjött: a **részleges (sub-999 m) utolsó szakasz kimarad a skálából, az átlagvonalból és a leggyorsabb-címkéből** (csak fix, lapos magasságot kap), és **azonos idejű splitek mindegyike ugyanarra a közép-magasságra kerül**, nem osztás nullával |
| C6w.4 ✅ | Futás-PR jelvény a session-fejlécen — **a nyitott kérdés web-oldali újraszámolással oldódott meg, ld. lent** | `web/src/features/workouts/cardioBestEffortRecords.ts` (új, 1:1 port a mobil `CardioPrBaseline`/`detectCardioPrs`-ból, 10 teszt), `bestEfforts.ts` (+ `records` paraméter), `components/BestEffortsCard.tsx` (+ amber „record" sor), `CardioSessionDetail.tsx` (+ `history` prop), `SessionsView.tsx` (átadja a már betöltött `sessions`-t) | M34 (csak a pill, az M36 ünneplő dialógus nem web-releváns) | **Kész (2026-08-20)** — a `BestEffortsCard` sora amber háttért + szegélyt + „record" pillt kap, ha a session az adott résztávon **szigorúan jobb** minden korábbi RUNNING session-nél; tesztelve: első futás nem rekord, holtverseny nem rekord, egy későbbi gyorsabb futás nem törli visszamenőleg, WALKING/HIKING session sem termel, sem nem szolgál alapul a rekordhoz |

> **C6w.2 — a tervezett kész-ha pontatlan volt, javítva a megvalósításban.** A doc eredetileg
> `activityType !== 'RUNNING'`-ra gátolta volna a kártyát; a mobil `cardio_session_screen.dart`
> `_finish()`-je viszont a `computeBestEfforts`-ot **a teljes DISTANCE családra** hívja (RUNNING **és**
> WALKING **és** HIKING), nem csak futásra — egy gyors gyaloglásnak vagy túrának is lehet 1/5/10 km-es
> legjobb szakasza, és a mobil `_bestEffortSection`-je sincs `activityType`-ra gátolva, csak a
> null-ellenőrzésre hagyatkozik. A web-kártya ezt követi: `family === 'DISTANCE'`-re kötve
> (`CardioSessionDetail.tsx`), nem `activityType === 'RUNNING'`-ra — a mobillal való adat-paritás
> fontosabb, mint a lépés címében szereplő „futás" szó szerinti értelmezése. Rekord-jelvény (a mobil
> M34 amber „record" pill-je) a **C6w.4**-ben épült meg, alább.

> **C6w.3 — egy kártya, egy fejléc, helyi kiválasztás.** A diagram a
> `CardioSplitsTable` **azonos kártyáján** belül, a „Splits" fejléc alatt jelenik meg (a táblázat
> kapott egy opcionális `chart` prop-ot) — külön kártya + saját fejléc duplikálná a szöveget, a
> mobil M33 is egy szekcióban tartja a diagramot és a listát. A **kiválasztás a diagramon belül
> marad** (kattintás kiemel egy oszlopot), **nem** kereszt-kiemeli a táblázat megfelelő sorát —
> mobilon a kettő egy képernyő-állapot, de a web táblázatnak ma nincs kiválasztás-fogalma, és azt
> bevezetni túlmutatna ezen az opcionális lépésen. 1 splitnél (vagy csupa részlegesnél) a komponens
> `null`-t ad vissza, ugyanaz a mobil C6.4 „1 splitnél nincs diagram" szabálya.

> **C6w.4 — a nyitott kérdés valójában nem backend-döntés volt.** A doc korábban azt feltételezte,
> hogy a cardio-PR-hoz szerver-oldali tárolás vagy egy backend-döntés kell, mert a mobil
> `CardioPersonalRecord`-ja kizárólag a kliensen dől el. Ez félrevezető volt: a mobil PR-motor maga
> sem tárol semmit — a `CardioPrBaseline.fromSessions()` minden indításkor **újraszámol** a korábbi
> session-ökből (`domain/cardio_personal_record.dart`, ld. a doc-kommentjét: „never persisted").
> A web pontosan ugyanezt tudja tenni: a `SessionsView` már **be is tölti a teljes session-listát**
> (`workoutSessionApi.list()`, ugyanaz a `sessions`, amit a `SessionLogger` `history` propként kap az
> erősítős „Previous" oszlophoz) — a cardio-nézetnek csak ugyanezt kellett átvennie.
>
> A `cardioBestEffortRecords.ts` a mobil `CardioPrType.fastest1k/5k/10k` + `CardioPrBaseline` +
> `detectCardioPrs` szeletét ülteti át (a teljes 8-típusos PR-motor helyett szándékosan csak ez a
> három — a lépés címe is csak a futás-résztávakról szól): egy adott session-hez a **nála korábban
> befejezett, RUNNING típusú** session-ökből épít alapvonalat típusonként a minimumból, majd
> „szigorúan jobb, mint az alapvonal" alapján dönt. Ugyanazok a szabályok, mint mobilon: **holtverseny
> nem rekord**, **az első futás sem az** (nincs mit megdönteni), és a WALKING/HIKING session-ök
> **sem termelnek, sem nem szolgálnak alapul** — a `BestEffortsCard` őket is megjeleníti (C6w.2), de
> a rekord-motor RUNNING-ra szűkített, a mobil `appliesTo`-jával egyezően.

### C7w — Szobabicikli: intervallum-splitek + összmunka (M38, M39) ✅

**Kész (2026-08-20).** Függés: W0w. **A szerkesztő nem kerül webre** ([58 D-W.1](58-cardio-web-plan.md))
— csak a végrehajtott terv olvasása.

| # | Lépés | Fájlok | Frame | Kész-ha |
|---|---|---|---|---|
| C7w.1 ✅ | Split-táblázat `splitType`-ág: `INTERVAL` sorok intenzitás-sávval a táv oszlop helyén (a mobil C7.6 „INTERVALLUM-SZAKASZOK" kártyájának web-megfelelője) | `CardioSplitsTable.tsx` (bővítve) | M39 | **Kész (2026-08-20)** — `DISTANCE` és `INTERVAL` típusú split egy táblázaton belül is helyesen jelenik meg: a teljes fejléc/sor-elrendezés vált, ha **bármelyik** split `INTERVAL` (index · intenzitás-sáv · időtartam · watt), a tisztán `DISTANCE` ág **bájtra változatlan** maradt (regresszió-mentes — a korábbi ✅ lépések tesztjei is zöldek); egy `DISTANCE` split intervallum-módban a saját táv+időtartam adatával jelenik meg, nem hasal el |
| C7w.2 ✅ | Összmunka (kJ) + gép-kalória két oldala — ugyanaz a képlet, ismételve a webes formázóban (`totalWorkKj = avgWatts × movingSeconds / 1000`, a mobil `CardioFormatter` párja) | `web/src/features/workouts/cardioFormat.ts` (+ 4 teszt), `cardioTiles.ts`, `components/TotalWorkCard.tsx` (új), `components/CalorieCard.tsx` (új) | M39 | **Kész (2026-08-20)** — **paritás-teszt**: a `cardio_formatter_test.dart` „totalWorkKj" csoportjának mind a 4 esete ugyanazokkal a bemenetekkel fut, zöld; watt nélkül (vagy `movingSeconds` nélkül) nincs kJ-csempe (`TotalWorkCard` `null`-t kap a hívótól, nem renderel) |
| C7w.3 ✅ | A terv **neve** nem jelenik meg (session→terv hivatkozás nincs, [D-C7.1](#d-c71--az-intervallum-terv-külön-entitás-a-végrehajtás-pedig-a-cardio_splits-be-megy)) — csak a végrehajtott szakaszok száma, ugyanaz a döntés, mint a mobil C7.6 fejléc-chipjén | – (a C7w.1 `CardioSplitsTable` fejléc-chipjének döntése) | M39 | **Kész (2026-08-20)** — a webes fejléc-chip is szakasz-számot ír (`{count} szakasz`/`{count} sections`), nem terv-alakot — konzisztens a mobillal |

> **C7w.2 — nincs „hero-csere" elrendezés weben, és az `avgWatts` csempe eltűnt a rácsból.**
> A mobil M39 a `_TotalWorkCard`-ot **a rács fölé, hero-pozícióba** teszi (a mozgásidő-kártya
> helyére), watt nélkül pedig a mozgásidő marad a hero. A web ehelyett a saját, már kialakult
> mintáját követi: a metrika-rács **mindig elöl van**, minden család esetén egyformán (ez már a
> C1w óta így van, egyetlen más lépés sem tért el ettől) — a kJ-kártya alája kerül, a rács
> family-specifikus kártyáival egy sorban. Az **adat** megegyezik, csak a lap-pozíció tér el.
> Emiatt a rács `avgWatts`-csempéje **eltűnt** — a mobil sosem mutatta önálló rács-csempeként,
> csak a hero-kártyán belül; a web most ezt követi, ahelyett hogy ugyanazt a számot kétszer írná
> ki (egyszer kicsiben a rácsban, egyszer nagyban a `TotalWorkCard`-on). Ez **eltérés a korábban
> leszállított kóddal szemben** — a régi, önálló `avgWatts` rács-csempét ez a lépés törölte,
> tesztekkel bizonyítva, hogy ma sehol nem jelenik meg csempeként.
>
> **A `CalorieCard` mindig megjelenik MACHINE-nél**, akkor is, ha mindkét oldal `null` (mindkettő
> „—"-t mutat) — bitre a mobil viselkedése, és eltér ennek az oldalnak a többi kártyájától, amik
> adat nélkül el szoktak tűnni. A lábjegyzet (miért nem adjuk össze a két számot) akkor is
> értékes információ, ha épp nincs egyik szám sem.

### C8w — Túra: valódi magasságprofil + útpontok az útvonal-SVG-n (M40, M41, M42) ✅

**Kész (2026-08-20).** Függés: W0w.

| # | Lépés | Fájlok | Frame | Kész-ha |
|---|---|---|---|---|
| C8w.1 ✅ | Magasságprofil, **egyszerűsített** változat: a webnek nincs hozzáférése a lokális nyers track-pontokhoz (azok csak a telefonon élnek, [52 D-C1.2](52-cardio-domain-backend-plan.md)) — csak a `route_polyline` + a session szint-adatai állnak rendelkezésre, tehát a web **mindig** a mobil „EGYSZERŰSÍTETT" nézetét kapja, sosem a valódi (C8.3) profilt | `web/src/features/workouts/routeGeometry.ts` (+ `flattenAltitudes`, 3 teszt), `components/ElevationProfileChart.tsx` (új) | M40 (csak az „EGYSZERŰSÍTETT" jelvényes állapot) | **Kész (2026-08-20)** — a jelvény **mindig** látszik weben, nem csak degradált esetben; az X-tengely **szintetikus pontindex**, nem valódi táv — a mobil tényleges fallback-kódját portoltam (nem egy feltételezett, „szebb" táv-alapú verziót), mert a polyline nem hordoz időbélyeget és a mobil sem rajzol valódi tengelyt ebben az állapotban |
| C8w.2 ✅ | Útpont-markerek a `RouteSvg`-n, számozva, a mobil `RoutePainter` mintájával | `RouteSvg.tsx`, `routeGeometry.test.ts` (+ 50 útpontos teszt) | M41 | **Kész — ez már a W0w.2-ben leszállt** (a `RouteSvg` a kezdetektől számozott waypoint-markereket rajzol), csak a kész-ha explicit tesztje hiányzott; most pótolva: 50 útponttal a geometria minden pontja véges koordinátát ad |
| C8w.3 ✅ | Útpont-lista (sorszám · magasság) — **a táv/idő oszlop kimaradt, ld. lenti megjegyzés: nincs miből számolni** | `web/src/features/workouts/components/WaypointsList.tsx` (új) | M41 | **Kész (2026-08-20)** — üres `waypoints[]`-nél a lista nem jelenik meg; HIKING-only |
| C8w.4 ✅ | Túra-mezők csempéi: GAP, hátizsák-súly, max magasság, időjárás — a `cardioTiles.ts` DISTANCE-ágának bővítése | `cardioFormat.ts` (+ 5 formázó, 5 teszt), `weatherCondition.ts` (új, 4 teszt), `cardioTiles.ts` (+ 6 teszt), `components/WeatherCard.tsx` (új) | M42 | **Kész (2026-08-20)** — hátizsák csak HIKING-nél, **mindig** csempe (mobil-paritás: „—", ha nincs érték, nem tűnik el); max magasság **a teljes DISTANCE családra**, nem csak HIKING-re (Q-D6, ugyanaz a kapuzás, mint a szintemelkedésé — ld. lenti megjegyzés a tervezett kész-ha pontatlanságáról); GAP csak HIKING-nél, de **presence-gated, nem „—"-fallback** (ld. lenti megjegyzés: gyakorlatban ma sosem jelenik meg); időjárás csak akkor jelenik meg, ha legalább egy mező ki van töltve |

> **C8w.3 — a tervezett „táv · idő" oszlop nem épült meg: a mezők nem léteznek sehol.** A doc
> eredetileg azt feltételezte, hogy ezek **szerveren tárolt** waypoint-mezők, csak nem a helyi
> track-ponthoz igazítva — ez tévedés volt. A `CardioWaypointResponse`
> (`backend/.../dto/CardioWaypointResponse.java`) **kizárólag** `waypointIndex`, `latitude`,
> `longitude`, `altitudeMeters`, `label` mezőket hordoz — se táv, se időbélyeg nincs sehol
> perzisztálva. A mobil `_WaypointRow` „táv · magasság · idő" hármasát a **`matchWaypointsToTrail`**
> állítja elő, kizárólag a session **lokális** nyers track-pontjaiból (amik csak a rögzítő
> telefonon élnek, [52 D-C1.2](52-cardio-domain-backend-plan.md)) — ez a webnek **soha, egyetlen
> session esetén sem** érhető el, nem csak a régieknél. A `WaypointsList` ezért csak azt mutatja,
> amit a szerver ténylegesen ismer: sorszám + magasság (a waypoint saját, mentett
> `altitudeMeters`-e — ugyanaz a fallback-érték, amit a mobil is használ, ha a track-illesztés nem
> ad semmit) + a `label`-t, ha valaha lesz (V1-ben Q-D5 szerint mindig `null`).
>
> **C8w.4 — a GAP-csempe hiánya utólag javítva (2026-08-20), mobil-oldali follow-upként.**
> A `grade_adjusted_pace.dart` (C8.2) képletét **soha semmi nem hívta meg** a
> `cardio_session_screen.dart` `_finish()`-ében — a backend oszlop és a DTO-mező létezett, a
> képlet is, de az `avgGapSecondsPerKm` mezőt **a teljes mobil-oldali plumbing hiányzott**: nem
> csak a `_finish()`-hívás, hanem maga a `CardioMetrics` domain-mező, a drift-oszlop, a
> repository read/write és a `pull_engine` leképezés is — a C8.2 kész-ha csak a képletet és a
> dokumentálást ígérte, semmi mást. Ezt a webes C8w.4 munka közben derítettük ki, és **ugyanebben
> a beszélgetésben ki is javítottuk**, nem csak felvettük egy jövőbeli feladatnak:
> - **Drift V43**: új `avg_gap_seconds_per_km` oszlop a `cardio_details` táblán, nullázható,
>   backfill nélkül (a régi, már törölt nyers pontú session-ök úgysem tudnák visszaszámolni).
> - `CardioMetrics` domain-osztály + `fromJson` + `mergedWithWatchMeasurement` bővítve.
> - `workout_session_repository.dart` (write/read/outbox JSON) és `pull_engine.dart` (pull-oldali
>   leképezés) mind a meglévő mezők mintáját követve bővítve.
> - `cardio_session_screen.dart` `_finish()`-e most **HIKING-nél** meghívja
>   `computeGradeAdjustedPaceSecondsPerKm(trail)`-t, ugyanabból a szűrt nyomvonalból, ugyanabban a
>   pillanatban, mint a legjobb-résztávakat és a csúcsmagasságot (C6.3/C8.5 mintája) — RUNNING/
>   WALKING-nál a mező marad `null` (M42 „TEREP" blokkja kizárólag túrán jelenik meg).
> - Tesztek: 2 új widget-teszt a `_finish()`-bekötésre (hegymászó nyomvonal → nem-null GAP;
>   RUNNING → `null`), 2 új repository-teszt (kerekre zárás a helyi soron/payloadon/`watchAll`-on
>   át, illetve `null`-nál nem 0). **870/870 meglévő teszt is zöld maradt** (`flutter test
>   test/features/workouts/ test/core/local_db/ test/core/sync/`), `dart analyze lib/` tiszta.
>
> A web `cardioGapLabel` csempéje (presence-gated, C8w.4) **mostantól ténylegesen meg is jelenik**
> egy frissen rögzített túránál — a mobil-oldali javítás nélkül csak elméletben lett volna helyes.

### C9w — Játék: pulzuszóna-eloszlás + box score (M43, M44, M45) ✅

**Kész (2026-08-20).** Függés: W0w.

| # | Lépés | Fájlok | Frame | Kész-ha |
|---|---|---|---|---|
| C9w.1 ✅ | Pulzuszóna-panel — a mobil `hr_zone_breakdown.dart` képletének web-megfelelője (5 zóna, vágás a bruttó időre, `exceedsGross`-eset) | `web/src/features/workouts/hrZoneBreakdown.ts` (új), `hrZoneBreakdown.test.ts` (új, 14 teszt), `components/HrZonePanel.tsx` (új) | M43 | **Kész (2026-08-20)** — **paritás-teszt**: a `hrZoneBreakdown.test.ts` a mobil `hr_zone_breakdown_test.dart` mind a 14 esetét ugyanazokkal a bemenetekkel futtatja (§9 kockázati sor: dupla-írás a vágást és az `exceedsGross`-t is kiváltja), mind zöld; zóna-adat nélkül (vagy csupa nulla zónánál) `buildHrZoneBreakdown` `null`-t ad, a panel nem jelenik meg |
| C9w.2 ✅ | Box score csempék: pont/gól + gólpassz + lepattanó (ma csak `scorePoints` jelenik meg — `scoreAssists`/`scoreRebounds` hiányzik a `cardioTiles.ts` GAME-ágából) | `cardioTiles.ts`, `messages/en.json`, `messages/hu.json` | M44 (csak az érték-megjelenítés, a léptető nem releváns egy olvasó nézeten) | **Kész (2026-08-20)** — kosárnál 3, focinál 2 mező **adat alapján, nem `gameFormat` alapján** (ld. lenti megjegyzés); nulla érték is megjelenik (tesztelve) |
| C9w.3 ✅ | Formátum csempe (`gameFormat`) — **helyszín (`venue`) már korábban is megjelent**, ld. lenti megjegyzés | `cardioTiles.ts` (a fenti C9w.2-vel egy módosításban) | M45 | **Kész (2026-08-20)** — a `gameFormat` mező megjelenik, ha van érték; hiányzó `gameFormat`-nál nincs csempe (tesztelve) |

> **C9w.1 — elhelyezés és egy szándékos szóhasználat-eltérés.** A Q-D7 mobil-szabálya
> („DISTANCE: splitek után, GAME: a domináns szám után, MACHINE: a »nincs útvonal« kártya után")
> webre fordítva: **DISTANCE** a split-táblázat/diagram-kártya után, **MACHINE** és **GAME** pedig
> közvetlenül a metrika-rács után — a webnek nincs se „domináns szám" elrendezése, se „nincs
> útvonal" kártyája, amihez a szabály szó szerint igazodna, a lényeg (a zóna-panel a család-specifikus
> tartalom **után** jön) viszont átjön. **Nincs saját `WorkoutSessionResponse`-mező-hozzáadás** —
> a panel a meglévő `hrZone1..5Seconds` és `startedAt`/`finishedAt` mezőkből épül.
>
> **Szóhasználat-eltérés a mobiltól, tudatosan.** A mobil magyar fordítása (`app_hu.arb`) a
> `hrZoneVerdictHard`/`hrZoneVerdictEasy` chip-szöveget mindig „kemény meccs"/„könnyű meccs"-nek
> mondja — **minden** cardio-típusra, holott a panel maga „egy komponens minden cardio-típusra" (Q-D7),
> tehát ez egy mobil-oldali fordítási pontatlanság (futásnál/biciklinél sem „meccs" zajlik). A webes
> fordítás ezt **nem** másolja: „kemény edzés"/„könnyű edzés" (hu), generikus „hard session"/
> „easy session" (en) — helyesebb, és nem egy meglévő hibát ültet át egy új namespace-be. Ez a
> mobil-kódot nem érinti, csak a web saját `messages/hu.json`/`en.json` szövegét.

> **C9w.2/C9w.3 — két pontatlanság a tervben, javítva a megvalósításban.**
>
> 1. **A „kosárnál 3, focinál 2 mező" nem `gameFormat`-tól függ** (ahogy a doc eredetileg írta),
>    hanem attól, hogy a mezőnek **van-e értéke** — pontosan úgy, ahogy a mobil `cardio_summary_screen.dart`
>    is teszi: `_scoreRebounds != null` dönt, nem az `activityType` vagy a `gameFormat`. Focinál a
>    `scoreRebounds` egyszerűen sosem kerül kitöltésre (az élő box score-léptető focinál nem ajánlja fel),
>    tehát a null-ellenőrzés **magától** hozza ki a 3-vs-2 különbséget — nem kellett hozzá külön
>    `activityType`-alapú kapu. A pont/gól címke viszont **explicit `activityType === 'BASKETBALL'`**
>    elágazás (mobil: `_activityType == 'BASKETBALL' ? boxScorePointsLabel : boxScoreGoalsLabel`) —
>    ez az egyetlen hely, ahol tényleg a sportág dönt, nem az adat jelenléte.
> 2. **A `venue` csempe már a W0w előtti alapkörben megjelent** — a doc tévesen állította, hogy
>    „egyik sem jelenik meg a GAME-ágban". A `cardioTiles.ts` GAME-ága a `venue`-t már a C1w-s
>    alapkör óta megjelenítette; ebben a lépésben ténylegesen csak a `gameFormat` volt hiányzó.
>
> **A `game_format` kódok kliens-oldali leképezése tudatosan eltér a mobilétól egy ponton:**
> ismeretlen kód esetén a mobil `GameFormat.fromCode(...) ?? GameSetup.defaults.format` csendben
> **„5v5"-re hamisítaná** a címkét (a `??` a hiányzó találatot az alapértékre esteti vissza) — a web
> ehelyett a **nyers kódot** mutatja, ha nincs ismert leképezés. Egy olvasó nézeten a „nem ismerem
> ezt a formátumot, itt a nyers érték" jobb, mint egy csendben rossz „5v5" felirat.

### Sorrend és javaslat

**A teljes §8 web-kör kész** (2026-08-20): W0w, C6w, C9w, C7w, C8w mind leszállítva — nincs
hátralévő opcionális webes lépés.

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
| **C7** Bicikli | 8 | 1 ✅ (M37–M39) | V70 ✅ | MF6c |
| **C8** Túra | 8 | 1 ✅ (M40–M42) | V71 | MF6d |
| *(opcionális)* web | 18 (W0w:4 ✅ + C6w:4 ✅ + C7w:3 ✅ + C8w:4 ✅ + C9w:3 ✅) | – | – | – |

**Összesen 30 lépés** (26 mobil/backend + 4 design), plusz 18 opcionális webes ([§8](#8-web-58--mit-lát-ebből-a-webes-olvasó-nézet)) — **mind a 18 kész** (2026-08-20).
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
