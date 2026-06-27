# Lifey Web — API integrációs referencia

> A web a meglévő Spring Boot REST API-t fogyasztja. Ez a fájl a **tényleges backend
> kontrollerekből és DTO-kból** kivonatolt, pontos szerződés — a Zod sémák és TanStack Query
> hookok ehhez igazodnak. Minden végpont a `/api/v1` alatt él, és (auth kivételével) **a
> hitelesített userhez kötött** — `userId`-t soha nem küldünk inputként, a backend a tokenből
> dolgozik.
>
> ⚠️ Két fontos jelenlegi korlát (részletek a [`08`](08-backend-gaps-and-changes.md)-ban):
> 1. A lista-végpontok **nem lapozottak** — teljes `List<...>`-t adnak vissza.
> 2. A statisztika **csak skalár összegeket** ad (nincs napi idősor a trend-grafikonokhoz).

---

## 1. Enumok (forrás: backend)

| Enum | Értékek |
|---|---|
| `Role` | `ROLE_USER`, `ROLE_ADMIN` |
| `MealType` | `BREAKFAST`, `LUNCH`, `DINNER`, `SNACK` |
| `MuscleGroup` (exercise category) | `CHEST`, `BACK`, `SHOULDERS`, `BICEPS`, `TRICEPS`, `FOREARMS`, `QUADS`, `HAMSTRINGS`, `GLUTES`, `CALVES`, `ABS`, `CARDIO`, `FULL_BODY` |
| `Equipment` | `BARBELL`, `DUMBBELL`, `MACHINE`, `CABLE`, `BODYWEIGHT`, `SMITH_MACHINE` |
| `UnitSystem` | `METRIC`, `IMPERIAL` |
| `ThemePreference` | `LIGHT`, `DARK`, `SYSTEM` |
| `LanguagePreference` | `SYSTEM`, `ENGLISH`, `HUNGARIAN` |
| `BarcodeSource` | `LOCAL`, `OPENFOODFACTS` |

> Megjegyzés: az `ExerciseResponse.category`/`.equipment` **string**-ként jön (nem enum típus),
> de a fenti értékkészletből — a Zod sémában `z.enum([...])`-ként vagy `z.string()`-ként kezeld
> defenzíven (ismeretlen érték ne dobjon).

---

## 2. Auth — `/api/v1/auth`

| Metódus | Útvonal | Request | Response | Megjegyzés |
|---|---|---|---|---|
| POST | `/register` | `RegisterRequest` | `201 UserResponse` | email + jelszó (min. 8 karakter) |
| POST | `/login` | `LoginRequest` | `200 AuthResponse` | refresh ma body-ban (lásd 04 §5) |
| POST | `/refresh` | `RefreshRequest` | `200 AuthResponse` | **rotáció**: a régi refresh érvénytelen lesz |
| POST | `/logout` | `RefreshRequest` | `204` | adott refresh visszavonása |
| POST | `/logout-all` | — (hitelesített) | `204` | összes eszköz kiléptetése |

```
RegisterRequest { email: string(@Email), password: string(8..100) }
LoginRequest    { email: string(@Email), password: string }
RefreshRequest  { refreshToken: string }
AuthResponse    { accessToken: string, refreshToken: string, tokenType: "Bearer", expiresIn: number }
UserResponse    { id: number, email: string, roles: Role[], createdAt: string(Instant) }
```

---

## 3. Foods — `/api/v1/foods`

| Metódus | Útvonal | Request | Response |
|---|---|---|---|
| GET | `/` | — | `FoodResponse[]` (összes, nem lapozott) |
| GET | `/{id}` | — | `FoodResponse` |
| POST | `/` | `FoodRequest` | `201 FoodResponse` |
| PUT | `/{id}` | `FoodRequest` | `FoodResponse` |
| DELETE | `/{id}` | — | `204` |
| GET | `/barcode/{barcode}` | — | `BarcodeLookupResponse` |

```
FoodRequest  { name, caloriesPer100g>=0, proteinPer100g>=0, carbsPer100g>=0,
               fatPer100g>=0, barcode?: string, hidden: boolean }
FoodResponse { id, name, caloriesPer100g, proteinPer100g, carbsPer100g, fatPer100g,
               barcode?: string, hidden: boolean }
BarcodeLookupResponse { id?: number, name, caloriesPer100g, proteinPer100g, carbsPer100g,
               fatPer100g, barcode, source: BarcodeSource }
```

