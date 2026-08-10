# 51 – Cardio & sportedzések: koncepció és ütemterv

Státusz: **TERV — nem indult el.**
Nyelv: a terv magyar, a kód/ARB-kulcsok angolok (repo-konvenció).

Kapcsolódó dokumentumok (ebben a mappában):
- [52-cardio-domain-backend-plan.md](52-cardio-domain-backend-plan.md) — domain, migrációk, REST API, delta-sync
- [53-cardio-mobile-plan.md](53-cardio-mobile-plan.md) — Flutter adatréteg, indítási UX, élő képernyő, Live Activity
- [54-cardio-gps-route-plan.md](54-cardio-gps-route-plan.md) — GPS, útvonal, térkép, akku és engedélyek
- [55-cardio-watch-plan.md](55-cardio-watch-plan.md) — Apple Watch / Wear OS, gyakoriság-rendezett picker
- [56-cardio-statistics-plan.md](56-cardio-statistics-plan.md) — statisztika, PR-ok, edzői riportok (a „mi romolhat el”)
- [57-cardio-design-prompt.md](57-cardio-design-prompt.md) — önhordó design prompt a Claude Designnak
- [58-cardio-web-plan.md](58-cardio-web-plan.md) — web: az érintett fájlok és a „nincs indítás webről” döntés

Külső háttér:
- [../16-apple-health-integration-plan.md](../16-apple-health-integration-plan.md), [../26-android-health-connect-integration-plan.md](../26-android-health-connect-integration-plan.md) — health-store írás/olvasás korlátai
- [../watch/40-watch-app-plan.md](../watch/40-watch-app-plan.md) — a watch-híd, amit újrahasználunk
- [../24-ios-widget-live-activity-plan.md](../24-ios-widget-live-activity-plan.md), [../25-android-widget-ongoing-notification-plan.md](../25-android-widget-ongoing-notification-plan.md) — az élő felületek
- [../17-statistics-page-plan.md](../17-statistics-page-plan.md), [../38-personal-records-plan.md](../38-personal-records-plan.md)
- [../design/18-design-system-prompt.md](../design/18-design-system-prompt.md) — a design tokenek

---

## 1. Mit építünk

Ma az app **kizárólag szett-alapú (erősítő) edzést** tud: a `WorkoutSession` gyakorlatokból és
`ExerciseSet`-ekből áll, a `LogSessionScreen` a reps/súly logolásra van szabva, a watch
`traditionalStrengthTraining` konfigurációval indul, a statisztika „edzés” metrikái pedig
szett-jelenlétet feltételeznek.

A cél: **hat új, nem szett-alapú edzéstípus** első osztályú támogatása —

| Kód | Magyar | Angol | Ikon (M3) | Család |
|---|---|---|---|---|
| `INDOOR_BIKE` | Szobabicikli | Indoor bike | `pedal_bike` | gép (`MACHINE`) |
| `RUNNING` | Futás | Running | `directions_run` | táv (`DISTANCE`) |
| `WALKING` | Séta | Walking | `directions_walk` | táv (`DISTANCE`) |
| `HIKING` | Túrázás | Hiking | `hiking` | táv (`DISTANCE`) |
| `BASKETBALL` | Kosárlabda | Basketball | `sports_basketball` | játék (`GAME`) |
| `FOOTBALL` | Foci | Football | `sports_soccer` | játék (`GAME`) |

…**úgy, hogy közben az erősítő edzés, a statisztika, az óra-szinkron és az edzői modul ne
romoljon el.** Ez utóbbi nem mellékmondat: a §6 kockázatlistája és az
[56-os doc](56-cardio-statistics-plan.md) fele erről szól.

### 1.1 A „család” fogalom — ez a terv gerince

Hat edzéstípusra hat külön képernyőt és hat külön metrika-készletet tervezni pazarlás és
karbantarthatatlan. Ehelyett **három családba** soroljuk őket, és a UI/metrika a *családtól*
függ, a konkrét típus csak ikont, nevet, színt és néhány extra mezőt ad:

