# V2 promptok (temp) — Barcode scanner + OpenFoodFacts

Futtatási sorrend: A1 → A2 → A3 → A4 → B1 → B2 → B3 → B4 → C1.
Részletes terv: `docs/11-v2-pland.md`.

---

## A) Backend

### Prompt A1 — barcode mező + Flyway  ✅ DONE
Add a nullable `barcode` (String) field to the `Food` entity, map it to a
`barcode` column. Flyway migration `V10__food_barcode.sql` adds a nullable
`barcode` column to `foods` plus a UNIQUE index on `barcode` (NOT
`(user_id, barcode)` — `foods` is a shared catalog with no `user_id`, see V6).
Add `barcode` to `FoodRequest`, `FoodResponse`, `FoodMapper`.

### Prompt A2 — OpenFoodFacts kliens
Create a new feature package `com.lifey.nutrition.openfoodfacts`. Add an
`OpenFoodFactsClient` (interface + Impl) that calls
`https://world.openfoodfacts.org/api/v2/product/{barcode}.json` using Spring's
`RestClient`, with a configurable base URL + User-Agent
(`OpenFoodFactsProperties` via `@ConfigurationProperties`, defaults in
`application.yml`), a 3s connect/read timeout, and constructor injection. Map
only the fields we need into an internal `OffProduct` record: product name,
brands, and per-100g energy-kcal, proteins, carbohydrates, fat from
`nutriments`. Return `Optional.empty()` on 404 / status 0 / missing product. No
controller yet.

### Prompt A3 — barcode lookup végpont
Add `GET /api/v1/foods/barcode/{barcode}` to the Foods feature. Logic in a new
`BarcodeLookupService` (interface + Impl): first look up an existing `Food` by
barcode (add a `findByBarcode` to `FoodRepository` — `foods` is a shared
catalog, NOT user-scoped); if found, return it as `FoodResponse` with a
`source=LOCAL` flag. If not found,
call `OpenFoodFactsClient`, normalize into a `BarcodeLookupResponse` (name + 4
macros + barcode + `source=OPENFOODFACTS`) WITHOUT persisting it. Return 404 if
OFF has no usable nutrition data. Use `CurrentUserProvider` like other services.
Add an `@Operation` doc and keep it consistent with existing controller style.

### Prompt A4 — backend tesztek
Write tests for the barcode feature: (1) a unit test for
`BarcodeLookupServiceImpl` covering existing-food hit, OFF hit, and
OFF-not-found, mocking `OpenFoodFactsClient` and `FoodRepository`; (2) a MockMvc
slice test for `GET /api/v1/foods/barcode/{barcode}` with security, asserting
200 for LOCAL/OFF and 404 when absent. Follow the existing test conventions in
the nutrition package; don't remove the Mockito javaagent surefire config.

---

## B) Mobil (Flutter)

### Prompt B1 — barcode a mobil Food rétegen
Thread a nullable `barcode` through the mobile Food layer: add `barcode`
(nullable text) to the `Foods` drift table in
`mobile/lib/core/local_db/tables/food_table.dart`, bump the drift schema version
and add a migration step in `app_database.dart`, add `barcode` to the `Food`
domain model, and include it in `FoodRepository.create/update` and their outbox
payloads. Then run `dart run build_runner build`. Don't hand-edit any `*.g.dart`.

### Prompt B2 — scanner csomag + jogosultságok
Add the `mobile_scanner` package to `mobile/pubspec.yaml`. Configure camera
permissions: Android `CAMERA` in `AndroidManifest.xml`, iOS
`NSCameraUsageDescription` in `Info.plist` (Hungarian description). Create a
reusable `BarcodeScannerScreen` under `lib/features/nutrition/presentation/`
that opens the camera, returns the first scanned EAN/UPC barcode string via
`Navigator.pop`, and handles permission-denied with a friendly message. No
lookup logic yet — just return the raw barcode.

### Prompt B3 — lookup repository + controller
Add a barcode lookup path on mobile. In `food_repository.dart` (or a small
dedicated `BarcodeLookupRepository`) add `lookupByBarcode(String barcode)` that
calls `GET /foods/barcode/{barcode}` via `dio` and parses the result into a
domain object (name + macros + barcode + source). Add the endpoint to
`ApiEndpoints`. Create a Riverpod controller exposing loading / found / notFound
/ offline states. This is an online-only call — do not read from drift and do
not enqueue an outbox entry for the lookup itself.

### Prompt B4 — UI összekötés
Wire the scan flow into the UI. Add a 'Scan barcode' action on the foods tab /
`AddFoodSheet`: it opens `BarcodeScannerScreen`, then calls the barcode lookup
controller. On `found`, prefill the `AddFoodSheet` fields (name + 4 macros) and
carry the `barcode` into `FoodRepository.create`. On `notFound`, open the sheet
empty but keep the scanned barcode prefilled so the user can fill macros
manually. Show a clear message on offline. Match the existing sheet/widget
styling.

---

## C) Záró

### Prompt C1 — roadmap + dokumentáció
Mark V2 as done in `docs/07-roadmap.md` and add a short note documenting the
OpenFoodFacts integration: required User-Agent, the
`GET /foods/barcode/{barcode}` contract, and that lookups are online-only while
food creation stays offline-first.
