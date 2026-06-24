# 18 — Macros Tab (Nutrition)

Egy új **Macros** fül a Nutrition képernyőn (4. pill tab), amely napi bontásban mutatja a kalória- és makró-bevitelt — szűrhető Today / Week / All nézetben, a dashboard makró-kártyák stílusában.

## Döntések

| Kérdés | Döntés |
|---|---|
| Lista egysége | **Napi összesítő** (1 sor = 1 nap) |
| Elhelyezés | **4. pill tab** a Nutritionban (Foods / Meals / Recipes / **Macros**) |
| Progress bar | **Nincs** — csak ikon + érték |
| Szöveges makró-cím | **Nincs** — csak az ikon és a szín azonosítja |

---

## Prompt 1 — Adatréteg: napi makró-összesítés

```
A Lifey mobile (Flutter) nutrition feature-jébe kell egy napi makró-összesítő adatforrás.

Hozz létre egy domain modellt: mobile/lib/features/nutrition/domain/daily_macros.dart
  class DailyMacros { final DateTime day; (helyi éjfél) final double calories, protein, carbs, fat; }

Hozz létre egy Riverpod providert: mobile/lib/features/nutrition/application/daily_macros_controller.dart
  - Forrás: a meglévő mealControllerProvider (StreamNotifier<List<Meal>>, lásd meals_tab.dart).
  - A meal-eket csoportosítsd helyi naptári nap szerint (meal.dateTime.toLocal()), naponta
    összegezd a totalCalories/totalProtein/totalCarbs/totalFat mezőket.
  - Adj vissza List<DailyMacros>-t, nap szerint csökkenő sorrendben.
  - Kövesd a projekt konvencióit: feature-based mappák, StreamNotifier/derived provider,
    a @riverpod generált providereket build_runnerrel (ne kézzel a *.g.dart).

FONTOS: a mealController lapozott (pagináció), így az "All" szűrőnél a régebbi napok
hiányozhatnak. Egyelőre a betöltött meal-ekből aggregálj (Today/Week pontos);
a teljes "All" pontossághoz később egy drift-alapú napi aggregáló query kell a
MealRepository-ban — ezt jelöld TODO-val, de most ne implementáld.
```

---

## Prompt 2 — Lokalizáció

```
Adj új l10n stringeket a Lifey mobile-hoz (mobile/lib/l10n/app_en.arb és app_hu.arb),
majd futtasd a `flutter gen-l10n`-t (ne szerkeszd kézzel a generált *.dart fájlokat):

- macrosTabLabel:          "Macros"              / "Makrók"
- noMacroDataTitle:        "No macros logged yet" / "Még nincs makró rögzítve"
- noMacroDataInRangeTitle: "No macros in this range" / "Nincs makró ebben az időszakban"

Ha a tryWiderDateFilterMessage kulcs még nem létezik (ellenőrizd app_en.arb-ban),
add hozzá azt is: "Try a wider date filter" / "Próbálj tágabb időszakot".
Ha már létezik, ne duplikáld.

Makró egységek szöveges felirat nélkül jelennek meg (csak ikon + "g" suffix),
ezért új makró-cím stringek nem kellenek.

Kövesd a meglévő arb formátumot: minden kulcshoz @description blokk az en arb-ban.
```

---

## Prompt 3 — Macros tab UI

```
Hozz létre: mobile/lib/features/nutrition/presentation/macros_tab.dart

A meals_tab.dart szerkezetét kövesd (ConsumerStatefulWidget, DateRangeFilter állapot,
DateRangeFilterBar felül, alatta RefreshIndicator + ListView.builder), de a
dailyMacrosControllerProvider adatából dolgozz (List<DailyMacros>).

Szűrés: DateRangeFilter (Today/Week/All) a shared DateRangeFilterBar widgettel —
filter.matches(entry.day)-vel szűrd a napokat (ld. date_range_filter_bar.dart).

Üres állapotok:
  - Nincs egyetlen adat sem → EmptyView(icon: Icons.pie_chart_outline, title: noMacroDataTitle)
  - Van adat, de a szűrőn kívül esik → EmptyView(title: noMacroDataInRangeTitle,
                                                    subtitle: tryWiderDateFilterMessage)

Minden sor egy nap = _DailyMacroCard widget. Kinézet (FONTOS a részletekre):

  Kártya alap:
    Card(elevation: 0, color: surfaceContainerHigh,
         shape: RoundedRectangleBorder(radius: AppRadius.card),
         margin: bottom 10, clipBehavior: Clip.antiAlias)
    Belső padding: horizontal 12, vertical 12 — mint a _MealCard.

  Felső sor (nap + kalória):
    - Bal: a nap relatív neve (Ma / Tegnap / DateFormat('EEE, MMM d') — helyi időzóna)
      → theme.textTheme.bodyLarge
    - Jobb: Icons.local_fire_department (méret 18, szín mc.calories) + szóköz +
      calories.toStringAsFixed(0) (titleLarge, w800, tabular figures) + " kcal"
      (labelMedium, onSurfaceVariant)

  Alsó sor (makrók — kisebb mint a felső):
    Három elem egymás mellett, azonos súlyú Expanded-ekben vagy csak Row-ban gap-pel.
    Minden elem: ColoredIcon + érték + "g" — progress bar nincs, szöveges cím nincs.
    Kinézet forrása: a dashboard compact StatCard (stat_card.dart), de egyszerűsítve —
    csak az ikon és az érték, a progress bar és badge elhagyva.

    Fehérje: Icon(Icons.egg_alt, size 16, color mc.protein)
             + Text("${protein.toStringAsFixed(0)} g", labelMedium, w600, mc.protein)
    Szénhidrát: Icon(Icons.bakery_dining, size 16, color mc.carbs)
                + Text("${carbs.toStringAsFixed(0)} g", labelMedium, w600, mc.carbs)
    Zsír:  Icon(Icons.water_drop, size 16, color mc.fat)
           + Text("${fat.toStringAsFixed(0)} g", labelMedium, w600, mc.fat)

    A felső és alsó sor között: SizedBox(height: 6).

  Szín-forrás: context.metricColors (mc.*) az app_tokens.dart AppMetricColors-ból.
  Spacing/radius tokenek: AppRadius.card, AppSpacing.* — nem hardcoded értékek.
  Nincs tap/swipe akció a sorokon (csak olvasható).
```

