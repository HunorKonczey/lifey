# 53 – Cardio: mobil (Flutter) terv

Státusz: **TERV.** Iterációk: **C0** (audit + taxonómia), **C1** (adatréteg + kézi rögzítés),
**C2** (élő edzés + gyorsindítás + Live Activity).
Előzmény: [51-cardio-overview-plan.md](51-cardio-overview-plan.md), séma:
[52-cardio-domain-backend-plan.md](52-cardio-domain-backend-plan.md).
GPS: [54-cardio-gps-route-plan.md](54-cardio-gps-route-plan.md) (C4a) — ez a doc GPS nélkül is teljes.
Design: **kész** — `design/Lifey Cardio Design.dc.html` (M01–M32). A frame → lépés leképezés és a
kódolási sorrend: [59-cardio-implementation-plan.md](59-cardio-implementation-plan.md).

Érintett meglévő kód:
- `mobile/lib/features/workouts/` — `domain/workout_session.dart`, `data/workout_session_repository.dart`,
  `application/workout_session_controller.dart`, `application/workout_resume_prompt.dart`,
  `presentation/log_session_screen.dart`, `sessions_tab.dart`, `session_row_plan.dart`,
  `workouts_screen.dart`, `open_workout_screens.dart`
- `mobile/lib/core/local_db/tables/workout_session_tables.dart` — drift táblák
- `mobile/lib/core/workout_session_notifier/workout_session_notifier_service.dart` — Live Activity /
  ongoing notification híd (`WorkoutSessionState`)
- `mobile/lib/core/sync/` — `OutboxWriter`, `SyncEngine`, `client_id.dart`
- `mobile/lib/core/theme/app_tokens.dart` — `AppSpacing`, `AppRadius`, `AppDuration`, `AppMetricColors`

---

## 0. C0 — az audit, ami minden mást megelőz

A [51 R1](51-cardio-overview-plan.md) kockázat: a kódban szétszórva **szett-jelenlétet feltételező**
helyek vannak, amiket egy üres `sets`/`exercises` listájú session eltör vagy értelmetlen kimenetre
vezet. A C0 ezeket járja végig, **még mielőtt** bármilyen cardio adat létezne — így a javítás
önmagában regressziómentes, és nem keveredik az új funkcióval.

Kötelezően átnézendő helyek (a keresés kiindulópontja, nem a teljes lista):

| Fájl | Mit feltételez | Cardióra helyes viselkedés |
|---|---|---|
| `presentation/session_row_plan.dart` | a session sorai gyakorlatokból állnak | cardio: egy „metrika-sor” terv (fő metrika + két másodlagos) |
| `presentation/sessions_tab.dart` | kártya-alcím = gyakorlatnevek | cardio: ikon + típusnév + fő metrika |
| `domain/personal_record.dart` + `docs/38-personal-records-plan.md` | PR = szett súlyából | cardio session **kihagyandó** az erősítő PR-motorból (C3-ban kap sajátot) |
| `application/recommended_template_provider.dart` | `templateClientId` ciklus | cardio session-öket **ignorálja** (nincs template-je) |
| `application/watch_session_merge.dart`, `standalone_session_processor.dart` | óráról jött szettek | `kind`-tudatos ág, lásd [55-ös doc](55-cardio-watch-plan.md) |
| `application/workout_resume_prompt.dart` | „folyamatban lévő edzés” → `LogSessionScreen` | cardio: `CardioSessionScreen`-re irányít |
| `presentation/open_workout_screens.dart` | egyetlen megnyitási út | `kind` szerinti elágazás — **ez legyen az egyetlen hely**, ahol az elágazás megtörténik |
| dashboard „legutóbbi edzések” | gyakorlatszám-felirat | ikon + fő metrika |

**Elfogadás:** egy kézzel beszúrt, üres `sets`/`exercises` listájú (még `STRENGTH` fajtájú)
session minden képernyőn megnyitható, nem dob, és nem mutat „NaN”/„0 gyakorlat” helyett üres
foltot. Ez a teszt a C0 után is a suite-ban marad.

### 0.1 Audit-eredmény (C0.3, 2026-08-10)

Végigmenve a fenti listán, kódolvasással + egy új regressziós teszttel
(`test/features/workouts/presentation/sessions_tab_empty_session_test.dart`):

