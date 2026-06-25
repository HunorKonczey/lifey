# Redesign – Workout Tab v2 (aktív edzés képernyő)

> **Terv, nem implementáció.** Ez a doksi a **futó / szerkesztett edzés-képernyőt**
> (`log_session_screen.dart`) tervezi át a `Lifey Redesign.dc.html` "Push day" workout
> képernyőjére (a feltöltött mockup). A v1 (`redesign-workout-tab.md`) a *Templates / Exercises /
> Exercise-detail* lapokról szólt — **ez a v2 kizárólag az edzés indítás / vezetés / lezárás
> folyamatát fedi**. A két doksi nem ütközik: a v1 az adat-réteget (kategória, equipment,
> `targetSets`) építi, ezt a v2 fel is használja (üres set-sorok száma).

---

## 1. Scope

### Benne van (most tervezzük)
1. **Az aktív edzés képernyő teljes vizuális átalakítása** a mockupra: lebegő top bar **pörgő eltelt
   idővel**, **rest banner élő idővel**, **gyakorlatonként egy kártya saját set-táblázattal**, alul
   sticky **"Finish workout"** gomb.
2. **Inline szerkeszthető set-sorok** a mostani bottom-sheet (`AddSetSheet`) helyett: 1 tap →
   szerkeszt, 2 tap → következő sor kitöltése ugyanazokkal az értékekkel, sor végén törlés, pipa →
   set kész.
3. **`targetSets` → előre legenerált üres set-sorok**: gyakorlat hozzáadásakor, ha a gyakorlatnak /
   template-bejegyzésnek van mentett set száma, annyi **üres** sor jön létre; ha nincs, **egy** sor.
4. **Health-enrichment (active kcal + avg bpm) csak lezárt, Apple-ből importált edzésnél** látszik —
   futó edzésen soha. **Nincs külön import gomb** — az enrichment a Finish-be van építve (lásd 6.).
5. **Dátum-pickerek megszüntetése**: a start az indításkori `now`, a finish az alsó gomb — nincs
   `showDatePicker` / `showTimePicker`.
6. **Az Apple-keresés a "Finish workout" gombba van építve**: lezáráskor a háttérben eldől, van-e
   lezárható Apple-edzés, és a találat / hiány / engedély szerint **dialogot** dob (lásd 5.6).
   Nincs külön "Import from Apple" gomb a felületen.

### Nincs benne (marad / külön kör)
- A **backend és a session adatmodell** lényegében marad: `WorkoutSession` + `ExerciseSet` +
  `SessionExercise.targetSets` már létezik. **Nincs új Flyway-migráció, nincs új DTO mező** (lásd 4.).
- Az `AddExerciseToSessionSheet` (gyakorlat-választó a katalógusból) **belső logikája marad** — csak a
  trigger lesz a designos "Add exercise" dashed gomb.
- A v1-es Exercises/Templates/Exercise-detail átalakítás (külön doksi).
- Heti / hangos rest-timer értesítés, beállítható rest hossz — most csak **megjelenítés** (eltelt idő
  az utolsó kész set óta), nem konfigurálható timer.

---

## 2. Jelenlegi állapot vs. redesign

| Terület | Most (`log_session_screen.dart`) | Redesign (mockup) | Teendő |
|---|---|---|---|
| Fejléc | sima `AppBar` cím + "Save" text gomb | lebegő pill: vissza-badge + edzésnév + **pörgő `28:14` timer** | Új lebegő top bar, élő eltelt idő. |
| Start mező | `OutlinedButton` + **date/time picker** | nincs külön mező; start = `now` indításkor | Picker törlése; start implicit. |
| Finish mező | `OutlinedButton` + **date/time picker** + clear | alul sticky **"Finish workout"** gomb | Picker törlése; finish = gombnyomás. |
| Health (kcal/bpm) | nincs külön kijelzés, csak import gomb | két stat-kártya **felül** | Csak **lezárt + Apple-import** session-nél jelenjen meg. |
| Rest | set alcímében statikus "rest 0:42" szöveg | önálló **rest banner élő** idővel | Élő count-up az utolsó kész set óta. |
| Tervezett gyakorlatok | quick-add **ActionChip sor** (`_planned`) | **gyakorlatonként kártya** set-táblázattal | Chip → kártya + set-tábla. |
| Set-ek | flat lista, `AddSetSheet` bottom-sheet, edit/dupla/törlés sheeten át | **inline sorok** a kártyában (Set/Kg/Reps/✓) | Sheet → inline szerkesztés + pipa. |
| "Add exercise" | text gomb a katalógus-sheethez | **dashed "Add exercise"** gomb a kártyák alatt | Csak vizuál + a sheet hívása. |
| Set hozzáadás | "Add set" globális gomb | kártyán belül **"Add set"** sor | Kártyánkénti add. |