| Család | Tagok | Mit mérünk | Mit **nem** |
|---|---|---|---|
| `DISTANCE` | futás, séta, túrázás | idő, táv, tempó/sebesség, szintemelkedés, GPS-nyomvonal, körök/splitek, pulzus, kalória | teljesítmény (W), ellenállás |
| `MACHINE` | szobabicikli | idő, táv (gépről), átlagsebesség, kadencia (rpm), teljesítmény (W), ellenállás-fokozat, pulzus, kalória | GPS, szintemelkedés |
| `GAME` | kosárlabda, foci | idő (bruttó és **játékidő**), intenzitás, pulzus + pulzuszónák, kalória, opcionális „box score” (pont/gól/gólpassz), pálya (kint/bent) | táv és tempó *alapból* (GPS-szel opcionálisan igen — lásd C7) |

**Következmény:** a C1–C5 iterációk *családszinten* dolgoznak (egy képernyő három elrendezéssel,
nem hat képernyő), és csak a C6+ iterációk visznek be típus-specifikus finomságokat.

---

## 2. Alapdöntések (D-C.1 … D-C.9)

### D-C.1 — A cardio session **ugyanaz az entitás**, mint az erősítő session

Két út volt:

| Opció | Értékelés |
|---|---|
| **A**: új `CardioSession` entitás + saját tábla, repository, outbox-típus, sync-kurzor, controller | Tiszta séma, de **le kell másolni** a delta-syncet, az outboxot, a watch-hidat, a Live Activityt, a trainer-láthatóságot, az RPE/feedback-hurkot, a trainer-kommentet, a session-listát, a naptárat és a heti riportot. Két „edzés” fogalom a UI-ban és a statisztikában, örökre. |
| **B**: `workout_sessions` + `session_kind` diszkriminátor + `activity_type` + cardio-mezők | **Ez a döntés.** Egy idővonal, egy sync-út, egy watch-híd, egy Live Activity. A már meglévő `activeCalories` / `averageHeartRate` / `healthWorkoutId` mezők pont a cardióra a leghasznosabbak. Ára: a `sets`/`plannedExercises` cardio esetén mindig üres, és minden szett-feltételezést ki kell gyomlálni (§6, R1). |

Diszkriminátor: `session_kind ∈ {STRENGTH, CARDIO}`, alapérték `STRENGTH` — a meglévő sorok
migráció közben ezt kapják, tehát a régi kliensek viselkedése változatlan.

### D-C.2 — Hibrid tárolás: kevés közös oszlop + egy tipizált `cardio_details` tábla + bulk gyerektáblák

- **Nem** EAV (`metric_key`/`value`): megölné a statisztika-lekérdezéseket és a típusosságot.
- **Nem** 25 nullable oszlop a `workout_sessions`-ön: a legforgalmasabb táblánk, minden lista-lekérdezés érinti.
- **Igen**: `workout_sessions`-ön csak a diszkriminátor és ami *minden* edzésre értelmes
  (`session_kind`, `activity_type`, `moving_seconds`), az összes cardio-metrika egy 1:1
  `cardio_details` táblában, a tömeges adat (GPS-pontok, splitek) külön gyerektáblákban.

Részletek: [52-cardio-domain-backend-plan.md §2](52-cardio-domain-backend-plan.md).

### D-C.3 — Az első iteráció **kézi rögzítés**, nem élő mérés

A C1 nem indít stoppert, nem kér GPS-engedélyt, nem nyúl az órához: csak annyit tud, hogy
„megvolt egy 42 perces futás, 7,3 km”. Ez azért így van, mert a teljes adat-út (séma →
API → drift → outbox → delta-sync → lista → statisztika) **önmagában** egy iteráció, és ha
ez nem stabil, minden ráépülő élő funkció hibát fog örökölni. Cserébe a C1 végén már valódi,
szállítható érték van a kezünkben.

### D-C.4 — Egy élő képernyő három elrendezéssel

`CardioSessionScreen`, a család alapján váltó metrika-blokkokkal. **Nem** ágazik el a
`LogSessionScreen`-ből: az szett-központú (gyakorlat-lista, stepper, pihenőidő), a közös
része (időzítő, sticky alsó zóna, zenevezérlés, befejezés-megerősítés) kiemelhető közös
widgetekbe. Lásd [53-cardio-mobile-plan.md §4](53-cardio-mobile-plan.md).

### D-C.5 — A GPS opcionális, és soha nem blokkolja az edzést