- **Barcode flow (web):** kézi vonalkód-beírás → `GET /barcode/{barcode}`.
  - `source=LOCAL` → `id` kitöltve, már a katalógusban van.
  - `source=OPENFOODFACTS` → `id=null`, **nincs elmentve** → a mező-előtöltés után `POST /foods`.
- Kamera-szken **nincs** weben (mobil-only).
- `hidden=true` → a választó/kereső listákban alapból kihagyva, külön „rejtett" szűrővel látható.

---

## 4. Meals — `/api/v1/meals`

| Metódus | Útvonal | Request | Response |
|---|---|---|---|
| GET | `/` | — | `MealResponse[]` (newest first, nem lapozott) |
| POST | `/` | `MealRequest` | `201 MealResponse` |
| PUT | `/{id}` | `MealRequest` | `MealResponse` |
| DELETE | `/{id}` | — | `204` |

```
MealEntryRequest  { foodId, quantityInGrams>0 }
MealRequest       { dateTime: Instant(@PastOrPresent), mealType: MealType,
                    name?: string(<=255), entries: MealEntryRequest[] (>=1) }
MealEntryResponse { foodId, foodName, quantityInGrams, calories, protein }
MealResponse      { id, dateTime: Instant, mealType: MealType, name?, entries: MealEntryResponse[] }
```

- A backend a `calories`/`protein` mezőket **kiszámolja** (food per-100g × mennyiség) — a web élő
  összesítéshez ugyanezt a képletet helyben is futtatja, de mentés után a szervert tekinti igazságnak.
- Nincs külön „étkezés-tétel" végpont: a tételek a `MealRequest.entries`-ben együtt mennek
  (egy meal = egy étkezés-csoport tételekkel).
- **Napi szűrés** kliensoldalon a `dateTime` lokál-napjára (a backend nem ad `?date` szűrőt).

---

## 5. Recipes — `/api/v1/recipes`

| Metódus | Útvonal | Request | Response |
|---|---|---|---|
| GET | `/` | — | `RecipeResponse[]` |
| GET | `/{id}` | — | `RecipeResponse` |
| POST | `/` | `RecipeRequest` | `201 RecipeResponse` |
| PUT | `/{id}` | `RecipeRequest` | `RecipeResponse` |
| DELETE | `/{id}` | — | `204` |

```
RecipeIngredientRequest  { foodId, quantityInGrams>0 }
RecipeRequest            { name, description?(<=2000), favorite: boolean,
                           servings?>0 (hiányzónál a szerver 1-re defaultol),
                           ingredients: RecipeIngredientRequest[] (>=1) }
RecipeIngredientResponse { foodId, foodName, quantityInGrams, calories, protein }
RecipeResponse           { id, name, description?, favorite: boolean, servings: int,
                           ingredients: RecipeIngredientResponse[] }
```

- **Kedvenc** szűrő kliensoldali (`favorite` mezőből).
- Az összérték a hozzávalókból számolható; az **adagonkénti** érték `összérték / servings`.

---

## 6. Workout — exercises / templates / sessions

### 6.1 Exercises — `/api/v1/exercises`
| Metódus | Útvonal | Request | Response |
|---|---|---|---|
| GET | `/` | — | `ExerciseResponse[]` |
| GET | `/{id}` | — | `ExerciseResponse` |
| POST | `/` | `ExerciseRequest` | `201 ExerciseResponse` |
| PUT | `/{id}` | `ExerciseRequest` | `ExerciseResponse` |
| DELETE | `/{id}` | — | `204` |

```
ExerciseRequest  { name, category?: MuscleGroup, equipment?: Equipment }
ExerciseResponse { id, name, category?: string, equipment?: string }
```
- **Szűrők** (kategória + eszköz) kliensoldaliak a listán.

### 6.2 Templates — `/api/v1/workout-templates`
| Metódus | Útvonal | Request | Response |
|---|---|---|---|
| GET | `/` | — | `WorkoutTemplateResponse[]` |
| GET | `/{id}` | — | `WorkoutTemplateResponse` |
| POST | `/` | `WorkoutTemplateRequest` | `201 ...` |
| PUT | `/{id}` | `WorkoutTemplateRequest` | `...` |
| DELETE | `/{id}` | — | `204` |