A lebegő top bar / nav pill stílusa megegyezik a v1-gyel — a tokenek ugyanazok (9. szakasz a v1-ben).

---

## 3. Képernyő-felépítés (a mockup szerint, fentről le)

```
┌─ lebegő top bar (rgba(34,36,27,.92) blur, radius 24) ──────────┐
│ [←40×40 badge]  Push day                  [⏱ 28:14 pill]       │   ← top:62, h:58
└────────────────────────────────────────────────────────────────┘
   ── content (top:132, padding 6/16/102, gap 13) ──
   ┌ active kcal ─────┐ ┌ avg bpm ─────────┐   ← CSAK lezárt + Apple
   │ 🔥 214           │ │ ❤ 128            │      import session-nél
   └──────────────────┘ └──────────────────┘
   ┌ rest banner (zöld 14% bg, zöld border) ───────────────────┐
   │ ⏳ Rest                                            0:42     │   ← élő count-up
   └────────────────────────────────────────────────────────────┘
   ┌ exercise card (#22241B, radius 22) ───────────────────────┐
   │ 🏋 Bench press                                      ⋯       │
   │ SET   KG        REPS                                        │
   │  1    60        10                                    ✓     │   ← kész (zöld bg)
   │  2    62.5      8                                     ✓     │
   │  3    62.5      —                                     ○     │   ← üres/terv
   │ ＋ Add set                                                  │
   └────────────────────────────────────────────────────────────┘
   ┌─ ＋ Add exercise (1.5px dashed #3C3E32) ───────────────────┐  ← "add other"
   └────────────────────────────────────────────────────────────┘
   ── sticky alul (bottom:24) ──
   ┌──────────── ✓ Finish workout (zöld) ──────────────────────┐
   └────────────────────────────────────────────────────────────┘
```

**Token-leképezés (NE hardcode-olj hex-et, használd a témát — részletek a v1 9. szakaszában):**

| Design hex | Mire | Flutter token |
|---|---|---|
| `#161611` | scaffold, badge háttér, "Add set" sor háttere | `scheme.surface` / `surfaceContainerLowest` |
| `#1C1E16` | health stat-kártya háttér | `scheme.surfaceContainerLow` |
| `#22241B` | **exercise kártya** háttér | `scheme.surfaceContainer` |
| `rgba(34,36,27,.92)` | lebegő top bar | `surfaceContainer` + blur (meglévő top-bar minta) |
| `#9DAE6B` | primary zöld (timer ikon, rest idő, pipa, Finish gomb, "Add set") | `scheme.primary` |
| `rgba(157,174,107,.10)` | **kész set-sor** háttér | `scheme.primary.withValues(alpha: .10)` |
| `rgba(157,174,107,.14)` + `.4` border | **rest banner** | `scheme.primary` 14% bg + 40% border |
| `#F1F0E4` | elsődleges szöveg / set értékek | `scheme.onSurface` |
| `#A8A899` | másodlagos szöveg, dashed gomb felirat | `scheme.onSurfaceVariant` |
| `#777264` | dimmed (uppercase Set/Kg/Reps fejléc, üres "—", `more_horiz`) | `scheme.onSurfaceVariant` ~60% |
| `#E0915A` | kcal ikon | `context.metricColors.calories` |
| `#C46A6A` | bpm ikon | `context.metricColors` heart/kraf (`error`-szerű piros) |
| `#3C3E32` | dashed "Add exercise" border | `scheme.outline` |