Megtagadott/elérhetetlen helymeghatározás mellett is elindul az edzés, csak nyomvonal és
GPS-alapú táv nélkül (a táv ilyenkor kézzel szerkeszthető). Bármi más azt jelentené, hogy egy
engedély-párbeszéd megakadályozza a felhasználót abban, hogy elinduljon futni.

### D-C.6 — Térkép: **saját `RoutePainter`**, nem tile-alapú térkép (első körben)

Az app precedense a `TimeSeriesChart` (saját festés, nincs `fl_chart`). Az útvonalat ugyanígy
saját `CustomPainter` rajzolja a téma színeivel: nulla új függőség, offline is működik, nincs
tile-szolgáltatói licenc/attribúció-kérdés, és a design nyelvébe illeszkedik. Valódi
térképcsempe (`flutter_map` + OSM) külön, opcionális iteráció (C4b), a CLAUDE.md
„ne hozz be új frameworköt indoklás nélkül” szabályához mérten.

### D-C.7 — Az indítás gyorsasága elsőrangú követelmény, nem plusz

Aki futni indul, nem akar öt koppintást. Négy belépési pont, ebben a prioritási sorrendben:
FAB hosszú nyomás → gyorsindító lap; dinamikus app-shortcutok (app-ikon hosszú nyomás);
kezdőképernyő-widget gomb; óra. Részletek: [53-cardio-mobile-plan.md §3](53-cardio-mobile-plan.md).

### D-C.8 — Egy közös „gyakoriság-rangsor”, amit a telefon és az óra is használ

A „leggyakrabban használt edzés kerüljön előre” követelmény **egyetlen** Dart-függvényben él
(`activity_ranking.dart`), és három helyen hívjuk: a telefonos gyorsindítón, az app-shortcutok
frissítésénél és a watch-picker payload összeállításánál. A rangsor **közös** listát ad
(erősítő tervek + cardio típusok együtt), mert az órán is egyetlen listát lát a user.
Képlet és indoklás: [55-cardio-watch-plan.md §3](55-cardio-watch-plan.md).

### D-C.9 — A statisztika „edzés” metrikái **összesítők maradnak**, de kap egy fajta-szűrőt

Nem törjük el a `workoutCount` jelentését (dashboard, heti riport, edzői riport, streak mind
használja) — az „összes edzés” marad. Mellé jön egy `STRENGTH / CARDIO / mind` szűrő és a
cardio-specifikus metrikák (táv, mozgásidő, szintemelkedés, átlagtempó). Az elvi indoklás és a
teljes ütközési lista: [56-cardio-statistics-plan.md](56-cardio-statistics-plan.md).

---

## 3. Metrikakészlet edzéstípusonként (kreatív rész)

Jelmagyarázat: **A** = automatikusan mért/számolt · **G** = gépről vagy órából jön · **K** = kézzel megadható · **S** = származtatott (nem tárolt).

### 3.1 Minden cardióra közös

| Metrika | Forrás | Megjegyzés |
|---|---|---|
| Bruttó idő (`startedAt`→`finishedAt`) | A | Már ma is van |
| **Mozgásidő** (`moving_seconds`) | A | Szünetek és „auto-pause” nélküli idő — ez a valódi edzésidő, ez megy a statisztikába |
| Aktív kalória | G/K | Meglévő `activeCalories` mező, óráról vagy becslésből |
| Átlag-/max pulzus | G | `averageHeartRate` már van; `max_heart_rate` új |
| **Pulzuszóna-eloszlás** (5 zóna, másodperc) | G | Óráról; a `GAME` családnál ez *a* fő intenzitás-mutató |
| RPE (1–10) + jegyzet | K | Meglévő `rpe`/`feedbackNote` — változtatás nélkül működik |
| Időjárás-pillanatkép (hőm., szél, csapadék) | A | *Opcionális, C8* — kültéri edzésnél sokat mond egy tempóról |

### 3.2 `DISTANCE` — futás, séta, túrázás

