# Redesign – Workout Tab

> Terv (nem implementáció). A `Lifey Workout Tabs.dc.html` design-handoff alapján, a jelenlegi
> Flutter + Spring Boot kód állapotához hasonlítva. Cél: a meglévő dark workout rendszer
> ráigazítása a designra, két új **opcionális, BE-n tárolt** mezővel (kategória + eszköz) és egy
> **új Exercise detail oldallal**.

---

## 1. Scope

### Benne van (most fejlesztjük)
1. **Exercise kategória** (izomcsoport) – kötött enum, **opcionális**, BE + lokális DB + megjelenítés, szerkeszthető.
2. **Exercise eszköz** (equipment, "mivel végeztük") – kötött enum, **opcionális**, BE + lokális DB + megjelenítés, szerkeszthető.
3. **Template-exercise set szám** (cél set count / exercise) – **opcionális** mező a template összeállított gyakorlatain; BE + lokális DB + megjelenítés.
4. **Új Exercise detail oldal** (design 04. képernyő) – pushed route: kategória/eszköz chipek, PR, becsült 1RM, trend chart, utolsó set-ek, edit gomb.
5. **Add/Edit exercise** form bővítése a két új mezővel (a szerkeszthetőség miatt kell).
6. **Exercises tab** vizuális ráigazítás: kategória szerinti csoportosítás + szűrő chipek (a kategória mező közvetlen következménye).

### Nincs benne (külön designon, később)
- **Edit / Create template oldal** (design 02. képernyő) – másik designon megy, oda visszatérünk.
  - Fontos: a `targetSets` **adat-réteget** (BE entity, DTO, lokális tábla, sync) most kiépítjük, hogy kész legyen, de a **set szám beviteli UI** az edit-template redesignnal érkezik. Addig a template megjelenítésben **read-only** ("3 sets") jelenik meg, ha ki van töltve.
- Új kategória/eszköz **felvétele futásidőben** – szándékosan nem lehet. A két lista **fix enum**, mert minden értékhez l10n (fordítás) kulcs tartozik. Bővítés = kód + ARB módosítás + migráció.
- Search mező és History ikon tényleges funkciója (a designon látszik, de nem ennek a körnek a része).

---

## 2. Jelenlegi állapot vs. redesign

| Terület | Most | Redesign | Teendő |
|---|---|---|---|
| Sub-tabok | `Sessions · Templates · Exercises` (`workouts_screen.dart`) | `History · Templates · Exercises` | A "Sessions" felirat → "History" (opcionális, csak címke). Sorrend azonos. |
| Template kártya | ikon + név + exercise-nevek listája (`templates_tab.dart` `_TemplateCard`) | ikon + név + "6 exercises · ~52 min" + **kategória chipek** | Subtitle formátum + kategória chipek a template gyakorlataiból aggregálva. |
| Template exercise sor (edit) | csak checkbox + név (`create_template_screen.dart`) | "3 sets · Barbell" alcím, drag handle | `targetSets` + equipment kijelzés (UI az edit-redesignban). |
| Exercises tab | lapos lista, swipe-to-delete (`exercises_tab.dart`) | search + **kategória szűrő chipek** + **kategória szerinti szekciók** + sorban "Barbell · Chest" alcím + chevron → detail | Csoportosítás, chipek, alcím, navigáció a detail oldalra. |
| Exercise detail | **nincs** | Új pushed route: chipek, PR, 1RM, 8 hetes trend, recent sets, edit | Teljesen új oldal. |
| Add exercise | csak név (`add_exercise_sheet.dart`) | – | Bővítés: opcionális kategória + equipment választó. |
| Exercise modell | csak `name` (BE `Exercise`, mobil `exercise.dart`) | kategória + equipment | Két új nullable mező végig a stacken. |

A jelenlegi top bar (lebegő, blur), nav pill és a zöld kijelölésű sub-tab sor a designnal megegyezik – ezeken nem kell változtatni.

---

## 3. Adatmodell – a két új enum