**Ikon-leképezés:** `arrow_back`→`Icons.arrow_back`, `timer`→`Icons.timer` (filled),
`local_fire_department`→`Icons.local_fire_department`, `favorite`→`Icons.favorite`,
`hourglass_top`→`Icons.hourglass_top`, `fitness_center`→`Icons.fitness_center`,
`more_horiz`→`Icons.more_horiz`, `check_circle`→`Icons.check_circle`,
`radio_button_unchecked`→`Icons.radio_button_unchecked`, `add`→`Icons.add`, `check`→`Icons.check`.

---

## 4. Adatmodell – mi marad, mi az ÚJ koncepció

**Nincs új BE/DB séma.** Minden megvan:
- `WorkoutSession.startedAt / finishedAt / activeCalories / averageHeartRate / healthWorkoutId`
- `SessionExercise.targetSets` (a v1 hozta be), `ExerciseSet { exerciseClientId, reps, weight, performedAt }`.

**Egy ÚJ, tisztán kliensoldali koncepció: a "set-sor" vs. "kész set".**
A mockup mutat **terv-sorokat** is (`3 | 62.5 | — | ○`), amik még nincsenek teljesítve. A jelenlegi
modellben egy `ExerciseSet` mindig "kész" (van `performedAt`). Döntés:

> **Üres/terv-sorok = efemer UI-állapot, NEM perzisztálódnak `ExerciseSet`-ként.**
> Csak a **bepipált** (kész) sorok mennek `ExerciseSet`-be. A pipa: kitölti a `performedAt`-et
> (`now`) és perzisztál (`_autoSave`). Így a rest-idő matek (`performedAt` deltái) sértetlen marad, és
> nincs szükség "completed" flag-re a BE-n.

A képernyő belső állapota ezért **gyakorlatonként csoportosított sorok** listája:

```dart
// presentation-only modell (nem domain)
class _SetRow {
  double? weight;      // null = még nem töltötték
  int? reps;           // null = "—"
  DateTime? doneAt;    // != null → kész (zöld sor + pipa); ez lesz performedAt
}
class _ExerciseBlock {
  final String exerciseClientId;
  final int? targetSets;
  final List<_SetRow> rows;
}
```

A `_persist()` ebből számolja a `List<ExerciseSetInput>`-et: **csak a `doneAt != null` sorokból**,
`performedAt: doneAt` értékkel. A `_planned` (PlannedExerciseInput) lista a blokkokból generálódik
(minden blokk egy planned exercise, `targetSets`-szel).

> ⚠️ Ez a **legfontosabb refaktor**: a mostani flat `_sets` + `AddSetSheet` lecserélése
> gyakorlatonkénti blokkokra inline sorokkal. A perzisztencia API (`logSession`/`updateSession`,
> `PlannedExerciseInput`, `ExerciseSetInput`) **változatlan** — csak a UI-állapotból másképp képződik
> a payload.

---

## 5. Viselkedés-specifikáció

### 5.1 Pörgő eltelt idő (top bar timer)
- Futó edzésnél: `Timer.periodic(1s)` → `now - _startedAt`, formázva `mm:ss` (1 óra felett `h:mm:ss`),
  `tabular-nums`. `dispose`-ban `cancel`.
- Szerkesztett **lezárt** session-nél: statikus `finishedAt - startedAt` időtartam (nem pörög).
- `_startedAt` az edzés indításakor (`LogSessionScreen` push) `DateTime.now()` — nincs picker.

### 5.2 Rest banner (élő)
- Az **utolsó kész set** (`max(doneAt)`) óta eltelt idő, `Timer.periodic(1s)` count-up, `m:ss`.
- Ha még nincs kész set: a banner **elrejtve** (vagy `0:00` — döntés a 8. pontban). Javaslat: amíg
  nincs kész set, ne látszódjon.
- Lezárt session-nél nem látszik (nincs aktív rest).
- Megosztja az 5.1 ticker-ét (egy `Timer` is elég az egész képernyőnek).