| Metrika | Forrás | Futás | Séta | Túra |
|---|---|---|---|---|
| Táv (m) | A (GPS) / K | ✅ | ✅ | ✅ |
| Átlagtempó (perc/km) | S | ✅ fő metrika | – | – |
| Átlagsebesség (km/h) | S | – | ✅ | ✅ |
| Km-splitek (idő, tempó, szintkülönbség) | A | ✅ | ✅ | ✅ |
| Szintemelkedés / -csökkenés (m) | A (GPS) / K | ✅ | ➖ | ✅ fő metrika |
| Max magasság (m) | A | – | – | ✅ |
| GPS-nyomvonal (polyline) | A | ✅ | ✅ | ✅ |
| Lépések | G | ➖ | ✅ | ✅ |
| Kadencia (spm) | G | ✅ | – | – |
| **Legjobb résztáv** (1 km, 5 km, 10 km a nyomvonalon belül) | S | ✅ PR-anyag | – | – |
| **Emelkedés-normált tempó** (GAP) | S | ➖ | – | ✅ *(C8)* |
| Hátizsák-súly (kg) | K | – | – | ✅ *(C8)* — kalória-becsléshez |

### 3.3 `MACHINE` — szobabicikli

| Metrika | Forrás | Megjegyzés |
|---|---|---|
| Táv (km) | K/G | A gép kijelzőjéről; C7-ben OCR-/fotó-alapú beolvasás megfontolható |
| Átlagsebesség (km/h) | S | |
| Átlag/max kadencia (rpm) | K/G | |
| Átlag/max teljesítmény (W) | K/G | |
| **Becsült összmunka (kJ)** | S | `avg_watt × moving_seconds / 1000` — összehasonlítható „mennyiség” metrika |
| Ellenállás-fokozat | K | |
| **Intervallum-szerkezet** (szakaszok: idő + cél-intenzitás) | K | C7 — ez a szobabicikli fő értéke: strukturált edzés |
| Gép által kijelzett kalória | K | Külön mezőben, hogy ne keveredjen az óra méréssel |

### 3.4 `GAME` — kosárlabda, foci

| Metrika | Forrás | Megjegyzés |
|---|---|---|
| Bruttó idő vs. **játékidő** | A + K | A padon ülés nem edzés; a lejátszó képernyőn egy nagy „pályán/padon” kapcsoló vezérli a `moving_seconds`-t |
| Pulzuszóna-eloszlás | G | A `GAME` család fő intenzitás-mutatója (nincs tempó, ami rangsorolna) |
| Intenzitás (1–5) | K | Gyors, szubjektív; az RPE-től független, mert a meccs „hullámzik” |
| Helyszín: terem / szabadtér | K | Hat a GPS-elérhetőségre és a kalória-becslésre |
| Formátum (5v5, kispálya, edzés/meccs) | K | |
| Box score: pont / gól / gólpassz / lepattanó | K | *C9* — opcionális, kikapcsolható; ez adja a „miért jó ezt logolni” élményt |
| Táv és sprintek (kültéri, GPS-szel) | A | *C9* — szabadtéri focinál valós érték, teremben kikapcsolva |

---

## 4. Iterációk

Minden iteráció **önmagában szállítható** (a végén az app konzisztens és tesztelhető), és
prompt-méretű. A → nyíl mutatja a kemény függést.

