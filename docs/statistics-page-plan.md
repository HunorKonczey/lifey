# Statisztika oldal – terv és promptok

> Cél: egy önálló **Statisztika** fül, ami a Weight tab grafikon-mintáját általánosítja
> több napi metrikára (fehérje, kalória, edzés-időtartam, víz, súly, stb.).
> A meglévő `TimeSeriesChart` + range-selector (`WeightRange`) mintát követjük,
> és a már migrált feature-repository-kból (meals, sessions, weight, water) számolunk
> lokálisan – ahogy a `DailyStats` / `dashboardControllerProvider` is teszi.

---

## 1. Ötletelés – milyen statisztikák legyenek?

A `DailyStats` (`features/dashboard/domain/daily_stats.dart`) már ma kiszámolja egy napra:
`calories, protein, carbs, fat, workoutCount, water, latestWeight`. Ebből látszik, hogy
az adatforrások adottak – csak idősorrá kell aggregálni őket nap szerint.

### Metrikák (minden napi bontásban, választható időtartománnyal)

| Metrika | Forrás | Aggregáció / nap | Mértékegység |
|---|---|---|---|
| **Kalória bevitel** | `Meal.totalCalories` (meals repo) | napi összeg | kcal |
| **Fehérje** | `Meal.totalProtein` | napi összeg | g |
| **Szénhidrát** | `Meal.totalCarbs` | napi összeg | g |
| **Zsír** | `Meal.totalFat` | napi összeg | g |
| **Edzés időtartam** | `WorkoutSession.finishedAt - startedAt` | napi összeg (perc) | min |
| **Edzések száma** | `WorkoutSession` count | napi darabszám | db |
| **Elégetett kalória** | `WorkoutSession.activeCalories` (Apple Health) | napi összeg | kcal |
| **Átlag pulzus edzésen** | `WorkoutSession.averageHeartRate` | napi átlag | bpm |
| **Vízbevitel** | water entries | napi összeg | ml / l |
| **Testsúly** | `WeightEntry.weight` | napi utolsó mérés | kg |
| **Megemelt össz-súly (volume)** | `ExerciseSet.reps * weight` | napi összeg | kg |

### Származtatott / haladó mutatók (későbbi fázis)

- **Kalória-egyenleg**: bevitt kcal − elégetett kcal (energy balance vonal a 0 körül).
- **Makró-megoszlás**: fehérje/szénhidrát/zsír % stacked bar vagy donut adott napra/időszakra.
- **Fehérje testsúly-kilóra vetítve**: `protein / latestWeight` (g/kg) – edzőknek hasznos.
- **Streak / konzisztencia**: hány nap volt edzés / a kalóriacél tartva.
- **Időszaki összegzők (KPI kártyák)**: átlag, min, max, trend (↑/↓ az előző azonos
  hosszú időszakhoz képest) a kiválasztott range-re.

### UX-koncepció

- Felül **metrika-választó** (chip/dropdown): melyik idősort nézzük.
- Alatta a Weight tab-ról ismerős **range SegmentedButton** (hét / hónap / negyedév / összes).
- Egy **összegző sáv** (KPI kártyák): átlag / összeg / trend a választott időszakra.
- A `TimeSeriesChart` rajzolja a kiválasztott metrika idősorát.
- **Kattintható pontok**: a grafikon pontjaira (különösen a csúcsértékekre) koppintva
  megjelenik a pontos szám az adott naphoz (érték + dátum) – tooltip/címke formában.
  Ez a megosztott `TimeSeriesChart`-ot bővíti, így a Weight tab is profitál belőle.
- Üres állapot és hiba a Weight tab `EmptyView` / `ErrorView` mintájával.

---

## 2. Architektúra-illeszkedés (fontos megkötések)

A `mobile/CLAUDE.md` szerint:

- **Négyrétegű feature**: `domain/ · data/ · application/ · presentation/` – akkor is, ha vékony.
- **Riverpod** kontroller-providerek; `@riverpod` annotáció után `dart run build_runner build`.
- A statisztika **nem ír** semmit, csak olvas → új repository nem kell, a meglévő
  feature-kontrollerek watch-streamjeit kombináljuk (mint a `dashboardControllerProvider`).