### 5.3 Exercise kártya + inline set-sorok
- Minden tervezett gyakorlat = egy kártya (`surfaceContainer`, radius 22). Fejléc: `fitness_center`
  badge (zöld), név (`bodyLarge`/16 w800), jobbra `more_horiz` → menü: **Remove exercise**
  (a blokk + sorai törlése), opcionálisan "Replace exercise".
- Oszlopfejléc: `SET · KG · REPS · (✓)` uppercase, dimmed, `labelSmall`.
- Sorok:
  - **Kész sor** (`doneAt != null`): zöld 10% háttér, set-szám zölden, kg/reps `onSurface`, jobbra
    `check_circle` (zöld, filled). Pipára tap → **vissza nyit** (doneAt = null) szerkesztésre.
  - **Üres/terv sor** (`doneAt == null`): áttetsző háttér, set-szám/kg/reps dimmed; üres érték `—`;
    jobbra `radio_button_unchecked`. A karikára tap → **kész** (kitölti `doneAt = now`, perzisztál).
- **"Add set" sor** a kártya alján: új üres `_SetRow` a blokkhoz; kg-t a blokk utolsó sorának
  értékéből előtölti (gyors progresszió), reps üres.

### 5.4 Set-sor gesztusok (a user kérése szerint)
- **1 tap** a sor kg vagy reps cellájára → **inline szerkesztés** (a cella `TextField`-é válik, vagy
  egy kompakt szám-stepper/kis bottom-sheet — lásd 8.). A `performedAt`/`doneAt` változatlan.
- **2 tap (double-tap)** a soron → **a következő sor kitöltése ugyanazzal a kg/reps értékkel**; ha
  nincs következő sor, **új sort** hoz létre ezekkel az értékekkel ("duplikál"). (A mostani
  `_duplicateSet` szándékát viszi tovább, inline.)
- **Sor végén törlés**: a user szerint "rálépve … helyett törlés a végén" → szerkesztő módban a sor
  trailing ikonja `close`/`delete` lesz a pipa helyett, azzal törölhető a sor.
- Üres állapot: ha egy blokk minden sorát törlik, a blokk üresen is maradhat (csak "Add set" sorral),
  vagy a blokk eltűnik — javaslat: maradjon a kártya, hogy a gyakorlat tervezve marad.

### 5.5 `targetSets` → sor-generálás
- Gyakorlat hozzáadásakor (`AddExerciseToSessionSheet` visszaad `targetSets`-et is):
  - ha `targetSets != null && > 0`: annyi **üres** `_SetRow` (`doneAt == null`).
  - különben: **egy** üres `_SetRow`.
- Template-ből indított edzésnél a `widget.template.exercises[i].targetSets` adja a sorszámot
  (initState-ben legenerálva).
- Szerkesztett session-nél: a perzisztált `ExerciseSet`-ek → kész sorok (`doneAt = performedAt`), a
  `targetSets` és a kész darabszám **különbözete** → annyi üres sor a végére (hogy a terv látszódjon).

### 5.6 Lezárás: egyetlen "Finish workout" gomb (az Apple-keresés bele van építve)
**Egy akció, nincs date picker, nincs külön import gomb.** Az alsó zöld "Finish workout" gomb maga
dönti el a háttérben, hogy van-e lezárható Apple-edzés. A flow (a gomb `onPressed`-jében):

1. **Apple Health nincs engedélyezve** (`appleHealthControllerProvider.value != true`): **nincs
   keresés** → egyszerűen lezár: `_finishedAt = now`, `_persist()`, dashboardra navigálás (a mostani
   `_save` finishing-ága). Apple-adat nélkül zár.
2. **Apple Health engedélyezve** → `importService.findImportable()` fut a háttérben (közben a gomb
   spinner/disabled):
   - **van workout** → **pairing dialog** (a meglévő: dátum + kcal + bpm). Két gomb:
     - **"Pair & finish"** → `importInto(...)` (lezár + enrichel a kcal/bpm-mel) → dashboard.
     - **"Finish without"** → sima lezárás Apple-adat nélkül → dashboard.
   - **nincs workout** → **"No Apple workout" dialog** (NEM snackbar, ahogy kérted): cím + szöveg, két
     gomb:
     - **"Finish anyway"** → sima lezárás Apple-adat nélkül → dashboard.
     - **"Cancel"** → bezárja a dialogot, **visszatér az edzéshez** (nem zár).