Mindkettő **kötött, fordítható enum**. A backend a **stabil kódot** tárolja (enum `name()`), a kliens
l10n-nel fordítja megjelenítéskor. Mindkét mező **nullable** → a jelenlegi (seed) gyakorlatoknál üres marad.

### 3.1 MuscleGroup (kategória)
A user által említettek (Chest, Shoulders, Glutes, Abs) + a designon szereplők (Back, Triceps, Biceps, Quads, Hamstrings) + `Other`. Javasolt **flat, granuláris** lista:

```
CHEST, BACK, SHOULDERS, BICEPS, TRICEPS, FOREARMS,
QUADS, HAMSTRINGS, GLUTES, CALVES, ABS, CARDIO, FULL_BODY, OTHER
```

- A designon a szűrő chipek tágabbak (All · Chest · Back · Legs · Arms), a template tag-ek granulárisak (Chest, Shoulders, Triceps, Quads…). **Javaslat:** granulárisat tárolunk; az Exercises tab szűrő-chipsora az adathalmazban **ténylegesen előforduló** kategóriákat mutatja (vízszintesen görgethető), így nem kell külön "broad group" leképezés. (Alternatíva: broad csoportok – `Arms = Biceps+Triceps+Forearms`, `Legs = Quads+Hamstrings+Glutes+Calves` – ha tágabb szűrőt akarunk; ez +1 leképező réteg.)

### 3.2 Equipment (eszköz, "mivel végeztük")
Designon: Barbell, Dumbbell, Cable, Bodyweight. Javasolt bővebb lista:

```
BARBELL, DUMBBELL, MACHINE, CABLE, BODYWEIGHT,
KETTLEBELL, RESISTANCE_BAND, SMITH_MACHINE, MEDICINE_BALL, OTHER
```

### 3.3 Fontos architekturális döntés – megosztott katalógus
Az `exercises` tábla **nem user-höz kötött** (`V6__ownership.sql`: szándékosan közös referencia-katalógus,
mint egy publikus gyakorlat-adatbázis). A jelenlegi kód ezt **globálisan szerkeszthetőként** kezeli
(van POST/PUT/DELETE `ExerciseController`, és `AddExerciseSheet`). A két új mező szerkesztése ezzel
**konzisztens: globális** – egy user módosítása mindenkinél látszik.

- **Javaslat:** maradjon globális (a meglévő precedens miatt a legkevesebb új komplexitás).
- **Nyitott kérdés (lásd 8. szakasz):** ha ez nem kívánatos, kell egy user-szintű override tábla
  (`user_exercise_meta(user_id, exercise_id, category, equipment)`) – jelentősen nagyobb meló, ezt
  most **nem** javaslom.

---

## 4. Backend változások (Spring Boot, Flyway)

### 4.1 Új Flyway migráció – `V18__exercise_category_equipment.sql`
```sql
alter table exercises add column category  varchar(32);
alter table exercises add column equipment varchar(32);
```
Nullable → seed gyakorlatok üresek maradnak. (Opcionális: a 8 seed gyakorlatnak adhatunk értelmes
default kategória/equipmentet külön update-ben, de a user kérése szerint **maradjon üres**.)

### 4.2 Új Flyway migráció – `V19__template_exercise_target_sets.sql`
```sql
alter table workout_template_exercises add column target_sets integer;
```

### 4.3 Enumok
- `com.lifey.workout.exercise.MuscleGroup` (3.1 értékek)
- `com.lifey.workout.exercise.Equipment` (3.2 értékek)

### 4.4 Érintett osztályok
- `Exercise.java` – `@Enumerated(EnumType.STRING) @Column(length=32) MuscleGroup category;` + `Equipment equipment;` (mindkettő nullable).
- `dto/ExerciseRequest.java` – `String category`, `String equipment` (nem `@NotBlank`; validáció: enum-ba parse-olható vagy null – pl. `@ValueOfEnum` jellegű ellenőrzés a service-ben vagy custom validátor).
- `dto/ExerciseResponse.java` – `String category`, `String equipment` (enum `name()` vagy null).
- `ExerciseMapper.java` – `apply`/`toResponse` a két mezőre; string→enum biztonságos parse (ismeretlen kód → null vagy 400).
- `WorkoutTemplateExercise.java` – `@Column Integer targetSets;` (nullable).
- `dto/WorkoutTemplateRequest.java` – **breaking change**: `List<Long> exerciseIds` helyett strukturált lista:
  ```java
  record TemplateExerciseEntry(@NotNull Long exerciseId, @Positive Integer targetSets) {}
  // request: List<TemplateExerciseEntry> exercises
  ```
  (`targetSets` nullable). 
