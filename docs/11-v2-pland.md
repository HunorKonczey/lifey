# V2 Plan — Barcode Scanner + OpenFoodFacts

## Goal

The user scans a barcode → the app looks up the product → the nutrition values
(kcal / protein / carbs / fat per 100g) are auto-filled into the `AddFoodSheet`
→ saved through the existing offline-first Food pipeline.

## Architecture decisions

1. **Backend proxy, not a direct mobile → OpenFoodFacts (OFF) call.**
   - Normalize OFF's quirky data in one place (missing fields, units,
     `nutriments` keys).
   - Cacheable in the DB (V3 AI and statistics can build on it), and it spares
     the OFF community server (mandatory User-Agent).
   - The mobile surface area doesn't grow; the existing `dio_client` + auth
     interceptor stay unchanged.
   - The mobile app calls **our own backend's** new endpoint, not OFF directly.

2. **Store the `barcode` on `Food`** (nullable).
   - A re-scan is recognized instantly from our own catalog (faster,
     OFF-independent, and useful for V3).

## Flow

```
scan (mobile_scanner)
  → GET /api/v1/foods/barcode/{barcode}  (online-only)
      → LOCAL hit: existing Food for the user           → prefill
      → OFF   hit: normalized OpenFoodFacts data         → prefill (not persisted)
      → 404:       no usable data                        → empty sheet + barcode prefilled
  → AddFoodSheet filled in
  → FoodRepository.create (offline-first, barcode syncs too)
```

## Dependency order

```
A1 → A2 → A3 → A4   (backend testable on its own)
                ↓
B1 → B2 → B3 → B4   (B3 already calls A3's live endpoint)
                ↓
               C1
```

Recommendation: complete and test the A phase end to end (Swagger / curl with a
real EAN), then move to mobile.

---

## Phase A — Backend

### A1. `barcode` field on the Food entity + Flyway migration (`V10`)
`Food` currently stores no barcode. Nullable, since manually-entered foods have
none. `foods` is a shared catalog with no `user_id` (see V6), so the index is a
UNIQUE index on `barcode` alone — a barcode identifies one product globally.

### A2. OpenFoodFacts client (new `nutrition/openfoodfacts/` package)
`RestClient`-based client for the OFF v2 `product/{barcode}` endpoint, with a
mandatory User-Agent header and timeouts. DTO limited to the `nutriments` fields
we actually need.

### A3. Barcode lookup endpoint + caching
`GET /api/v1/foods/barcode/{barcode}`: 1) is there already a `Food` (shared
catalog, not user-scoped) with this barcode → return it (`source=LOCAL`); 2) if
not, call OFF + normalize
→ a **non-persisted** lookup result (`source=OPENFOODFACTS`). The actual save
goes through the existing POST `/foods` so the offline sync isn't broken.

### A4. Backend tests
Unit test for the normalization (missing/partial OFF fields); MockMvc test for
the endpoint (LOCAL hit, OFF hit, 404). The OFF client is mocked.

---

## Phase B — Mobile (Flutter)

### B1. Thread `barcode` through the mobile Food layer
`Foods` drift table + schema version bump + migration, `Food` domain,
`FoodRepository.create/update` and the outgoing sync payload all gain a nullable
`barcode`. Run `build_runner`.

### B2. Scanner package + permissions
Add `mobile_scanner`, Android `CAMERA` permission + iOS
`NSCameraUsageDescription`. A reusable `BarcodeScannerScreen` that returns a
scanned EAN/UPC string.

### B3. Barcode lookup repository + controller on mobile
`lookupByBarcode(String)` calls the backend `GET /foods/barcode/{barcode}` via
`dio` (an **online** operation — not the drift cache, since OFF is required).
Riverpod controller: loading / found / notFound / offline states. No outbox
entry for the lookup.

### B4. UI wiring — scan → prefill → save
"Scan barcode" button on the foods tab / `AddFoodSheet`: opens B2, calls B3 with
the result, prefills the sheet fields + barcode. On `notFound`, an empty sheet
with the scanned barcode. Save goes through the existing
`FoodRepository.create`, so the barcode syncs too.

---

## Phase C — Wrap-up

### C1. Roadmap + documentation update
Mark V2 done in `docs/07-roadmap.md`; document OFF User-Agent / rate-limit
considerations + the `GET /foods/barcode/{barcode}` contract.

---

## Open considerations

- OFF rate-limit / error handling (timeout, 5xx) — graceful fallback to an empty
  sheet.
- Multiple results / regional product DB (`world` vs localized OFF) — `world`
  endpoint for now.