- A mostani `_importFromAppleHealth()` logikája beolvad a `_save`/Finish gombba: a `findImportable()`
  hívás és a pairing dialog onnan jön, a **változások**: (a) nincs külön gomb/`canImportFromHealth`
  gate; (b) a "nincs workout" ág snackbar helyett dialog; (c) az engedély-hiány ág → azonnali sima
  lezárás; (d) a pairing dialognak van egy "finish without" ága is, hogy a Finish mindig zárjon.

### 5.7 Health stat-kártyák (kcal/bpm)
- **Csak** akkor renderelődik a két felső kártya, ha `session.finishedAt != null && session.fromAppleHealth`
  (azaz `activeCalories`/`averageHeartRate` megvan). Futó vagy kézzel zárt edzésnél elrejtve.
- Értékek: `activeCalories.round()` + "active kcal", `averageHeartRate.round()` + "avg bpm".

---

## 6. Érintett fájlok (mobil, BE érintetlen)
- **`presentation/log_session_screen.dart`** — a fő átalakítás: lebegő top bar + ticker, rest banner,
  `_ExerciseBlock`/`_SetRow` állapot, inline set-sorok, dashed "Add exercise", sticky Finish, import
  dialog. Date-pickerek (`_pickDateTime`) törlése.
- **`presentation/widgets/` – ÚJ** `exercise_session_card.dart` (a kártya + set-tábla + gesztusok),
  hogy a screen ne híznia el. Opcionális, de javasolt.
- **`add_set_sheet.dart`** — az inline modellnél a teljes set-felvételhez (exercise + reps + weight)
  már nem kell minden ághoz; a kg/reps inline szerkesztéshez **kompakt szám-popover** kell (8.1
  eldöntve). A katalógusból gyakorlatot az `AddExerciseToSessionSheet` ad, nem ez.
- **`application/workout_session_controller.dart`, `data/workout_session_repository.dart`** — **nem
  változik** (a payload ugyanaz).
- **`core/health/health_workout_import_service.dart`** — **nem változik**; csak a hívó UI változik:
  a `findImportable()` + pairing dialog beolvad a **Finish gombba**, a "nincs workout" ág snackbar
  helyett dialog, és nincs többé külön import gomb / `canImportFromHealth` gate.
- **i18n (ARB)** — új kulcsok: `restLabel`, `finishWorkoutButton`, `noAppleWorkoutTitle`,
  `noAppleWorkoutMessage`, `finishAnywayButton`, `finishWithoutPairingButton`, `pairAndFinishButton`,
  `removeExerciseLabel`, `addSetLabel`, `activeKcalLabel`, `avgBpmLabel`. A meglévők
  (`pairAppleWorkout*`, `addExerciseTitle`) újrahasználhatók; a régi `importFromAppleHealthButton`
  feleslegessé válik (nincs külön gomb).

---

## 7. Részletes implementációs promptok

> Minden prompt önállóan végrehajtható. Színek/ikonok a 3. szakasz tokenjeit használják, **hex tilos**.

### 7.1 — Lebegő top bar + pörgő eltelt idő
> A `log_session_screen.dart` `AppBar`-ját cseréld a mockup lebegő pill top bar-jára:
> `surfaceContainer` (`rgba(34,36,27,.92)` ekv.) háttér + blur, `AppRadius` 24, `top:62 left/right:12`,
> magasság 58. Bal: 40×40 `surface` badge `Icons.arrow_back` (`onSurfaceVariant`) → pop. Közép-bal:
> edzésnév (`title* / 17 w800`) — template név vagy "Workout"/"Edit workout". Jobb: pill (`surface`
> bg, radius 13) `Icons.timer` (filled, primary) + **élő `mm:ss`**. Implementáld a tickert egy
> `Timer.periodic(const Duration(seconds: 1))`-pel state-ben (`_now` frissítése), `dispose`-ban
> `cancel`. Futó edzés: `_now - _startedAt`. Lezárt session: statikus `finishedAt - startedAt`, nincs
> timer. A `_startedAt` indításkor `DateTime.now()`. **Mobil eltérés:** a mostani `AppBar` + "Save"
> text gomb eltűnik; mentés ezután a Finish gomb / autosave.