- `dto/WorkoutTemplateResponse.java` – ugyanígy `List<{exerciseId, targetSets}>`.
- `WorkoutTemplateMapper.java` + `WorkoutTemplateServiceImpl` – a structured lista kezelése (eddig csak `exerciseId`-kat resolvolt).
- Tesztek: `ExerciseControllerTest`, `ExerciseServiceImplTest`, `WorkoutTemplate*Test` frissítése az új mezőkre.

> ⚠️ A `WorkoutTemplateRequest`/`Response` séma váltása töri a mobil push/pull payloadot – a 5. szakasz ezt párban kezeli. Mivel az edit-template UI külön körben jön, érdemes a structured listát **most** bevezetni, hogy ne kelljen kétszer migrálni a payloadot.

---

## 5. Mobil változások (Flutter, offline-first)

### 5.1 Lokális DB (drift) + migráció
- `tables/exercise_table.dart` – `TextColumn get category => text().nullable()();` + `equipment` ugyanígy (enum kódot stringként tároljuk).
- `tables/workout_template_tables.dart` – `WorkoutTemplateExercises`: `IntColumn get targetSets => integer().nullable()();`
- `app_database.dart` – `schemaVersion` bump + migrációs lépés (addColumn ×3). `dart run build_runner build` a `.g.dart`-hoz (generált fájlt nem szerkesztünk kézzel).

### 5.2 Domain
- `domain/exercise.dart` – `final String? category; final String? equipment;` (stabil enum kód). Az `==`/`hashCode` marad `clientId` alapú (a meglévő dropdown-megfontolás miatt – ne bántsuk).
- `domain/workout_template.dart` – `exerciseClientIds: List<String>` helyett `exercises: List<TemplateExercise>` ahol `TemplateExercise { String exerciseClientId; int? targetSets; }`. (Vagy: tartsd meg az id-listát és egy párhuzamos `Map<String,int?> targetSets` – de a structured lista tisztább és illeszkedik a BE-hez.)

### 5.3 Repository + sync
- `data/exercise_repository.dart`
  - `create` / új `update` – `category`, `equipment` paraméter; payload: `{'name':…, 'category':…, 'equipment':…}` (null is mehet).
  - `_toDomain` – olvassa a két új oszlopot.
- `data/workout_template_repository.dart`
  - `_payload` – `'exerciseIds': [...]` helyett `'exercises': [{'exerciseId': clientRef(id), 'targetSets': n}]`.
  - `watchAll` / `_toDomain` – `targetSets` beolvasása a join-ból.
  - `_insertLinks` – `targetSets` írása.
- `core/sync/pull_engine.dart`
  - `_pullExercises` – `category`, `equipment` mezők átvétele a response-ból.
  - `_pullWorkoutTemplates` – a structured `exercises` lista (id + targetSets) parse-olása a mostani `exerciseIds` helyett.
- `core/sync/entity_sync_config.dart` – nincs új entitás; a meglévő `exercise` és `workout_template` config marad.

### 5.4 UI
- **`add_exercise_sheet.dart`** – a név alá két opcionális választó (DropdownButtonFormField / chip-választó): kategória és equipment. "Nincs megadva" alapérték.
- **Edit exercise** – a detail oldal edit (ceruza) gombja → ugyanaz a form, előtöltve. Külön sheet vagy az `AddExerciseSheet` `initial`-os újrahasznosítása.
- **`exercises_tab.dart`**
  - Kártya alcím: `equipment · category` (l10n-fordítva), ha ki van töltve; chevron → detail.
  - Kategória szerinti szekció-fejlécek + felül a szűrő chipsor (a jelenlévő kategóriákból). Üres-kategóriás gyakorlatok pl. "Other"/"Uncategorized" szekcióba.
  - Tap a kártyán → `ExerciseDetailScreen` push (rootNavigator, mint a többi push route).