| Fájl | Eredmény |
|---|---|
| `session_row_plan.dart` | **Nem hiba.** Tiszta függvény, gyakorlatonként hívva — üres `exercises` listánál egyszerűen nulla hívás történik. A „nincs terv, nincs szett” eset már ma is tesztelve (`session_row_plan_test.dart`, „an exercise with no sets and no plan shows a single empty row”). |
| `sessions_tab.dart` | **Nem hiba, ellenőrizve widget-teszttel.** Az `exerciseNames` üres string esetén a „Exercise names” sor `if (exerciseNames.isNotEmpty)`-tel ki van hagyva; a szettszám mindig `l10n.setsCountLabel(session.sets.length)` (helyesen „0 szett”, nem crash). |
| `personal_record.dart` | **Nem hiba, szerkezetileg kizárva.** A `getPrBaseline` az `exercise_sets` drift-táblát joinolja `exerciseClientId`-re — egy cardio session (aminek soha nem lesz `exercise_sets` sora, a metrikái a leendő `cardio_details`-be írnak) automatikusan nem termel PR-t, védőháló nélkül is. A C3.5-ös explicit `kind`-szűrő ennek ellenére bekerül védekező rétegként, de a mai kód nem hibás. |
| `recommended_template_provider.dart` | **Nem hiba ma, de a zaj valós volt — javítva C0.5-ben.** A `.whereType<String>()` már a C0.3 idején is kiszűrte a template nélküli session-öket a mintafelismerésből (nem crashelt, nem adott hibás választ), de a `.take(10)` a szűrés *előtt* futott, tehát sok egymást követő template nélküli (jövőben: cardio) session felhígította a mintaablakot. A C0.5 megcserélte a sorrendet — lásd [59 C0.5](59-cardio-implementation-plan.md). |
| `watch_session_merge.dart`, `standalone_session_processor.dart` | **Ma nincs `kind` mező, nincs mit auditálni még.** A `kind`-tudatos ág a C5-ös (óra) munka része, a `sessionKind` mező C1.5-ben kerül a domain-modellbe. |
| `workout_resume_prompt.dart` | **Nem hiba** — `.watchAll().first` egy Drift-stream első eleme, nem egy lehetségesen üres lista `.first`-je. A cardio-irányítás (`CardioSessionScreen`-re) a C0.4 feladata, a képernyő létezése után. |
| `open_workout_screens.dart` | Az egyetlen `kind`-elágazási pont kialakítása **C0.4**, nem C0.3 — ma nincs mit elágaztatni, mert nincs `kind` mező. |
| dashboard „legutóbbi edzések” (`dashboard_screen.dart` `_WorkoutTile`) | **Nem hiba, ellenőrizve kódolvasással.** `workout.exerciseNames.isEmpty ? '—' : ...` — mindig renderel valamit, sosem üres foltot; `exCount > 0` őrzi a „N gyakorlat” statisztika-sort. Widget-tesztet **nem** kapott (a teljes `DashboardScreen` felhúzása táplálkozás/víz/súly/lépés providerekkel aránytalan lenne egy megerősítő teszthez) — a kódolvasásos ellenőrzés elég, mert a logika azonos mintát követ, mint a már widget-teszttel lefedett `sessions_tab.dart`. |

**Következtetés:** a mai kód — a fenti audit szerint — **nem tartalmaz olyan hibát**, amit az
üres `sets`/`exercises` lista kiváltana; a meglévő `isEmpty`/`whereType` őrök már véd(t)ék ezt
az esetet. A regressziós teszt négy forgatókönyvet zár le tartósan a suite-ban: template nélküli
üres session, template-es üres session, futó üres session, és üres + normál session vegyesen egy
listában. A C0-ban valódi kódmódosítást igénylő tételek (`open_workout_screens.dart` elágazása,
`recommended_template_provider.dart` zaj-szűrése) a C0.4/C0.5 lépésekre halasztva, mert azok nem
*javítanak* egy mai hibát, hanem a C1+ számára készítik elő a terepet.

---

## 1. Adatréteg (C1)

### 1.1 Drift-táblák

A `workout_session_tables.dart` bővül, a meglévő minta szerint (`clientId` PK, nullable
`serverId`, nullable oszlopok):