| # | Név | Tartalom | Doc | Függés |
|---|---|---|---|---|
| **C0** | Taxonómia + fundamentum | `SessionKind`, `ActivityType`, `ActivityFamily` enumok (backend + Dart), ikon-/szín-/l10n-térkép, feature flag, **a meglévő szett-feltételezések auditja és javítása** (§6 R1) | 52, 53 | – |
| **C1** | Cardio adat-mag (kézi rögzítés) | Migráció, entitás + `cardio_details`, DTO/mapper, controller-bővítés, delta-sync, drift-táblák, repository, outbox, kézi rögzítő lap, session-kártya ikonnal, lista-szűrő | 52, 53 | C0 |
| **C2** | Élő cardio a telefonon | `CardioSessionScreen` (3 elrendezés), stopper + auto-pause, gyorsindítási felületek (FAB long-press, app-shortcut, widget), resume-prompt, Live Activity / ongoing notification cardio-változat | 53 | C1 |
| **C1w** | Web: cardio megjelenítés | Olvasó cardio részletnézet a szett-logoló helyett, lista- és edzői kártya `kind`-elágazása, útvonal-SVG, i18n. **Webről indítás nincs** (D-W.1) | 58 | C1 |
| **C3** | Statisztika-integráció | Fajta-szűrő, új `StatMetric`-ek, backend `StatisticsResponse` bővítés, dashboard, heti recap, edzői riport, streak, PR-motor cardio-ága | 56 | C1 |
| **C3w** | Web: statisztika-paritás | `aggregate.ts` fajta-szűrő és cardio-adatsorok, dashboard-bontás, paritás-teszt a mobillal | 58 | C3, C1w |
| **C4a** | GPS-nyomvonal | `geolocator`, előtér-szolgáltatás, pont-szűrés, táv/szintemelkedés számítás, polyline-tárolás és -sync, `RoutePainter` útvonalrajz, engedély-utak | 54 | C2 |
| **C4b** | *(opcionális)* Valódi térképcsempe | `flutter_map` + OSM, csak ha a `RoutePainter` kevésnek bizonyul | 54 | C4a |
| **C5** | Óra-integráció | Aktivitás-specifikus `HKWorkoutConfiguration` / `ExerciseType`, cardio aktív képernyő az órán, **gyakoriság-rendezett egyesített picker**, standalone cardio, összegzés-visszaküldés, watch-GPS | 55 | C2 (C4a a watch-GPS-hez) |
| **C6** | Futás-specifikum | Km-splitek, tempó-diagram, kadencia, legjobb résztáv, futás-PR-ok, hangos/haptikus km-visszajelzés | 51 §3.2, 56 | C4a |
| **C7** | Szobabicikli-specifikum | Teljesítmény/kadencia/ellenállás mezők, összmunka, **intervallum-szerkesztő és -lejátszó**, gép-kalória külön | 51 §3.3 | C2 |
| **C8** | Túra-specifikum | Magasságprofil-diagram, max magasság, GAP, útpont-jelölés, hátizsák-súly, időjárás-pillanatkép | 51 §3.2 | C4a |
| **C9** | Játék-specifikum | Pályán/padon kapcsoló és játékidő, pulzuszóna-panel, box score, formátum/helyszín, kültéri GPS-mód | 51 §3.4 | C5 (zónákhoz óra kell) |

**Design-blokkolás — FELOLDVA (2026-08-10).** A [57-es prompt](57-cardio-design-prompt.md)
lefutott, a két canvas elkészült (`design/Lifey Cardio Design.dc.html` — M01–M32 + W01–W02;
`design/Lifey Cardio Watch Design.dc.html` — AW 16–22 / W 15–21), tehát minden UI-t szállító
iteráció indítható. A frame → lépés leképezés és a végrehajtási sorrend:
[59-cardio-implementation-plan.md](59-cardio-implementation-plan.md).

---

## 5. Ami tudatosan kimarad (V1)

- **Edzésterv cardióra** (tervezett intervallum-sablon, mint az erősítő `WorkoutTemplate`) — a C7
  intervallum-szerkesztője ennek a szűkített előfutára, teljes cardio-sablon később.
- **Edző által ütemezett cardio** (`workout_schedules` / program-hozzárendelés cardióval) —
  a séma bírná (a `scheduledFor` a session-ön van), de az edzői web-admin és a naptár UI
  bővítése külön munka. **A backendnek viszont már a C1-ben hibátlanul kell viselkednie, ha egy
  cardio session-t megnyit egy edző** (§6 R4).
- **Élő pulzus a telefon képernyőjén** párosítatlan mellkasi/karpánt-szenzorból (BLE) — az óra
  fedi a use case-t.
- **Úszás** (vízálló-specifikus mérés, medence-hossz) és **túra közbeni navigáció** (útvonal
  betöltése, követés).
- **Fotó/média az edzéshez** (túra-képek a nyomvonalon).

---

## 6. Kockázatok — „mi romolhat el”