```
TemplateExerciseEntry    { exerciseId, targetSets?>0 }
WorkoutTemplateRequest   { name, exercises: TemplateExerciseEntry[] (>=1) }
WorkoutTemplateResponse  { id, name, exercises: TemplateExerciseEntry[] }
```
- A `exercises` **sorrendje hordozza a megjelenítési sorrendet** (drag&drop → tömb-átrendezés →
  PUT). A backend `V20__template_exercise_sort_order` migrációja perzisztálja a sorrendet.

### 6.3 Sessions — `/api/v1/workout-sessions`
| Metódus | Útvonal | Request | Response |
|---|---|---|---|
| GET | `/` | — | `WorkoutSessionResponse[]` |
| POST | `/` | `WorkoutSessionRequest` | `201 ...` |
| PUT | `/{id}` | `WorkoutSessionRequest` | `...` |
| DELETE | `/{id}` | — | `204` |

```
ExerciseSetRequest      { exerciseId, reps>0, weight>=0, performedAt: Instant(@PastOrPresent) }
WorkoutSessionRequest   { startedAt: Instant, finishedAt?: Instant, exerciseIds: number[],
                          sets: ExerciseSetRequest[], activeCalories?>=0,
                          averageHeartRate?>=0, healthWorkoutId?: string }
ExerciseSetResponse     { exerciseId, exerciseName, reps, weight, performedAt: Instant }
ExerciseSummary         { exerciseId, exerciseName }
WorkoutSessionResponse  { id, startedAt, finishedAt?, exercises: ExerciseSummary[],
                          sets: ExerciseSetResponse[], activeCalories?, averageHeartRate?,
                          healthWorkoutId? }
```
- **Health mezők** (`activeCalories`, `averageHeartRate`, `healthWorkoutId`) forrása az Apple
  Health (mobil) — weben **csak olvashatók** (a logger ne kínáljon szerkesztést rájuk).
- **Élő naplózás** mintája: a session indítható üresen vagy sablonból (`exerciseIds` előtöltve);
  a logger fokozatosan PUT-tal frissíti a `sets` tömböt és a végén `finishedAt`-et.
- **Gyakorlat-progresszió:** nincs dedikált végpont → a `GET /workout-sessions` előzményből,
  gyakorlatonként szűrve számolható a súly/ismétlés-trend (kliensoldalon).

---

## 7. Weight — `/api/v1/weights`

| Metódus | Útvonal | Request | Response |
|---|---|---|---|
| GET | `/` | — | `WeightResponse[]` |
| POST | `/` | `WeightRequest` | `201 WeightResponse` |
| DELETE | `/{id}` | — | `204` |

```
WeightRequest  { date: LocalDate(@PastOrPresent), weight>0 }
WeightResponse { id, date: LocalDate, weight }
```
- **Nincs PUT** — javítás = törlés + új bejegyzés (vagy ugyanarra a napra új POST, ha a backend
  felülírja; ezt érdemes a `08`-ban tisztázni). A trend a `date` szerint rendezett sorból épül.

---

## 8. Water — entries + sources

### 8.1 Entries — `/api/v1/water-entries`
| Metódus | Útvonal | Request | Response |
|---|---|---|---|
| GET | `/` | — | `WaterEntryResponse[]` |
| POST | `/` | `WaterEntryRequest` | `201 ...` |
| DELETE | `/{id}` | — | `204` |

```
WaterEntryRequest  { consumedAt: Instant, sourceId?: number, volumeLiters>0 }
WaterEntryResponse { id, consumedAt: Instant, volumeLiters, sourceId?, sourceName? }
```
- A `sourceId` **csak informatív** — a volument a kliens küldi (a forrás csak előtölti).
- **Nincs PUT** entry-re (törlés + új).

### 8.2 Sources — `/api/v1/water-sources`
| Metódus | Útvonal | Request | Response |
|---|---|---|---|
| GET | `/` `/{id}` | — | `WaterSourceResponse[]` / `WaterSourceResponse` |
| POST | `/` | `WaterSourceRequest` | `201 ...` |
| PUT | `/{id}` | `WaterSourceRequest` | `...` |
| DELETE | `/{id}` | — | `204` |

```
WaterSourceRequest  { name, volumeLiters>0 }
WaterSourceResponse { id, name, volumeLiters }
```
- A források adják a dashboard/water-oldal **gyors „+" gombjait**.

---

## 9. Steps — `/api/v1/steps`

| Metódus | Útvonal | Request | Response |
|---|---|---|---|
| GET | `/` | — | `DailyStepCountResponse[]` |
| POST | `/` | `DailyStepCountRequest` | `201 ...` |
| PUT | `/{id}` | `DailyStepCountRequest` | `...` |
| DELETE | `/{id}` | — | `204` |