```dart
// WorkoutSessions bővítés
TextColumn get sessionKind => text().withDefault(const Constant('STRENGTH'))();
TextColumn get activityType => text().nullable()();
IntColumn  get movingSeconds => integer().nullable()();

// Új tábla: CardioDetails (1:1)
class CardioDetails extends Table {
  TextColumn get sessionClientId => text().references(WorkoutSessions, #clientId)();
  RealColumn get distanceMeters => real().nullable()();
  // ... a 52-es doc §2.2 oszlopainak Dart-párja ...
  TextColumn get routePolyline => text().nullable()();
  @override Set<Column> get primaryKey => {sessionClientId};
}

// Új tábla: CardioSplits
class CardioSplits extends Table { /* sessionClientId + splitIndex összetett kulcs */ }
```

A GPS nyers pontjai (`CardioTrackPoints`) **nem itt**, hanem a [54-es docban](54-cardio-gps-route-plan.md)
kerülnek be, a C4a-ban — a C1-nek nincs rájuk szüksége.

Drift-séma-verzió emelés + migrációs lépés a `AppDatabase.migration`-ben. A `withDefault`
gondoskodik róla, hogy a meglévő lokális sorok `STRENGTH`-ek legyenek.

### 1.2 Domain

`WorkoutSession` (a `domain/workout_session.dart`-ban) kap `sessionKind`, `activityType`,
`movingSeconds`, `cardio` (nullable `CardioDetails` value object) és `splits` mezőt, valamint:

```dart
bool get isCardio => sessionKind == 'CARDIO';
ActivityFamily? get family => activityType == null ? null : activityFamilyOf(activityType!);
/// Effective training time: moving time when tracked, else the wall-clock span.
Duration? get effectiveDuration => ...;
```

### D-C2.1 — A `sessionKind` `String`, nem Dart-enum a domain-modellben

A repo meglévő mintája (`kMuscleGroups`, `kEquipments` kódlisták + `switch`-elő label-függvények)
ugyanezt teszi, és **ismeretlen szerver-kód esetén nem robban** — egy jövőbeli
`ActivityType` érték a régi kliensen „Egyéb”-ként jelenik meg ahelyett, hogy parse-hibát dobna.
A típusbiztonságot a `activity_type.dart` konstans-listája és a lint adja.

### 1.3 Repository és outbox

A `WorkoutSessionRepository` **nem duplázódik**: ugyanaz a repo kezeli mindkét fajtát.

- `create` / `update` a cardio-blokkot is beírja (tranzakcióban a session sorral együtt).
- **Az `_payload` builderben** a cardio blokk csak `isCardio` esetén kerül be — a szerver
  keresztmezős validációja különben 400-at ad ([52 §3.2](52-cardio-domain-backend-plan.md)).
- **A [52 §4](52-cardio-domain-backend-plan.md) bump-szabály kliensoldali párja:** minden
  cardio-mező-írás egy **session-szintű** outbox-elemet enqueue-l (`updateSession`), nem külön
  „cardio-update” típust. Új outbox-művelettípus nem kell, ami egyben azt is jelenti, hogy a
  `SyncEngine` drain-hurokja változatlan.
- Új watch-stream: `watchByKind(String? kind)` a lista-szűrőhöz.

### 1.4 Delta-pull

A pull-ág mapper-e kitölti az új mezőket. **Kritikus:** ha a szerver `sessionKind` nélküli
(régi) választ ad, `STRENGTH`-nek vesszük — soha nem null-nak.

---

## 2. Kézi rögzítés (C1)

A C1 látható terméke: egy `LogCardioSheet` modal bottom sheet (`showDragHandle: true`, a repo
meglévő mintája), amivel **utólag** rögzíthető egy edzés.

Mezők (családfüggő, [51 §3](51-cardio-overview-plan.md)):

1. Típus-választó — hat ikonos csempe, a leggyakoribbak elöl (§3.4 rangsor).
2. Dátum + kezdés időpontja (alap: most; múltbeli nap választható — [51 Q3](51-cardio-overview-plan.md)).
3. Időtartam (perc) → `movingSeconds`.
4. `DISTANCE`: táv (km, 0,01 pontossággal), opcionális szintemelkedés.
   `MACHINE`: táv, átlag-W, átlag-rpm, ellenállás, gép-kalória.
   `GAME`: intenzitás (1–5 chip-sor), helyszín (terem/szabadtér), opcionális box score.
5. Kalória (opcionális), pulzus-átlag (opcionális).
6. RPE + jegyzet — a meglévő post-workout feedback komponens újrahasznosítva.

Minden numerikus mező `source = MANUAL` jelzést kap.

---

## 3. Az indítás (C2) — „praktikus dolog a telefonon”

A követelmény: **minimális súrlódás**. Négy belépési pont, prioritási sorrendben.