| # | Kockázat | Miért reális | Kezelés |
|---|---|---|---|
| **R1** | **Szett-feltételezések a meglévő kódban.** Egy cardio session `sets` és `plannedExercises` listája üres — bárhol, ahol a kód `sets.first`, „domináns izomcsoport”, „összes emelt súly”, „gyakorlatszám”, vagy nem üres lista feltételez, hibás kimenet vagy kivétel keletkezik. | A `session_row_plan.dart`, `personal_record.dart`, `watch_session_merge.dart`, `recommended_template_provider.dart`, a session-kártya és a backend `ExerciseSummary` mind ilyen. | **A C0 kötelező eleme egy audit**: `sets`/`plannedExercises`/`templateName` minden olvasási helye, `kind`-tudatos ággal vagy explicit üres-kezeléssel. Regressziós teszt: egy üres session minden képernyőn megnyitható. |
| **R2** | **Statisztika-ugrás.** A `workoutCount`, `workoutMinutes` és az edzői/heti riportok egyik napról a másikra megugranak, mert a séta is „edzés”. | A dashboard, a heti recap, a streak és az edzői riport mind ugyanabból számol. | D-C.9 + [56-os doc](56-cardio-statistics-plan.md): a jelentés marad „összes edzés”, mellé fajta-bontás és -szűrő kerül; a streak-szabály **eldöntve** (§8 Q1): ≥ 15 perc mozgásidő vagy erősítő session. |
| **R3** | **Delta-sync és a gyerektáblák.** A [16-delta-sync-rollout](../16-delta-sync-rollout.md) szerint csak a szülő `WorkoutSession` van delta-syncelve, a gyerekek nincsenek önállóan tombstone-ozva — egy „csak GPS-pont változott” írásnál a szülő `updatedAt`-jét kézzel kell bumpolni. | Pontosan ez a hiba már megtörtént a `WorkoutSessionServiceImpl#update`-ben, a kód kommentje ezt őrzi. | A `cardio_details` / `cardio_track_points` / `cardio_splits` **ugyanezt a mintát** követi, és a [52-es doc §4](52-cardio-domain-backend-plan.md) kötelező lépésként írja elő a bumpolást + tesztet. |
| **R4** | **Edzői modul és web.** Az edző kliens-nézete, a naptár-előnézet és a web session-megnyitása gyakorlat-listát vár — a `SessionLogger` egyenesen szett-logolót nyitna egy cardio edzésre. | `docs/personal_trainer/*`, `docs/web/*` — külön kódbázis; a konkrét fájlok és sorok: [58-cardio-web-plan.md §2](58-cardio-web-plan.md) | A C1 backend-változás **additív** (a DTO minden meglévő mezőt hoz, csak `exercises: []`-vel — semmi nem NPE-zik, de „üres edzés” látszik). A javítás a **C1w** iteráció, ami a C1 után önállóan futtatható. Webről cardiót indítani **nem** lehet (D-W.1) — ott a scope tudatosan olvasó. |
| **R5** | **GPS akkumulátor és háttér-leállítás.** Egy 4 órás túra alatt az OS megölheti az app folyamatát. | Android háttér-korlátozások, iOS suspend. | [54-es doc](54-cardio-gps-route-plan.md): előtér-szolgáltatás + `allowsBackgroundLocationUpdates`, adaptív mintavétel, minden pont **azonnal** a driftbe íródik (crash-túlélő), a session újranyitásakor helyreállás. |
| **R6** | **Óra: rossz aktivitástípus → rossz kalória.** Ha minden cardio `.other`-ként indul, a HealthKit/Health Connect kalóriabecslése rossz lesz, és a ring-kreditelés is. | A watch app ma fixen `traditionalStrengthTraining`. | [55-ös doc §2](55-cardio-watch-plan.md): explicit típus-térkép mindkét platformra, `locationType` (indoor/outdoor) beállítással. |
| **R7** | **Túl sok új nullable mező** → a mapper és a payload elfajzik. | 3 család × 10 metrika. | D-C.2 hibrid tárolás + családonkénti DTO-blokk; a payload csak a kitöltött blokkot viszi. |
| **R8** | **Kézi + mért adat ütközése** (a user beír 7 km-t, a GPS 6,8-at mér). | Gyakori, ha rossz a jel. | Minden metrikának van `source` jelzése (`MEASURED` / `MANUAL` / `DEVICE`); a kézi felülírás nyer és megjelölődik, a UI mutatja („kézzel szerkesztve”). |

---

## 7. Elfogadási feltételek (iterációnként, pass/fail)

**C0**
- [ ] `SessionKind`, `ActivityType`, `ActivityFamily` létezik backend- és Dart-oldalon, azonos kódokkal
- [ ] Minden `sets`/`plannedExercises` olvasási hely auditálva; üres listával egyik képernyő sem dob és nem mutat „NaN”-t
- [ ] Ikon-, szín- és l10n-térkép a hat típusra (HU + EN kulcsok)