---

## Prompt 4 — A 4. tab beillesztése a Nutrition képernyőbe

```
Módosítsd: mobile/lib/features/nutrition/presentation/nutrition_screen.dart

Adj hozzá negyedik tabként a Macros tabot (a meglévő sorrend NEM változik):
  0 = Foods, 1 = Meals, 2 = Recipes, 3 = Macros

Változtatások:
  - TabController length: 3 → 4
  - TabBarView children: add hozzá const MacrosTab() negyedikként
  - PillTabBar tabs: add hozzá Tab(text: l10n.macrosTabLabel) negyedikként
  - nutritionPendingTabProvider doc-komment: frissítsd (3 = Macros)
  - Frissítsd a megjegyzést a _HeaderSpacer kommentjében is

FAB-kezelés a Macros tabon (index 3):
  A Macros tab csak olvasható, nincs "+" akció. A _fab switch-ben a 3-as esetben
  ne adj vissza FAB adatot — nézd meg a shell_fab.dart shellFabProvider-t, hogyan
  törölhető a FAB (pl. .set(null) vagy hasonló minta), és a _pushFab metódusban a
  3-as indexnél hívd azt. Így nem marad ott a Recipes "+" gombja Macros tabra váltáskor.

PillTabBar:
  4 fül esetén ellenőrizd, hogy nem szorulnak-e össze. Ha a PillTabBar
  scrollozható (physics paraméter), nincs teendő; ha nem, teszteld vizuálisan
  és szükség esetén adj scrollable: true-t.
```

---

## Prompt 5 — Ellenőrzés

```
Futtasd a következőket és javítsd az esetleges hibákat:

1. flutter gen-l10n
2. dart run build_runner build  (ha @riverpod annotációt használtál)
3. flutter analyze lib/features/nutrition/domain/daily_macros.dart \
                    lib/features/nutrition/application/daily_macros_controller.dart \
                    lib/features/nutrition/presentation/macros_tab.dart \
                    lib/features/nutrition/presentation/nutrition_screen.dart

Indítsd el az appot és ellenőrizd:
  - A Macros fül megjelenik negyedikként a Nutrition PillTabBar-ban
  - Today szűrő: aznap étkezéseinek összesítője látszik (1 sor)
  - Week szűrő: max 7 sor az elmúlt 7 napra
  - All szűrő: minden betöltött nap (paginációs korláttal — ez ismert)
  - Üres állapot: ha nincs adat, az EmptyView jelenik meg
  - Macros tabon a "+" FAB nem látszik
  - A kalória hangsúlyos (felső sor, nagyobb), a makrók kisebbek alatta ikon+g-vel
```

---

## Adatkapcsolatok (referencia a fejlesztőnek)

| Elem | Forrás fájl |
|---|---|
| Meal lista | `mealControllerProvider` — `meals_tab.dart` |
| Napok szűrése | `DateRangeFilter` — `date_range_filter_bar.dart` |
| Makró-ikonok/színek | `AppMetricColors` — `app_tokens.dart` |
| Kártya-minta | `_MealCard` — `meals_tab.dart` |
| compact StatCard | `stat_card.dart` (`features/dashboard/presentation/widgets/`) |
| Pill tab host | `nutrition_screen.dart` |

## Ismert korlát

Az „All" szűrő csak a memóriában lévő (lapozott) meal-ekből aggregál. Teljes pontossághoz
egy `MealRepository.watchDailyMacros()` Drift query kell — ezt a prompt 1 TODO-ként jelöli,
külön feladatként implementálandó.
