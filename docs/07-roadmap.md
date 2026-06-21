V1
- Weight tracking
- Recipes
- Workouts
- Nutrition

V2 — done
- Barcode scanner
- OpenFoodFacts integration

### OpenFoodFacts integration notes

- The mobile app never calls OpenFoodFacts directly — it calls the Lifey
  backend, which proxies and normalizes OFF data. This keeps the mobile
  surface small and centralizes nutrition-data normalization in one place.
- Backend → OFF requests must send a descriptive `User-Agent`
  (`lifey.openfoodfacts.user-agent`, default `Lifey/1.0 (<contact email>)`)
  per OFF's API usage policy. Configurable via `OPENFOODFACTS_USER_AGENT`.
- Contract: `GET /api/v1/foods/barcode/{barcode}` (authenticated)
  - 200 with `{ id, name, caloriesPer100g, proteinPer100g, carbsPer100g,
    fatPer100g, barcode, source }`, where `source` is `LOCAL` (already in
    our shared `foods` catalog) or `OPENFOODFACTS` (fetched live, not
    persisted by this endpoint).
  - 404 if the barcode isn't in our catalog and OFF has no usable
    nutrition data (missing calories or protein).
- Lookups are **online-only**: the mobile barcode lookup repository/
  controller calls the backend directly via `dio` and never reads from or
  writes to the local Drift cache or the sync outbox. Food *creation*
  stays offline-first as before — a scanned barcode just prefills the
  `AddFoodSheet` form, and saving still goes through the normal local-write
  + outbox flow regardless of whether the data came from a scan.

V3
- AI recipe generation
- AI calorie estimation

V4
- HealthKit
- Garmin
- Strava