**C1**
- [ ] Cardio session létrehozható, szerkeszthető, törölhető offline is, és delta-synccel átér
- [ ] A session-lista ikonnal különbözteti a fajtákat, van fajta-szűrő
- [ ] Egy cardio session megnyitása az edzői web-admin nézetében nem hibázik
- [ ] Meglévő erősítő session viselkedése bitre azonos (regressziós teszt)

**C2**
- [ ] Az edzés indítható a FAB hosszú nyomásából ≤ 2 koppintással, app-shortcutból ≤ 1-ből
- [ ] Az élő képernyő mindhárom családban helyes metrikákat mutat; szünet/folytatás/befejezés működik
- [ ] Live Activity / ongoing notification cardio-változatot mutat, nem „0 szett”-et
- [ ] Az app megölése után az edzés helyreáll (resume-prompt)

**C3**
- [ ] A statisztika fajtánként szűrhető, a cardio-metrikák chartolhatók
- [ ] A dashboard/heti recap/edzői riport számai definíció szerint helyesek és dokumentáltak
- [ ] A PR-motor cardio-PR-t is számol, és erősítő PR-t nem számol cardio session-ből

**C4a**
- [ ] Engedély megtagadva → az edzés attól még elindul és rögzíthető
- [ ] 60 perc futás nyomvonala ≤ 5% táv-hibával, az akku-fogyás dokumentálva
- [ ] Az útvonal megjelenik a session összegzésén, mindkét témában

**C5**
- [ ] Az óráról indítható mind a hat típus, a picker a leggyakoribbakat mutatja elöl
- [ ] Az óra a helyes aktivitástípussal indul, és az összegzés a telefon session-jébe kerül

---

## 8. ✅ Döntések (eldöntve 2026-08-09)

| # | Kérdés | Döntés |
|---|---|---|
| Q1 | Számít-e egy 10 perces séta „edzésnek” a streakben? | **Igen, 15 perc *mozgásidőtől*** (`moving_seconds ≥ 900`), és egy `STRENGTH` session mindig számít, hossztól függetlenül. **Nem beállítás.** Indoklás lent. |
| Q2 | A meglévő `CARDIO` **izomcsoport**-kód (`exercise_enums.dart`) és az új `ActivityType` együttélése zavaró? | Együtt élnek: az egyik gyakorlat-címke, a másik session-típus. A C0-ban az l10n-kulcsokat egyértelműsítjük (`muscleGroupCardio` vs. `activityTypeRunning`). |
| Q3 | Kell-e a kézi cardio-rögzítéshez „múltbeli dátum” választás már a C1-ben? | **Igen**, a C1 része — enélkül a funkció fele hiányzik (tegnapi meccs beírása). |
| Q4 | A gép-kalória (szobabicikli kijelzője) beleszámítson-e a napi aktív kalóriába? | **Nem.** Külön mezőben tároljuk, és **csak akkor** számít, ha az adott sessionhöz nincs óra-/Health-mérés. Összeadni soha nem szabad. |
| Q5 | Kültéri foci GPS-e alapból be vagy ki? | **Ki.** A helyszín-választó („szabadtér”) ajánlja fel egy kapcsolóval. |

**Q1 — miért a mozgásidő, és miért nem beállítás.** A mozgásidő az egyetlen szám, ami mindhárom
családban ugyanazt jelenti, és amit nem lehet azzal megszerezni, hogy valaki nyitva felejti az
appot — a bruttó idő pontosan ezt engedné. Fix küszöb, mert a streak összehasonlítható szám: ha
minden felhasználónál mást jelent, az edző riportjában sem jelent semmit, és „nálam miért nem
számított be” típusú kérdéseket termel. Ami **nem** következik belőle: a 12 perces séta ettől még
felkerül a listára és beleszámít minden statisztikába — csak a streaket nem hosszabbítja meg.
A kézi rögzítés ugyanezen a szabályon megy át, mert az is mozgásidőt hordoz.

**Q4 — miért nem adjuk össze.** A gép száma egy modell (teljesítmény + általános testsúly), az
óráé egy *ezen a testen* végzett mérés. A kettő összege nem pontosabb, hanem duplán számol, és
éppen a napi aktív kalória az a szám, ami a **táplálkozási keretbe** folyik be — ott egy
felfújt érték valódi kárt okoz. A gép-értéket a felületen is jelöljük (honnan jött), hogy a
felhasználó lássa, miért különbözik az órájáétól.