- **`exercise_detail_screen.dart`** (ÚJ, design 04)
  - AppBar: vissza + név + edit gomb.
  - Chipek: kategória (kitöltve), equipment (kitöltve) – csak ha van érték.
  - PR + becsült 1RM kártyák, 8 hetes trend chart, "Recent sets" lista – a gyakorlathoz tartozó `exercise_sets`-ekből számolva (a session adatok már lokálisan vannak). 1RM pl. Epley-formulával; ha nincs set-adat, üres állapot.
- **`templates_tab.dart` `_TemplateCard`** – kategória chipek a template gyakorlatainak kategóriáiból (uniq, max N), és a subtitle "N exercises". A "~X min" becslés opcionális (target_sets alapján), egyelőre kihagyható.
- **`create_template_screen.dart`** – **most nem nyúlunk hozzá funkcionálisan** (külön redesign), de a refaktor miatt a `WorkoutTemplate.exercises` típusváltását át kell vezetni rajta, hogy forduljon (a `targetSets`-et `null`-lal továbbítja, amíg nincs beviteli UI).

### 5.5 i18n
Minden enum-értékhez l10n kulcs az ARB-ekben (ez a "fordítás miatt fix" indok lényege), pl.:
`muscleChest`, `muscleBack`, …, `muscleOther`; `equipmentBarbell`, …, `equipmentOther`.
Megjelenítéskor enum kód → l10n kulcs leképezés (kliens oldali helper). Új cím-kulcsok: exercise detail
szekciók (Personal record, Estimated 1RM, Recent sets), category/equipment mező label-ek.

---

## 6. Megjelenítési szabály (a user kérése szerint)
- A két exercise mező és a template set szám **opcionális** → ha üres, **nem** jelenik meg chip/alcím (a jelenlegi seed gyakorlatoknál tehát semmi extra).
- Ha ki van töltve: **template** kártyán a kategória chipek és (edit-redesign után) az exercise sorban "3 sets · Barbell"; **exercise** kártyán/detailen az "Equipment · Category" és a chipek.

---

## 7. Javasolt sorrend (fázisok)
1. **BE adat-réteg**: enumok + V18/V19 migrációk + entity/DTO/mapper/service + tesztek.
2. **Mobil adat-réteg**: drift oszlopok + schema bump + domain + repository + pull_engine + payloadok (build_runner).
3. **Exercise UI**: add/edit form a két mezővel; exercises_tab alcím + navigáció.
4. **Exercise detail oldal** (új route).
5. **Exercises tab** csoportosítás + szűrő chipek.
6. **Template megjelenítés** (kategória chipek; targetSets read-only kijelzés).
7. **i18n** kulcsok mindenhol.
8. *(Külön kör)* Edit/Create template redesign – ekkor jön a `targetSets` beviteli UI.

---

## 8. Nyitott döntések
1. **Globális vs. per-user szerkeszthetőség** a kategória/equipment mezőkre (3.3). *Javaslat: globális (meglévő precedens).*
2. **Granuláris vs. broad kategóriák** a szűrőben (3.1). *Javaslat: granuláris tárolás, jelenlévő-kategóriás chipsor.*
3. **Pontos enum-listák** véglegesítése (3.1 / 3.2) – a fentiek javaslatok, a fordítás miatt utólag bővíteni drágább.
4. **Sessions → History** átnevezés a sub-tabon megtörténjen-e (csak címke, design így mutatja).

> **Eldöntött:** a `WorkoutTemplate` API sémája **most** vált strukturált listára
> (`exerciseIds: [Long]` → `exercises: [{exerciseId, targetSets}]`), hogy ne kelljen kétszer
> migrálni a payloadot. Lásd 4.4 és 5.3.

---

## 9. Design token → theme leképezés (NE hardcode-olj hex-et)