### 3.1 FAB hosszú nyomás → gyorsindító lap *(elsődleges)*

A Workouts tab FAB-ja ma a tab kontextusa szerint cselekszik (session/terv/gyakorlat). Bővítés:

- **Koppintás**: a mai viselkedés, változatlanul.
- **Hosszú nyomás** (`onLongPress`) → alulról egy **kompakt gyorsindító lap**: a **négy
  legmagasabb rangú** indítás (erősítő tervek és cardio típusok vegyesen, §3.4), nagy ikonos
  csempékként, alattuk egy „Összes…” sor. Egy koppintás = az edzés **azonnal elindul** (nincs
  köztes beállító képernyő; minden beállítás menet közben módosítható).
- Haptikus visszajelzés a hosszú nyomásra és az indításra.

Ez összesen **egy hosszú nyomás + egy koppintás**, két gesztus a mai négy-öt helyett.

### 3.2 Dinamikus app-shortcutok (app-ikon hosszú nyomás) *(másodlagos, a legkevesebb koppintás)*

Android `ShortcutManager` dinamikus shortcutjai és iOS `UIApplicationShortcutItem` — a
**három legmagasabb rangú** edzés, a rangsor változásakor frissítve (app háttérbe kerülésekor,
nem minden képernyőnyitáskor). A shortcut deep-linket nyit
(`lifey://workout/start?activity=RUNNING`), a `go_router` új route-ja pedig **azonnal indítja**
az edzést, még a Workouts tab megnyitása nélkül.

Ez az **egy gesztus** út: az app-ikonra nyomva, elengedve már fut a stopper.

### D-C2.2 — Külön plugin nélkül

A dinamikus shortcutokhoz nem hozunk be új Flutter-plugint: mindkét platformon néhány sor
natív kód egy meglévő `MethodChannel`-mintában (`lifey/shortcuts`), a
`workout_session_notifier` hídjának mintájára. Indok: a CLAUDE.md függőség-szabálya, és hogy a
rangsor-frissítés amúgy is natív oldali listát ír.

### 3.3 Kezdőképernyő-widget és óra *(harmadlagos)*

- A már meglévő `home_widget` híd ([24-es doc](../24-ios-widget-live-activity-plan.md)) kap egy
  „gyorsindítás” gombsort a top-2 edzéssel, ugyanarra a deep-linkre.
- Az óráról indítás a [55-ös doc](55-cardio-watch-plan.md) tárgya.

### 3.4 A rangsor: `activity_ranking.dart` *(közös, D-C.8)*

Egyetlen tiszta függvény, a `recommended_template_provider.dart` szomszédjaként, **mindhárom**
fogyasztóval közösen (gyorsindító lap, shortcut-frissítő, watch-payload):

```dart
/// Recency-weighted usage ranking over the user's sessions, newest first.
/// Half-life: 21 days — a workout done 3 weeks ago counts half as much as
/// today's, so the list follows the user's *current* routine instead of
/// freezing on whatever they did most a year ago.
List<QuickStartEntry> rankQuickStartEntries(
  List<WorkoutSession> sessionsDesc, {
  required DateTime now,
  int max = 8,
});
```

- **Kulcs**: cardio session-nél az `activityType`, erősítőnél a `templateClientId`
  (template nélküli erősítő session → egyetlen „Üres edzés” bejegyzés).
- **Pontszám**: `Σ 0.5^(napok / 21)` az adott kulcs befejezett session-jein.
- **Döntetlen**: a frissebb utolsó használat nyer; ha az is egyezik, a
  `kActivityTypes` megjelenítési sorrend.
- **Hidegindítás** (nincs elég előzmény): a lista feltöltve az alapértelmezett sorrendből
  (erősítő → futás → séta → szobabicikli → …), hogy sose legyen üres.
- **Stabilitás**: a rangsor csak session-befejezéskor (és pull-szinkron után) számolódik újra,
  nem minden build-ben — különben a csempék a szemünk előtt ugrálnának.

Ez a függvény **tisztán tesztelhető** (bemenet: session-lista + `now`), és a
[55-ös doc §3](55-cardio-watch-plan.md) ugyanezt használja az órai picker sorrendjéhez.

---

## 4. Az élő cardio képernyő (C2)

`CardioSessionScreen` — új képernyő, **nem** a `LogSessionScreen` elágazása (D-C.4).

### 4.1 Állapotgép