```
DailyStepCountRequest  { date: LocalDate(@PastOrPresent), steps>=0 }
DailyStepCountResponse { id, date: LocalDate, steps }
```
- Weben **kézi bevitel/szerkesztés** (a mobil szenzoros adat web-only nézete).

---

## 10. Settings — `/api/v1/settings`

| Metódus | Útvonal | Request | Response |
|---|---|---|---|
| GET | `/` | — | `SettingsResponse` |
| PUT | `/` | `SettingsRequest` | `SettingsResponse` |

```
SettingsRequest/Response {
  unitSystem: UnitSystem,
  dailyCalorieGoal?>=0, dailyProteinGoal?>=0, dailyCarbsGoal?>=0, dailyFatGoal?>=0,
  dailyWaterGoalLiters?>=0, dailyStepGoal?>0,
  theme: ThemePreference, language: LanguagePreference
}
```
- Ez a **célok igazságforrása** — a dashboard/statisztika cél-progress és cél-tónus ezekből számol.
- A `theme` és `language` a kliens témáját/nyelvét is vezérli (lásd 04 §8).

---

## 11. Statistics — `/api/v1/statistics`

| Metódus | Útvonal | Query | Response |
|---|---|---|---|
| GET | `/daily` | `?date=LocalDate` (opcionális) | `StatisticsResponse` |
| GET | `/weekly` | `?date=LocalDate` | `StatisticsResponse` (utolsó 7 nap összege) |
| GET | `/monthly` | `?date=LocalDate` | `StatisticsResponse` (utolsó 30 nap összege) |

```
StatisticsResponse { totalCalories, totalProtein, totalCarbs, totalFat,
                     workoutCount: int, latestWeight?, totalWater }
```
- A `?date` a **hívó lokál napja** (a nap-határ ehhez igazodik). Mindig küldd a topbar-dátumot.
- ⚠️ **Ez csak aggregált skalár** — nincs napi bontás. A design statisztika-oldala (mockup 10/11.
  frame) **idősoros trendeket** vár (kalória/súly/volumen napi pontokkal). Ezt MA nem adja a
  backend. Megoldási opciók a [`08` §2](08-backend-gaps-and-changes.md)-ben:
  - **A)** új idősoros végpont (`/statistics/series?from&to&metric`) — ajánlott;
  - **B)** kliens N db `/daily?date=...` hívással építi a sort (lassú, sok kérés — csak átmenet).

---

## 12. TanStack Query — kulcsok és invalidáció

Központi kulcsgyár (`lib/api/queryKeys.ts`), hogy a mutációk célzottan invalidálhassanak:

```ts
const keys = {
  foods:    { all: ['foods'], detail: (id) => ['foods', id] },
  meals:    { all: ['meals'], byDate: (d) => ['meals', { date: d }] },
  recipes:  { all: ['recipes'], detail: (id) => ['recipes', id] },
  exercises:{ all: ['exercises'] },
  templates:{ all: ['workout-templates'], detail: (id) => ['workout-templates', id] },
  sessions: { all: ['workout-sessions'] },
  weights:  { all: ['weights'] },
  water:    { entries: ['water-entries'], sources: ['water-sources'] },
  steps:    { all: ['steps'] },
  settings: { root: ['settings'] },
  stats:    (period, date) => ['statistics', period, { date }],
};
```

**Invalidációs térkép** (mely mutáció mit frissít — a statisztika/dashboard mindig érintett):

| Mutáció | Invalidálandó kulcsok |
|---|---|
| meal create/update/delete | `meals.*`, `stats(*)`, dashboard |
| weight create/delete | `weights.all`, `stats(*)`, dashboard |
| water entry create/delete | `water.entries`, `stats(*)`, dashboard |
| steps upsert/delete | `steps.all`, dashboard |
| session create/update/delete | `sessions.all`, `stats(*)`, dashboard |
| food/recipe/template/exercise CRUD | a saját `*.all` + ahol referenciaként megjelenik (pl. meal-választó) |
| settings PUT | `settings.root` + minden cél-progresszt mutató nézet (dashboard, statistics) |

**Optimistic update** ott, ahol a UI azonnali visszajelzést igényel: water „+" gombok, set
„kipipálás" a loggerben, étkezés-tétel hozzáadás. Hibára rollback + toast.