A `Lifey Workout Tabs.dc.html` hex-értékei **egy az egyben** a meglévő `app_theme.dart` /
`app_tokens.dart` tokenek. Mindenhol a `Theme.of(context).colorScheme` / `context.metricColors` /
`AppRadius` / `textTheme` tokeneket használd – így a light téma és a jövőbeli tweak-ek ingyen jönnek.

| Design hex | Mire | Flutter token |
|---|---|---|
| `#161611` | scaffold / legmélyebb háttér | `scheme.surface` (≙ `scaffoldBackgroundColor`), `scheme.surfaceContainerLowest` |
| `#1C1E16` | **kártya háttér** (template/exercise lista, search, recent-set sor) | `scheme.surfaceContainerLow` |
| `#22241B` | **stat/elevated kártya** (PR, 1RM, trend chart, edit-template exercise sor) | `scheme.surfaceContainer` (= `primaryContainer`) |
| `#2A2C20` | ikon-badge, lebegő top bar, nav pill háttér | `scheme.surfaceContainerHigh` |
| `#32342A` | chip / kijelölt szegmens háttér | `scheme.surfaceContainerHighest` |
| `#9DAE6B` | primary zöld (FAB, aktív tab, accent szöveg, "Save", chart vonal) | `scheme.primary` |
| `#161611` (zöldön) | szöveg/ikon primary felületen | `scheme.onPrimary` |
| `#F1F0E4` | elsődleges szöveg | `scheme.onSurface` |
| `#A8A899` | másodlagos / muted szöveg | `scheme.onSurfaceVariant` |
| `#777264` / `#76766c` | dimmed (uppercase szekció-label, timestamp, chevron) | `scheme.onSurfaceVariant` ~60% opacity |
| `#3C3E32` | szaggatott border ("Add exercise") | `scheme.outline` |

**Kategória-chip színek = az `AppMetricColors` paletta** (a design ezt a meglévő macro-paletta-színeket
újrahasználja): Chest `#E0915A` = `calories`, Shoulders `#D8B35A` = `carbs`, Triceps `#8E8EC4` = `fat`,
Back `#6FA8C4` = `water`, Biceps `#9DAE6B` = `protein`, Quads `#E0915A` = `calories`,
Hamstrings `#B08AC8` = `steps`, Glutes `#D8B35A` = `carbs`. → Kell egy
`Color muscleColor(MuscleGroup, BuildContext)` helper, ami minden izomcsoportot egy `context.metricColors`
accentre képez le (a fenti hozzárendelés szerint, a maradékot körbeosztva). **Chip stílus:** háttér =
`color.withValues(alpha: 0.15)`, szöveg/ikon = `color`, `fontSize 11 / w700`, padding `5×11`,
`AppRadius.pill`.

**Material Symbols → Flutter `Icons` leképezés:**
`fitness_center`→`Icons.fitness_center`, `directions_run`→`Icons.directions_run`,
`sports_gymnastics`→`Icons.sports_gymnastics`, `search`→`Icons.search`, `history`→`Icons.history`,
`chevron_right`→`Icons.chevron_right`, `drag_indicator`→`Icons.drag_indicator`, `close`→`Icons.close`,
`add`→`Icons.add`, `arrow_back`→`Icons.arrow_back`, `edit`→`Icons.edit`,
`accessibility_new`→`Icons.accessibility_new`, **`trophy`→`Icons.emoji_events`** (nincs "trophy" a
Material Iconsban). A status bar (network_cell/wifi/battery) és a nav ikonok (dashboard/restaurant/
monitor_weight/bar_chart) rendszer- ill. meglévő elemek – ne építsd újra.

---

## 10. Részletes implementációs promptok (képernyőnként)

> Minden prompt önállóan végrehajtható. A színek/ikonok/radiusok a 9. szakasz tokenjeit használják.
> Ahol a design eltér a mostani kódtól, **„Mobil eltérés”** blokk jelzi a tényleges fejlesztést.

### 10.1 — Exercises tab (design 03 · library)
**Fájl:** `mobile/lib/features/workouts/presentation/exercises_tab.dart`