### 7.2 — Health stat-kártyák (feltételes)
> A content tetejére tedd a két stat-kártyát (`surfaceContainerLow`, radius 18, `13×15` padding):
> bal `Icons.local_fire_department` (`metricColors.calories`) + `activeCalories.round()` + "active
> kcal"; jobb `Icons.favorite` (piros metric szín) + `averageHeartRate.round()` + "avg bpm". **Csak
> akkor renderelődik**, ha `widget.session?.finishedAt != null && widget.session!.fromAppleHealth`.
> Minden más esetben (futó, kézzel zárt) a sor elmarad.

### 7.3 — Rest banner (élő)
> A stat-kártyák alá (futó edzésen) rest banner: `primary` 14% háttér + 40% border, radius 18,
> `13×16`. Bal: `Icons.hourglass_top` (primary) + "Rest" (`onSurface`, w700). Jobb: **élő count-up**
> `m:ss` (primary, w800, tabular) az utolsó **kész** set (`max doneAt`) óta. Ugyanazt a 7.1 tickert
> használja. Ha nincs még kész set, a banner **ne jelenjen meg**. Lezárt session-nél nincs banner.

### 7.4 — Exercise kártya + inline set-tábla (ÚJ widget)
> Hozz létre `widgets/exercise_session_card.dart`-ot. Props: gyakorlat neve, `_ExerciseBlock`
> (sorok + targetSets), és callbackek (sor kész/visszanyit, sor szerkeszt, sor töröl, sor duplikál,
> add set, remove exercise). Kártya `surfaceContainer`, radius 22, padding 16. Fejléc: 22px
> `Icons.fitness_center` (primary) + név (`16 w800`) + jobbra `Icons.more_horiz` (dimmed) → menü
> (Remove exercise). Oszlopfejléc `SET/KG/REPS` uppercase dimmed `labelSmall`, 34px set-oszlop, flex
> kg + reps, 34px trailing. **Sorok** a 3./5.3 szerint: kész = `primary` 10% háttér + zöld set-szám +
> `Icons.check_circle`; terv = áttetsző + dimmed + `—` + `Icons.radio_button_unchecked`. Alul "Add
> set" sor: `surface` háttér, radius 13, `Icons.add` + "Add set" primary színnel. **Mobil eltérés:** a
> mostani `ActionChip` quick-add sor és a flat `_sets` `Card`-lista helyett ez a kártya jön; egy kártya
> = egy tervezett gyakorlat.

### 7.5 — Set-sor gesztusok
> A set-sorra: **1 tap** → a kg ill. reps cella inline szerkeszthető (kompakt numerikus szerkesztő —
> lásd 8. döntés). **double-tap** → a következő sor kitöltése a sor kg/reps értékeivel; ha nincs
> következő, új sor ezekkel az értékekkel. **Szerkesztő módban a trailing pipa → `Icons.close`**,
> azzal a sor törölhető. A **karika (terv sor) tap → kész** (`doneAt = now`, `_autoSave`); a **pipa
> tap → visszanyit** szerkesztésre (`doneAt = null`). Minden mutáció után `_autoSave()` (a meglévő
> debounce/snackbar minta), és a kész sorok `performedAt`-ja `doneAt`.

### 7.6 — "Add exercise" (dashed) + sor-generálás
> A kártyák alá dashed gomb: `1.5px dashed outline`, radius 18, padding 14, `Icons.add` + "Add
> exercise" (`onSurfaceVariant`). Megnyitja a meglévő `AddExerciseToSessionSheet`-et
> (`excludeIds` a már tervezett gyakorlatok). A visszakapott `targetSets` szerint: `>0` → annyi üres
> `_SetRow`, különben 1 üres sor (5.5). Template-ből indításkor és session szerkesztésekor a sorok az
> 5.5 szerint generálódnak initState-ben.