- A `TimeSeriesChart` (`shared/widgets/charts/`) **újrahasználandó** – ez már feature-agnosztikus.
- A `WeightRange` enumot **általánosítsuk** közös `StatsRange`-re, ne másoljuk.
- Új l10n kulcsok az `app_en.arb`-be (+ a többi nyelvi fájlba).

---

## 3. Inkrementális promptok (bemásolható)

A fázisok egymásra épülnek; mindegyik külön, kis, reviewelhető diff.

### Prompt 0 – Közös range kiemelése

```
A features/weight/application/weight_range.dart-ban lévő WeightRange + cutoff() logikát
emeld ki egy újrahasználható, feature-független StatsRange-be a shared/ alá
(pl. lib/shared/widgets/charts/ vagy lib/shared/stats/). A WeightRangeController
maradhat weight-specifikus, de a cutoff()/napszám logika a közös enumra hivatkozzon,
hogy a statisztika fül ne másolja. Ne törj meg meglévő importokat; futtasd a meglévő
weight teszteket. Csak a range-logikát mozgasd, viselkedés ne változzon.
```

### Prompt 1 – Stats domain + metrika-definíció

```
Hozz létre egy új feature-t: lib/features/statistics/.
A domain/ rétegbe tegyél egy StatMetric enumot (calories, protein, carbs, fat,
workoutMinutes, workoutCount, activeCalories, water, weight) a következő mezőkkel:
- l10n-alapú címke,
- mértékegység szöveg,
- aggregáció típusa (sum / average / lastOfDay).
Tegyél mellé egy DailyStatPoint értékobjektumot (date, value), ami a TimeSeriesPoint-ra
képezhető. Üzleti logikát itt még ne számolj – csak a típusokat és a metrika-metaadatot.
Tartsd magad a négyrétegű feature-felosztáshoz (mobile/CLAUDE.md).
```

### Prompt 2 – Aggregáló application réteg

```
A lib/features/statistics/application/ alá írj egy provider-t, ami a meglévő
feature-kontrollerek watch-streamjeiből (mealControllerProvider, workoutSession
controller, waterEntry repo, weightControllerProvider) – a dashboardControllerProvider
mintájára – egy kiválasztott StatMetric + StatsRange alapján legyárt egy
List<TimeSeriesPoint> idősort, napi bontásban:
- calories/protein/carbs/fat: Meal napi totalX összege,
- workoutMinutes: WorkoutSession (finishedAt-startedAt) napi összeg percben (befejezetlent hagyd ki),
- workoutCount: napi session darabszám,
- activeCalories: WorkoutSession.activeCalories napi összeg,
- water: napi vízbevitel,
- weight: napi utolsó WeightEntry (a weight_chart_data.dart latestPerDay logikája szerint).
A kiválasztott metrikát és range-et külön kis Notifier-providerek tartsák (mint a
weightRangeControllerProvider, csak StatMetric-re is). Új repository NE legyen – csak olvasunk.
@riverpod használata esetén futtasd a build_runner-t.
```

### Prompt 3 – Időszaki összegzők (KPI)

```
Egészítsd ki az application réteget egy provider-rel, ami a kiválasztott metrika
aktuális idősorából kiszámolja a range-re vonatkozó összegzőket: összeg, átlag, min,
max, és a trendet az előző azonos hosszúságú időszakhoz képest (előjeles % vagy abszolút
delta). Ez tisztán a már legyártott pontokból számoljon, ne kérdezze le újra a repókat.
```

### Prompt 4 – Presentation: Statisztika képernyő

```
Készítsd el a lib/features/statistics/presentation/statistics_screen.dart-ot a
weight_screen.dart felépítését követve:
- AppBar címmel,
- felül metrika-választó (SegmentedButton vagy DropdownMenu a StatMetric-ekre),
- alatta a StatsRange SegmentedButton (week/month/quarter/all) a weight tab mintájára,
- KPI összegző kártyák sora (a dashboard stat_card.dart widgetet használd újra, ha illik),
- a TimeSeriesChart a kiválasztott metrika pontjaival, a metrika mértékegységét használó
  label-builderrel,
- EmptyView üres adatra, ErrorView hibára, CircularProgressIndicator töltésre,
  pontosan ahogy a weight_screen csinálja.
Minden user-facing szöveg l10n kulcsból jöjjön.
```