```
IDLE → RUNNING ⇄ PAUSED → ENDING → SUMMARY
```

- `RUNNING`: ticker fut, `movingSeconds` nő.
- `PAUSED`: kézi szünet **vagy** auto-pause (§4.3). A bruttó idő nő, a `movingSeconds` nem.
- `ENDING`: megerősítő (véletlen befejezés ellen — a képernyő edzés közben, izzadt kézzel
  használatos), a záró gomb **húzásra** (slide-to-finish) vagy hosszú nyomásra reagál, nem sima
  koppintásra.
- `SUMMARY`: összegzés + RPE + szerkesztés + mentés.

Az állapot **minden változásnál** a driftbe íródik (nem csak memóriában), így a
`workout_resume_prompt` egy kilőtt app után is pontosan folytatja.

### 4.2 Elrendezések családonként

| Család | Fő metrika (nagy) | Másodlagos sor | Extra vezérlő |
|---|---|---|---|
| `DISTANCE` | eltelt mozgásidő | táv · aktuális tempó/sebesség · pulzus | km-visszajelzés kapcsoló, útvonal-minitérkép (C4a) |
| `MACHINE` | eltelt mozgásidő | táv · kadencia · teljesítmény | ellenállás-léptető, intervallum-sáv (C7) |
| `GAME` | eltelt **játékidő** | bruttó idő · pulzus · intenzitás | **„Pályán / Padon” nagy kapcsoló**, gyors pont/gól léptető (C9) |

Közös elemek mindhárom családban: nagy, tabuláris számjegyek; szünet/folytatás; befejezés;
zenevezérlő sor (a meglévő [46-os](../music/46-workout-music-controls-plan.md) sticky zóna);
képernyő-ébrentartás (`WakelockPlus` helyett a meglévő megoldás, ha van — különben natív hívás).

### 4.3 Auto-pause (`DISTANCE` család)

Ha 15 másodpercig a sebesség < 0,5 m/s (és van GPS-jel), automatikus szünet; mozgásra
automatikus folytatás. Kikapcsolható. GPS nélkül nincs auto-pause (nem találgatunk).

### 4.4 `GAME`: a „pályán/padon” kapcsoló

Ez a `GAME` család egyetlen igazán fontos interakciója: egy meccs alatt a felhasználó valójában
az idő felét sem tölti pályán, és egy 90 perces „edzés” hamis adat. A kapcsoló nagy, hüvelykkel
elérhető, és haptikusan visszajelez. A `movingSeconds` csak „pályán” állapotban nő.

---

## 5. Live Activity / ongoing notification (C2)

A `WorkoutSessionState` ma szett-központú (`exerciseName`, `setsDone`, `setsTotal`,
`totalSetsDone`, `restEndsAtEpochMs`…). Ez a cardióra értelmetlen — „0 szett” látszana a
zárolási képernyőn.

### D-C2.3 — Egy payload, `kind` mezővel; a natív layout ágazik el

Nem építünk második csatornát. A `WorkoutSessionState` kap:

```dart
final String kind;              // 'STRENGTH' | 'CARDIO'
final String? activityType;     // ikon- és címválasztáshoz
final CardioLiveMetrics? cardio; // primary/secondary/tertiary metrika, előre formázva
```

- A `cardio` blokk **előre formázott stringeket** visz (`"7,32 km"`, `"5:12 /km"`), nem nyers
  számokat: a formázás lokalizált és mértékegység-függő (a Settings metric/imperial kapcsolója),
  és ezt a natív oldalon nem akarjuk újraimplementálni sem Swiftben, sem Kotlinban.
- Egyetlen kivétel: az **idő** továbbra is epoch-alapú (`startedAtEpochMs` + `pausedAtEpochMs`),
  hogy a natív felület magától ketyegjen, frissítés-kvóta nélkül. Ez a meglévő
  `restEndsAtEpochMs`-minta.
- A Swift `WorkoutActivityAttributes.ContentState` és az Android ongoing notification
  layoutja `kind` szerint választ elrendezést. Egy régi natív build (ami nem ismeri a `kind`-ot)
  a `STRENGTH` ágra esik vissza — csúnya, de nem törik.

Frissítési ütem: cardio alatt legfeljebb **5 másodpercenként** (iOS Live Activity kvóta), és
csak ha a megjelenített string ténylegesen változott.

---

## 6. Lista, kártya, szűrő, ikonok (C1)