### 7.7 — Sticky "Finish workout" gomb (Apple-keresés beépítve, NINCS külön import gomb)
> Alul sticky (`bottom:24 left/right:16`) zöld gomb: `primary` bg, `onPrimary` szöveg, magasság 54,
> radius 20, `Icons.check` + "Finish workout". A tap az 5.6 teljes flow-ját futtatja **egyetlen
> gombból**:
> 1. Ha az Apple Health nincs engedélyezve (`appleHealthControllerProvider.value != true`) → azonnal
>    sima lezárás: `_finishedAt = now`, `_persist`, dashboardra navigálás (a meglévő `_save`
>    finishing-ága).
> 2. Ha engedélyezve van → a gomb spinnerre vált, fut a `importService.findImportable()`:
>    - **van workout** → pairing dialog (meglévő, dátum + kcal + bpm): **"Pair & finish"** →
>      `importInto(...)` → dashboard; **"Finish without"** → sima lezárás → dashboard.
>    - **nincs workout** → **"No Apple workout" dialog** (snackbar helyett): **"Finish anyway"** →
>      sima lezárás → dashboard; **"Cancel"** → vissza az edzéshez (nem zár).
>
> **Töröld** a `_pickDateTime`-ot, a start/finish `OutlinedButton`-okat, a régi külön
> `_importFromAppleHealth` gombot és a `canImportFromHealth` gate-et — a logika a Finish gombba olvad.

### 7.8 — i18n
> Vedd fel az új ARB kulcsokat (6. szakasz: `restLabel`, `finishWorkoutButton`, `noAppleWorkoutTitle`,
> `noAppleWorkoutMessage`, `finishAnywayButton`, `finishWithoutPairingButton`, `pairAndFinishButton`,
> stb.), és a meglévő `pairAppleWorkout*`, `addExerciseTitle` újrahasználatát hagyd meg. Minden
> user-facing szöveg l10n-ből.

---

## 8. Eldöntött kérdések
1. **Inline cella-szerkesztés módja → kompakt szám-popover.** Tapra egy kis kg+reps popover/sheet,
   nem helybeli `TextField` a táblában (kevesebb fókusz/keyboard-bug, gyorsabb).
2. **Rest banner üres állapot → rejtve**, amíg nincs kész set (nincs `0:00` placeholder).
3. **Az Apple-import nem külön gomb** — a Finish gombba van építve (5.6 / 7.7). A felületen nincs
   "Import from Apple" gomb.
4. **Remove exercise → ha van kész (`doneAt != null`) set a blokkban, megerősítő dialog**; ha nincs,
   azonnal törölhető.
5. **Több gyakorlat:** a mockup egy kártyát mutat; több tervezett gyakorlatnál egymás alá kerülnek a
   kártyák (scroll). Nincs külön teendő, csak rögzítjük.

---

## 9. Acceptance
- Sehol nincs `showDatePicker` / `showTimePicker` az edzés-folyamatban; start = indításkori `now`,
  finish = "Finish workout" gomb.
- A top bar eltelt ideje **pörög** futó edzésnél (1 mp), lezártnál statikus időtartam.
- A rest banner **élő** count-up az utolsó kész set óta; nincs kész set → nincs banner.
- A health (kcal/bpm) kártyák **csak** lezárt + Apple-importált session-nél jelennek meg.
- Gyakorlat hozzáadásakor `targetSets` szerint generálódnak üres sorok (vagy 1, ha nincs).
- 1 tap szerkeszt, 2 tap a következő sort tölti / duplikál, sor végén törölhető, pipa → kész
  (`performedAt` stamp + autosave).
- Csak a kész (`doneAt != null`) sorok perzisztálódnak `ExerciseSet`-ként; a payload/repo/BE séma
  változatlan.
- **Nincs külön import gomb**; a Finish gomb dönt: engedély nincs → lezár; van workout → pairing
  dialog (Pair & finish / Finish without); nincs workout → **dialog** (Finish anyway / Cancel), nem
  snackbar.
- Minden szín téma-tokenből; hex nincs a workout kódban (light témában is helyes).
```