> Alakítsd át az Exercises tabot a design 03 képernyőre. Felül **search mező**: `surfaceContainerLow`
> háttér, `AppRadius.md`, magasság 46, bal oldalt `Icons.search` (`onSurfaceVariant`), placeholder
> „Search exercises…” (l10n). Alatta **vízszintesen görgethető kategória-chipsor**: „All” + az
> adathalmazban ténylegesen előforduló kategóriák (üres-kategóriás gyakorlatoknál „Other”). Aktív chip:
> `scheme.primary` háttér + `onPrimary` szöveg; inaktív: `surfaceContainerLow` háttér +
> `onSurfaceVariant`; mind `AppRadius.pill`, `fontSize 12`, padding `7×14`. A lista **kategória szerinti
> szekciókra** bomlik: uppercase szekció-fejléc (`textTheme.labelSmall`, `onSurfaceVariant`, betűköz
> +1px). Minden sor: bal oldalt 42×42 ikon-badge (`surfaceContainerHigh` háttér, `Icons.fitness_center`
> a `muscleColor` accentjével – bodyweight gyakorlatnál `Icons.sports_gymnastics`), cím
> (`textTheme.bodyLarge`), alcím = `equipment · category` l10n-fordítva (`onSurfaceVariant`, csak ha van
> érték), jobbra `Icons.chevron_right` (`onSurfaceVariant`). A teljes sor `InkWell` → push
> `ExerciseDetailScreen` (rootNavigator).
>
> **Mobil eltérés a mostanihoz:** jelenleg lapos `ListView` + `Dismissible` swipe-to-delete, és a kártya
> `surfaceContainerHigh`-on ül. Át kell térni szekciózott listára, megtartva a swipe-to-delete-et (vagy a
> törlést átvinni a detail oldalra). A FAB („Exercise”, `add` ikon) marad a `shell_fab` mechanizmuson.
> Üres állapot: maradhat a meglévő `EmptyView`.

### 10.2 — Exercise detail (design 04 · ÚJ pushed route)
**Új fájl:** `mobile/lib/features/workouts/presentation/exercise_detail_screen.dart`

> Teljesen új pushed route (`MaterialPageRoute`, rootNavigator), a meglévő push-route mintát követve
> (`AppBar`, `scrolledUnderElevation: 0`). AppBar: bal `Icons.arrow_back`, cím = gyakorlat neve
> (`textTheme.titleLarge`), jobbra `Icons.edit` gomb → megnyitja az edit exercise sheetet (10.4).
> **Törzs (felülről):**
> 1. **Chip-sor:** kategória chip (`Icons.accessibility_new` + l10n név, `muscleColor` accent, 15% háttér)
>    és equipment chip (`Icons.fitness_center` + l10n név, `surfaceContainerLow` háttér,
>    `onSurfaceVariant`). **Csak a kitöltött mező jelenik meg** – ha mindkettő üres, a sor elmarad.
> 2. **Két stat-kártya egymás mellett** (`surfaceContainer`, `AppRadius.input`): bal = „Personal record”
>    (`Icons.emoji_events`, `carbs` accent) nagy érték „85 kg × 5” (`textTheme.displayLarge`-szerű,
>    tabular) + dátum; jobb = „Estimated 1RM” (`Icons.history`, `primary`) érték zölden + havi delta.
> 3. **1RM trend kártya** (`surfaceContainer`, `AppRadius.lg`): fejléc „Estimated 1RM · 8 weeks” +
>    százalék-pill (`primary` háttér, `onPrimary`). Vonaldiagram `CustomPaint`-tel: `primary` vonal
>    (3px, lekerekített), alatta 12% opacity area-fill, utolsó ponton 5px kör. (Ha kevés az adat,
>    egyszerű placeholder/üres állapot.)
> 4. **„Recent sets”** szekció (uppercase label) + sorok (`surfaceContainerLow`, `AppRadius.md`): bal a
>    nap („Today”/„Mon”), jobbra a set-ek „60×10 · 62.5×8 · 62.5×7” (tabular, `onSurfaceVariant`).
>
> **Adatforrás:** minden szám a lokális `exercise_sets`-ből számolva ehhez a `exerciseClientId`-hoz
> (PR = max becsült terhelés, 1RM = pl. Epley `w*(1+reps/30)`, trend = heti max 1RM 8 hétre). Nincs új
> BE hívás. **Mobil eltérés:** ilyen oldal **ma nincs**, ez tisztán új. Készíts hozzá egy
> `exerciseStatsProvider(exerciseClientId)`-t (application réteg), ami a session/set streamből aggregál.