- **Session-kártya**: bal oldalt kerek ikon-chip az aktivitás színével és ikonjával
  ([51 §1](51-cardio-overview-plan.md) térkép), cím = típusnév (vagy erősítőnél a
  `templateName`), alatta a családfüggő fő metrika (**DISTANCE = táv, MACHINE = mozgásidő,
  GAME = játékidő** — [57 §2](57-cardio-design-prompt.md), eldöntve). Az erősítő kártya vizuálisan **változatlan**,
  csak megkapja a `fitness_center` chipet — így a lista egységes lesz, nem kétféle.
- **Fajta-szűrő**: a `workouts_screen.dart` már visz egy `_sessionFilter`-t; ez bővül
  `mind / erősítő / cardio` chip-sorral, és cardio esetén másodlagos, típus-szintű szűrővel.
- **Ikon és szín**: az `activity_type.dart`-ban, az `exercise_enums.dart`
  `muscleGroupColor` mintájára — a meglévő `AppMetricColors` palettából választva, hogy ne
  kerüljön be új, a rendszerbe nem illő szín. Javasolt kiindulás (a design felülírhatja):
  futás → `calories`, séta → `steps`, szobabicikli → `carbs`, túra → `protein`,
  kosár → `fat`, foci → `water`, erősítő → `weight`.

---

## 7. Lokalizáció

Minden új szöveg ARB-kulcsként (`mobile/lib/l10n/`), EN + HU, soha nem literál. Új kulcs-családok:
`activityType*` (6+1 név), `cardioMetric*` (táv, tempó, kadencia, teljesítmény, szintemelkedés,
mozgásidő, játékidő, intenzitás, zónák), `cardioAction*` (indítás, szünet, folytatás, befejezés,
pályán/padon), `cardioEmpty*` / `cardioPermission*` (üres és engedély-állapotok).

**Mértékegység**: a Settings metric/imperial kapcsolóját a cardio is tiszteli
(km↔mérföld, m↔láb, perc/km↔perc/mérföld). Egy közös `CardioFormatter` a
`lib/core/format/`-ban, a Live Activity string-előformázásával megosztva (§5).

---

## 8. Feladatlista

### C0
| # | Lépés |
|---|---|
| M0.1 | `activity_type.dart` (kódlista, label, ikon, szín, család) + ARB-kulcsok |
| M0.2 | A §0 audit végigvitele + regressziós teszt az üres session-re |
| M0.3 | `open_workout_screens.dart` egyetlen `kind`-elágazási pontja (cardio ág egyelőre `TODO`) |

### C1
| # | Lépés |
|---|---|
| M1.1 | Drift-táblák + séma-migráció |
| M1.2 | Domain-bővítés (`sessionKind`, `activityType`, `movingSeconds`, `cardio`, `splits`) |
| M1.3 | Repository create/update/pull + payload-builder + outbox-bump (§1.3) |
| M1.4 | `LogCardioSheet` kézi rögzítés |
| M1.5 | Session-kártya ikon-chip + fajta-szűrő |
| M1.6 | `CardioFormatter` + mértékegység-kezelés |

### C2
| # | Lépés |
|---|---|
| M2.1 | `CardioSessionScreen` váz + állapotgép + drift-perzisztencia |
| M2.2 | Három családi elrendezés |
| M2.3 | `activity_ranking.dart` + tesztek |
| M2.4 | FAB hosszú nyomás → gyorsindító lap |
| M2.5 | Deep-link route (`lifey://workout/start?activity=`) + dinamikus app-shortcutok (natív híd) |
| M2.6 | `WorkoutSessionState` `kind`-bővítés + natív Live Activity / ongoing notification cardio-layout |
| M2.7 | Resume-prompt cardio-ág |
| M2.8 | Kezdőképernyő-widget gyorsindító gombok |

---

## 9. Tesztek

- `activity_ranking_test.dart`: felezési idő, döntetlen-feloldás, hidegindítás, vegyes lista.
- `CardioSessionScreen` állapotgép-teszt: szünet/folytatás alatt a `movingSeconds` és a bruttó
  idő külön viselkedik; app-kilövés után helyreállás.
- Repository-teszt: cardio create → outbox-elem → payload alakja; a `STRENGTH` payload
  **bájtra azonos** a maival (regresszió).
- Widget-teszt: a session-lista mindkét fajtát rendereli, a szűrő helyesen szűr.
- Formázás-teszt: metric/imperial mindkét irányban, HU és EN lokálon.