### Prompt 5 – Navigáció / fül beillesztése

```
Illeszd be a Statisztika képernyőt az app shell navigációjába (go_router + az alsó
navigáció, ahol a Weight/Nutrition/Workouts fülek vannak). A FAB-os heroTag buktatóra
figyelj (lásd weight_screen kommentje: az IndexedStack miatt minden FAB-nak egyedi
heroTag kell) – a statisztika oldalon valószínűleg nincs is FAB. Adj hozzá ikont és
l10n-alapú fül-címkét.
```

### Prompt 6 – Lokalizáció

```
Add hozzá az összes új szöveget (oldal cím, metrika-nevek, mértékegységek, KPI címkék,
üres/hiba állapotok) az app_en.arb-hez, és szinkronizáld a többi nyelvi arb fájlt.
Generáld újra a lokalizációt.
```

### Prompt 7 – Kattintható pontok a grafikonon

```
Bővítsd a megosztott TimeSeriesChart-ot (shared/widgets/charts/time_series_chart.dart)
úgy, hogy a pontokra koppintva megjelenjen az adott pont pontos értéke + dátuma.
A widget jelenleg interakció nélküli CustomPaint – tedd kattinthatóvá:
- GestureDetector/onTapDown a CustomPaint köré, a koppintás pozícióját a legközelebbi
  ponttal párosítsd (a painter xFor/yFor logikájával konzisztens találati teszt),
- a kiválasztott pont fölött rajzolj egy kis tooltip-buborékot a formázott értékkel
  (a hívó adjon egy valueLabelBuilder-t, hasonlóan a meglévő dateLabelBuilder/
  deltaLabelBuilder-hez), benne a dátum is,
- újabb koppintás máshová / ugyanarra zárja vagy átviszi a tooltipet,
- a kijelölt pontot emeld ki (nagyobb/másik színű kör).
Maradjon feature-agnosztikus: csak a TimeSeriesPoint-ból és a builder-ekből dolgozzon.
A Weight tab és a Statisztika fül is automatikusan örökölje ezt – ne duplikálj logikát.
Figyelj a shouldRepaint-re, hogy a kijelölés-váltás újrarajzoljon.
```

### Prompt 8 – Tesztek

```
Írj unit teszteket az aggregáló providerre: napi összegzés metrikánként, üres adat,
range-szűrés határai (cutoff), és a "napi utolsó súly" kiválasztás. A KPI/trend
számításra is legyen teszt (üres és egy-pontos idősor szélső esetek). Widget-szinten
elég egy smoke teszt, hogy a képernyő üres/adat/hiba állapota a helyes nézetet rendereli.
A TimeSeriesChart kattintható pontjaira írj widget tesztet: egy pontra koppintás után
megjelenik a tooltip a várt értékkel (és nem jelenik meg koppintás előtt).
```

---

## 4. Bővítési lehetőségek (későbbre)

- **Bar chart variáns** a `TimeSeriesChart` mellé (napi diszkrét értékekhez, pl. edzésszám
  jobban néz ki oszlopként, mint vonalként).
- **Több metrika egy grafikonon** (pl. bevitt vs. elégetett kcal overlay).
- **Cél-vonalak**: napi fehérje/kalória cél behúzása vízszintes referenciaként
  (`UserSettings`-ből, ha van).
- **Makró donut** a kiválasztott időszak átlagos makró-megoszlásával.
- **Export / megosztás** (PNG vagy CSV) a kiválasztott időszakról.

---

## 5. Érintett / referencia fájlok

- Minta: `mobile/lib/features/weight/presentation/weight_screen.dart`
- Range minta: `mobile/lib/features/weight/application/weight_range.dart`
- Napi-utolsó aggregáció minta: `mobile/lib/features/weight/application/weight_chart_data.dart`
- Újrahasznált grafikon: `mobile/lib/shared/widgets/charts/time_series_chart.dart`
- Adat-kombinálás minta: `mobile/lib/features/dashboard/application/dashboard_controller.dart`
- Napi aggregátum modell: `mobile/lib/features/dashboard/domain/daily_stats.dart`
- KPI kártya: `mobile/lib/features/dashboard/presentation/widgets/stat_card.dart`
- Adatforrás modellek: `meal.dart`, `workout_session.dart`, `weight_entry.dart`, water entries
```