### 10.3 — Templates tab (design 01 · list)
**Fájl:** `mobile/lib/features/workouts/presentation/templates_tab.dart` (`_TemplateCard`)

> Igazítsd a template kártyát a design 01-re. Kártya `surfaceContainerLow`, `AppRadius.card`. Felső sor:
> 46×46 ikon-badge (`surfaceContainerHigh`, `Icons.fitness_center` zölden – cardio jellegnél
> `Icons.directions_run`), cím (`textTheme.bodyLarge`/16 w800), alcím „N exercises” (l10n,
> `onSurfaceVariant`), jobbra `Icons.chevron_right`. Alatta **kategória-chip sor**: a template
> gyakorlatainak **uniq kategóriái** (kitöltöttek), `muscleColor` accentekkel, `flex-wrap`. A „~X min”
> becslés egyelőre **elhagyható**.
>
> **Mobil eltérés:** jelenleg a subtitle a gyakorlatnevek vesszős listája, és van „Start” pill + overflow
> menü (edit/delete). A designon ezek nincsenek a kártyán (a tap a detail/edit-be visz). **Javaslat:**
> tartsd meg a Start/▶ funkciót (a kártya tap = Start marad, ahogy most), de a subtitle váltson
> „N exercises”-re és jöjjenek a kategória-chipek. A targetSets-et a kártya **nem** mutatja (az az
> exercise-soron belüli adat, az edit-template redesignban jelenik meg „3 sets · Barbell” formában).

### 10.4 — Add / Edit exercise (form bővítés)
**Fájl:** `mobile/lib/features/workouts/presentation/widgets/add_exercise_sheet.dart`

> Bővítsd a sheetet két **opcionális** választóval a név alatt: **Category** és **Equipment**. Mindkettő
> egy-egy chip-rács vagy `DropdownButtonFormField`, „—/None” alapértékkel (a kitöltetlen a default, hogy a
> seed gyakorlatok üresek maradjanak). Az értékek l10n-fordítva jelennek meg, de a tárolt érték a **stabil
> enum kód**. Tedd a sheetet újrahasználhatóvá szerkesztésre is (`initial` exercise param) – ezt hívja az
> Exercise detail edit gombja (10.2). Save-kor a két mező a payloadba kerül (lehet `null`).
>
> **Mobil eltérés:** ma csak `name` mező van; nincs edit-sheet (csak add). Kell: edit mód + a két mező +
> az `ExerciseRepository.update(...)` (most csak `create`/`delete` van).

### 10.5 — Sub-tab címke (opcionális, design 01/03)
> A designon a sub-tab sor „History · Templates · Exercises”. Ma „Sessions · Templates · Exercises”
> (`workouts_screen.dart`, `l10n.sessionsTabLabel`). Ha egységesítünk a designgal: csak a label-kulcs
> szövege vált „History”-ra (a `SessionsTab` és minden logika marad). **Vizuális/copy döntés, nem
> funkció** – lásd 8/4. nyitott pont.

---

## 11. Acceptance (a design „logikussága” miatt figyelni)
- Üres mezők **soha** nem rajzolnak chipet/alcímet (seed gyakorlatok ugyanúgy néznek ki, mint ma).
- Minden szín theme tokenből jön → light témában is helyes (ne legyen hardcode hex a workout kódban).
- A kategória-chip színe konzisztens végig (lista, template, detail) ugyanarra az izomcsoportra.
- Exercise detail számai a lokális set-adatból jönnek, BE hívás nélkül, és üres set-listánál nem dobnak.
