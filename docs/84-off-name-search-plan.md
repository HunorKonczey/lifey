# 84 – Food search by name in OpenFoodFacts

Status: proposed (planning only — no code written; the Prompt 0 spike must run first)
Scope: backend · web · mobile
Depends on: docs/11-v2-pland.md (OpenFoodFacts proxy, barcode lookup — built), docs/12-language-plan.md (HU/EN language setting — built), docs/78 W2.5/W2.6 (web add-food dialog), docs/75 (log a food from the Foods tab)

## 1. What we're building

Today OpenFoodFacts (OFF) is reachable only by scanning a barcode (`GET /foods/barcode/{barcode}`
→ `BarcodeLookupServiceImpl` → `OpenFoodFactsClientImpl`). This plan lets the user find a packaged
food **by typing its name** and log it, on web and on mobile.

1. In the add-food surface — the web **Add food** dialog (`AddFoodModal`) and the mobile **add meal
   entry sheet** (`AddMealEntrySheet`) — there is a **checkbox "Search OpenFoodFacts too"**. It is
   **off by default**, and remembered per device once ticked.
2. With the checkbox on and at least 3 characters typed, the client asks the backend, which searches
   OFF **in the user's language first (HU or EN, from the language setting)**. If that search
   returns **nothing usable**, the backend searches again **in English** and says so
   (`fellBackToEnglish`).
3. OFF results appear in their own **"From OpenFoodFacts" section below the user's own foods and
   recipes**; own results are never pushed down or replaced. A row shows name, brand, kcal / 100 g.
4. Picking an OFF row works like picking a food: quantity, meal type, macro preview, "left after
   this". Submitting **first saves it as one of the user's foods** (`POST /foods`, with its barcode,
   `hidden=false`), **then logs it**. From then on it is an ordinary own food — found offline,
   editable, in the Foods tab.
5. With the checkbox off, nothing changes: no request leaves the app, no text is sent anywhere.
6. When OFF is slow, rate-limited or down, the dialog says so under the own results and keeps
   working. It never blocks logging and never turns into a spinner that does not end.

## 2. Key design decisions

### D1 The backend does the search; clients never talk to OFF
Same reasoning as docs/11 §1: OFF requires an identifying `User-Agent`, the egress IP is shared (the
rate limit applies to us, not per user), and one proxy lets us cache, filter and change the OFF
endpoint without a mobile release. Rejected: calling OFF from the browser/phone — no cache, no shared
limiter, a User-Agent we cannot set from a browser.

### D2 New endpoint `GET /api/v1/foods/off-search?q=…&lang=hu|en`
Next to the existing `GET /foods/barcode/{barcode}` in `FoodController`. Rejected: overloading
`GET /foods?search=` (it is the paged own-catalog search and the offline-sync feed; mixing a third-party
source into it would make sync and caching ambiguous) and `/foods/search` (collides visually with
`/foods/{id}`). Response (never a 500 for an OFF problem):

```json
{
  "status": "OK | UNAVAILABLE | RATE_LIMITED",
  "language": "hu",
  "fellBackToEnglish": false,
  "items": [
    { "barcode": "4056489827702", "name": "Csirkemell", "brand": "Pikok",
      "caloriesPer100g": 110, "proteinPer100g": 14, "carbsPer100g": 2.4, "fatPer100g": 4.9,
      "nameLanguage": "hu" }
  ]
}
```

At most 20 items; no paging in v1. `lang` is only `hu` or `en` (anything else → `en`).

### D3 The client sends the language; the backend does not guess it
`LanguagePreference` is `SYSTEM | ENGLISH | HUNGARIAN`; `SYSTEM` is resolved from the device or
browser, which only the client knows. Web sends `useLocale()`, mobile sends the app's resolved
locale (`AppLocalizations.of(context).localeName`). Rejected: reading `Accept-Language` — the
Flutter client's header does not follow the in-app language override.

### D4 Language-first, then English — and only on "nothing usable", never on an error
Flow in a new `FoodNameSearchService` (package `nutrition/food/service/`):

1. `lang == en` → one search.
2. Otherwise search `lang`; if the **filtered** result (D6) is empty → search `en` once, set
   `fellBackToEnglish=true`, `language="en"`.
3. If a search **fails** (timeout, 5xx, 429) → return `status=UNAVAILABLE` / `RATE_LIMITED` with
   whatever is already known. **Do not** run the English search as a retry: showing English hits
   because the Hungarian call timed out would look like "no Hungarian results" and is a silent lie.

Rejected: merging both languages into one list (doubles the calls, duplicates every product that
exists in both) and falling back whenever there are fewer than N results (the requirement is
"nothing came back"; a threshold is an invented rule).

### D5 Which OFF endpoint: search-a-licious, behind a second base URL
Probed live on 2026-10-06 with "csirkemell": both `GET /cgi/search.pl` (v1, `world.openfoodfacts.org`)
and `GET https://search.openfoodfacts.org/search?q=…&langs=hu` (search-a-licious) answer. Choice:
**search-a-licious** (the OFF-recommended full-text search, language parameter, small field list via
`fields=`). New property `lifey.openfoodfacts.search-base-url` (default
`https://search.openfoodfacts.org`, env `OPENFOODFACTS_SEARCH_BASE_URL`) in `OpenFoodFactsProperties`,
and a second `RestClient` bean (`openFoodFactsSearchRestClient`) in `OpenFoodFactsConfig` with the same
User-Agent but its own timeout (search is slower than a barcode hit; start at 5 s, tune in the spike).
The barcode client keeps `world.openfoodfacts.org`. Rejected: v1 `search.pl` — older, slower, and the
page-size/field behaviour is less predictable; kept as the documented fallback if the spike finds
search-a-licious unsuitable.

### D6 Filtering lives in the backend, one function, and is strict
An OFF hit becomes an item only if **all** hold:

- it has a non-blank product name — in the requested language if OFF has one, else the product's own
  `product_name` (then `nameLanguage` says which language it is);
- it has `energy-kcal_100g` **and** `proteins_100g` (same rule as `hasUsableNutrition` in
  `BarcodeLookupServiceImpl`, so a name hit and a barcode hit are interchangeable);
- the numbers are **plausible**: kcal ≤ 900, and each of protein / carbs / fat ≤ 100 per 100 g
  (community data contains typos like 9 000 kcal);
- the user does not already own that barcode (`FoodRepository.findByUserIdAndBarcode`) — it is already
  in their own list, and saving it again would hit the `(user_id, barcode)` unique index from
  `V40__foods_exercises_ownership.sql`.

Carbs and fat may be `null` (OFF often lacks them); clients treat `null` as 0, as the barcode flow
does today. The "usable" check of D4 runs on this filtered list.

### D7 A small hand-rolled cache and a global limiter — no new dependency
OFF asks clients not to hammer search (and not to use it for type-ahead; the figure of ~10 search
requests per minute per IP is to be confirmed in the spike). Every Lifey user shares one egress IP, so:

- `OffSearchCache`: bounded LRU with TTL (e.g. 500 entries, 10 min), key = `lang + normalised query`
  (**the language is part of the key** — a Hungarian result must never answer an English request).
  Only `OK` results are cached; `UNAVAILABLE` is not.
- `OffSearchLimiter`: one global limit (configurable, `lifey.openfoodfacts.search-per-minute`); over it
  the endpoint answers `status=RATE_LIMITED` immediately without calling OFF.

Rejected: Spring Cache + Caffeine (CLAUDE.md: no new framework without justification — ~60 lines of
`LinkedHashMap` cover this one cache) and per-user quotas (the shared IP is the scarce thing; per-user
fairness is a non-goal for v1).

### D8 Nothing is persisted until the user logs it
The search endpoint is read-only: no table, **no Flyway migration**, nothing in the delta-sync feed.
Saving happens at log time, exactly like a scanned barcode (docs/11: "the client must POST /foods to
persist it"). Rejected: caching OFF products in a shared server table — `foods` is user-owned
(V40), and a global product table is a separate, larger decision.

### D9 The text sent to OFF is only what the user typed, nothing else
The query string and the Lifey `User-Agent` leave our server — no user id, no email, no language
other than `hu`/`en`. That is why the checkbox is **off by default** and remembered only after the
user turned it on: typing into the search is otherwise a purely local act.

### D10 The checkbox, the debounce and the section are client state only
- Web: preference in `localStorage` (`lifey.addFood.offSearch`, read inside try/catch like the other
  per-viewer conveniences); query debounced 400 ms, minimum 3 characters, `useQuery` with
  `staleTime` 10 min and `placeholderData` so the list does not flash.
- Mobile: preference via the same storage pattern as `core/push/weigh_in_reminder_preferences.dart`;
  online-only — offline the checkbox is disabled with a hint, because the rest of the sheet is
  offline-first and must stay so.

## 3. UI spec

### 3.1 Web — `web/src/features/nutrition/components/addFood/`
- `FoodSearchPane.tsx`: under the filter chips, a `Checkbox` (`@/components/ds`) "Search OpenFoodFacts
  too". Below the own results a section label "From OpenFoodFacts" and rows in the same shape as own
  rows (name, `Brand · kcal / 100 g`, a small "OFF" tag). While loading: a one-line skeleton, not a
  spinner over the list. Notes under the section, one at a time:
  `fellBackToEnglish` → "No Hungarian results — showing English ones."; `UNAVAILABLE` → "OpenFoodFacts
  isn't answering right now."; `RATE_LIMITED` → "Too many searches — try again in a minute.".
- `foodSearch.ts`: `SearchItem` gains a third kind `"off"` (`key: off:<barcode>`, carries the item).
  `searchItems()` is **not** changed — OFF rows are appended by the pane, never ranked into own rows.
- `FoodPreviewPane.tsx`: handles `kind === "off"` — grams (default 100), the four macro tiles, "left
  after this", meal type; the source line reads "OpenFoodFacts · 110 kcal / 100 g · Pikok". The mutation
  creates the food first (`foodApi.create`, `hidden: false`, `barcode`), then goes through the existing
  `addFoodEntry`.
- `api.ts` / `types.ts` / `web/src/lib/api/queryKeys.ts`: `foodApi.offSearch(q, lang)`,
  `OffSearchResponse`, `queryKeys.foods.offSearch(q, lang)`.
- `web/messages/en.json` + `hu.json` under `nutrition.addFoodModal`.
- Gallery: `AddFoodModalSection.tsx` gets a fixture OFF result set so the section is testable without a
  backend (the `ds` e2e project has none).

### 3.2 Mobile — `mobile/lib/features/nutrition/`
- `presentation/widgets/add_meal_entry_sheet.dart`: a `CheckboxListTile`-style row "Search
  OpenFoodFacts too" above/below the existing food `Autocomplete<Food>`; OFF rows are a second group in
  `_FoodOptions` (own list stays first). Choosing one fills `_food` like an own food after saving it
  (§4 Prompt 10).
- `data/off_search_repository.dart` (pattern: `barcode_lookup_repository.dart`): online-only Dio call,
  no drift cache, no outbox. `core/constants/api_endpoints.dart`: `foodsOffSearch`.
- `application/off_search_controller.dart` (pattern: `barcode_lookup_controller.dart`): debounce,
  min length, the checkbox preference, the three statuses.
- Saving the picked product goes through the existing offline-first `FoodRepository.create` (outbox +
  `clientId`), so the sheet's "log it" path is unchanged after that.
- Strings: `mobile/lib/l10n/app_en.arb` + `app_hu.arb` (use the `localization` skill; check with
  `check_arb_sync`).

## 4. Order of work

**Smallest thing worth using: Milestone 1 + 2 (backend + web).** Mobile follows once the endpoint has
been used for a while.

### Milestone 0 — Know the API
- Prompt 0 (no merged code)

### Milestone 1 — Backend: a search endpoint that is safe to call
- Prompts 1–4. Demo: `curl` the endpoint with a Hungarian and an English term, and with a nonsense term.

### Milestone 2 — Web: the checkbox and the section
- Prompts 5–7. Demo: tick the box in the Add food dialog, type "csirkemell", pick a row, log it.

### Milestone 3 — Mobile
- Prompts 8–10. Demo: same flow on the emulator, then in airplane mode (checkbox disabled, own foods fine).

### Milestone 4 — Close
- Prompt 11.

## Prompt 0 — Spike: confirm what OFF really does (research, result goes into this doc)
Run against `search.openfoodfacts.org` and note the findings under a new "Spike results" heading here:
1. Does `langs=hu` restrict matching or only the returned name fields? Is `product_name` returned in the
   requested language when the product has one (`product_name_hu`)? Which `fields=` give us name, brand,
   `energy-kcal_100g`, `proteins_100g`, `carbohydrates_100g`, `fat_100g`, `lang`, `countries_tags`?
2. Real rate limit and the response when exceeded (status code, headers). Is it OK for us to call it
   from a server that debounced clients hit? If not, D7's numbers change.
3. 20 Hungarian terms (csirkemell, tej, kenyér, túró, paradicsom, …) and 10 English brand/product
   terms: how many hits survive the D6 filter? How often is a kJ-only product dropped (see Non-goals)?
4. The same term through `search.pl` for comparison; settle D5.
Verification: the findings table is in the doc and D5/D7 are edited to match. **If the survival rate for
Hungarian terms is poor, stop and revisit the plan before Prompt 1.**

## Prompt 1 — Backend: OFF name-search client
- `OpenFoodFactsProperties`: add `searchBaseUrl`; `application.yml`: `search-base-url`,
  `search-per-minute`; `OpenFoodFactsConfig`: `openFoodFactsSearchRestClient`.
- `OpenFoodFactsClient`: add `List<OffSearchHit> searchByName(String query, String lang, int limit)`;
  implement in `OpenFoodFactsClientImpl` with a new raw response record next to `OffApiResponse`
  (`@JsonIgnoreProperties(ignoreUnknown = true)`).
- A transport failure is a typed exception (`OffUnavailableException`, `OffRateLimitedException` for 429),
  not an empty list — D4 depends on telling "nothing" from "failed".
Verification: `OpenFoodFactsClientImplTest` with a stub server (200 with hits, 200 empty, 429, timeout).
Mergeable alone: nothing calls it yet.

## Prompt 2 — Backend: language-first search with English backoff and filtering
- `FoodNameSearchService` + `Impl` (package `nutrition/food/service/`): D4 flow, D6 filter as one
  package-private function, dedupe against `FoodRepository.findByUserIdAndBarcode`.
- DTOs in `nutrition/food/dto/`: `OffSearchResponse`, `OffSearchItem`, `OffSearchStatus`.
Verification: `FoodNameSearchServiceImplTest` — hu hit (no fallback); hu empty → en hit
(`fellBackToEnglish`); hu timeout → `UNAVAILABLE` **and the English client is never called**; en request
makes one call; each D6 rule has a test; an owned barcode is dropped.

## Prompt 3 — Backend: cache and global limiter
- `OffSearchCache` (bounded LRU + TTL, key `lang|normalised query`), `OffSearchLimiter`; wired into the
  service. Normalise like the web (`normalizeForSearch`: trim, lowercase, accents folded).
Verification: unit tests — second identical call is a cache hit (stub client called once); different
`lang` is a miss; `UNAVAILABLE` is not cached; limiter over the limit answers `RATE_LIMITED` without a
client call; TTL expiry with an injected clock.

## Prompt 4 — Backend: the endpoint
- `FoodController`: `GET /off-search` (`@RequestParam q` min length 3 → 400 otherwise, `lang`),
  OpenAPI `@Operation` text as the barcode endpoint has; docs/postman collection entry.
Verification: `FoodControllerTest` — 200 shape, 400 on a 2-character query, 401 without a token, user
scoping (another user's owned barcode is not dropped for me). `./mvnw -q test` green.

## Prompt 5 — Web data: API, types, hook
- `api.ts`, `types.ts`, `queryKeys.ts`, and `useOffSearch(query, lang, enabled)` (debounce, min length,
  `staleTime`) in `web/src/features/nutrition/`; a pure `offItemToSearchItem` mapper.
Verification: Vitest for the mapper and the "disabled below 3 characters / when unchecked" rule; `tsc`,
`eslint`.

## Prompt 6 — Web UI: the checkbox and the "From OpenFoodFacts" section
- `FoodSearchPane.tsx`, `AddFoodModal.tsx` (preference + passing results down), messages en/hu, gallery
  fixture. Rows are selectable and the preview shows the macros; submit is wired in Prompt 7.
Verification: `web/e2e/ds/addFoodSearch.spec.ts` additions — box off: no OFF section and no request;
box on: section under own rows; the three status notes; `fellBackToEnglish` note; preference survives a
reload (localStorage). Check at 1440 and 390 (the Modal is a bottom sheet below 768 px).

## Prompt 7 — Web: pick, save as own food, log
- `FoodPreviewPane.tsx` `kind === "off"`: create the food, then `addFoodEntry`; the dialog stays open
  afterwards (it does since the web add-food fix: an add no longer closes it) and the new food shows in own
  results.
  If the create returns 409 (`DuplicateResourceException`, barcode already owned) re-fetch foods and use
  the existing one instead of failing.
Verification: e2e in the gallery with stubbed submit; against the real backend by hand: log one OFF
food, see it in the Foods tab with its barcode, log it a second time from own results (no second
`POST /foods`).

## Prompt 8 — Mobile data: repository and controller
- `off_search_repository.dart`, `off_search_controller.dart`, `ApiEndpoints.foodsOffSearch`, the
  preference store, the `OffSearchResult` domain model.
Verification: `flutter test` unit tests with a fake Dio — statuses map to states, debounce coalesces
keystrokes, the preference is read/written, offline (`DioException` connection error) → `unavailable`.

## Prompt 9 — Mobile UI: the checkbox and the OFF group in the sheet
- `add_meal_entry_sheet.dart`, `_FoodOptions`; ARB strings (en + hu). Selecting is wired in Prompt 10.
Verification: widget tests — off by default and no call; ticked + 3 characters shows the group under
own foods; offline disables the checkbox; `flutter analyze` clean. Emulator check at 1.0 and 1.3 text scale.

## Prompt 10 — Mobile: pick → save through the offline-first stack → log
- Choosing an OFF row creates the `Food` via `FoodRepository.create` (outbox, new `clientId`, barcode
  set), selects it in the sheet, and the rest of the sheet is untouched. Duplicate barcode locally →
  select the existing food.
Verification: repository/widget test that exactly one outbox entry is enqueued and a second pick of the
same barcode enqueues none; emulator: pick online, kill the network, log works; then reconnect and check
the food reaches the backend (docs/15-delta-sync.md).

## Prompt 11 — Close
- Status here → built; the `docs/README.md` row (added with this plan) updated; note in
  docs/11-v2-pland.md pointing to this plan; Postman updated; the spike table kept.

## 5. After implementation
- Update this doc's Status and the README row; add the spike results permanently.
- Follow-ups deliberately left out are listed under Non-goals.

## Non-goals (deferred)
- **AI estimation as a fallback when OFF finds nothing.** It already exists as its own feature
  (docs/23); this plan does not link, offer or trigger it.
- Searching OFF from the mobile **create-food form** (`add_food_sheet.dart`) or the web **Foods tab
  editor** — v1 covers the two logging surfaces only.
- Paging / "load more" of OFF results (20 is the cap).
- Showing per-serving values, nutriscore, images, allergens.
- Deriving kcal from kJ when a product only has `energy_100g` (it is dropped today, same as the
  barcode flow). Revisit after the spike shows how many Hungarian products this costs.
- Countries beyond language: no "only products sold in Hungary" filter (the spike decides whether it is
  worth adding).
- A shared server-side product table; per-user OFF quotas.
- Languages other than `hu`/`en`.

## Edge cases
- Query shorter than 3 characters, only spaces, or punctuation → no request, no section.
- The user types fast: only the last debounced query is sent; a late response for an older query is
  ignored (`useQuery` key / controller token).
- Same product returned twice (two OFF records with one barcode) → deduplicate by barcode in the service.
- A product the user already owns → dropped from OFF results (D6), it is in the own list.
- Product in `fellBackToEnglish` mode: name is English; row still shows `nameLanguage` implicitly through
  the section note — and the saved food keeps that English name (the user can rename it).
- Beverages: OFF values are per 100 **ml** and we store per 100 g, so the "grams" of a drink are ml.
  Accepted for v1 (the barcode flow does the same today); the row does not say "ml".
- Typed Hungarian term in the English backoff will usually find nothing; the section then shows the
  "no results" line, not an error. The backoff pays off for brand and English product names.
- The user changes language in Settings with the dialog closed → next open uses the new language;
  cached results are keyed by language (D7).
- 429 / timeout → status note; own results unaffected; no automatic retry loop.
- Offline on mobile → checkbox disabled; own offline search unchanged.
- Server restart empties the cache — harmless.

## Test plan
- **Backend unit:** client (stub server), service (D4 flows, D6 rules, dedupe), cache (keys, TTL,
  `UNAVAILABLE` not cached), limiter. **Controller:** shape, validation, auth, scoping.
- **Backend integration:** none against the real OFF — it is a community service and must not be called
  from CI. One manual smoke script in the Prompt 0 notes.
- **Web:** Vitest (mapper, enable rules, normalisation parity with the backend), `ds` e2e on the gallery
  fixture (checkbox, section, notes, persistence, 1440 + 390).
- **Mobile:** unit (repository, controller), widget (sheet states), repository test for the outbox
  entry; emulator walk once at the end (owed, like earlier plans).
- **Manual:** one real-device walk with real Hungarian terms, noting the survival rate again.

## Suggested PR split
1. **PR 1 — Backend** (Prompts 1–4): endpoint merged, unused by clients; reviewable with `curl`.
2. **PR 2 — Web** (Prompts 5–7).
3. **PR 3 — Mobile** (Prompts 8–10).
4. **PR 4 — Docs close** (Prompt 11), or folded into PR 3.
Prompt 0 has no PR of its own: its findings land as a commit to this doc ahead of PR 1.

## Risk checkpoints where a failure would be silent
- **A failed Hungarian search shown as English results** (D4 step 3): review that the English call sits
  only on the "success and empty" branch. Test: hu timeout → English client never invoked.
- **Cache key without the language:** a Hungarian answer served to an English request. Test with the same
  query in both languages.
- **Implausible numbers logged as truth** (9 000 kcal, 250 g fat): the D6 plausibility bounds are the only
  guard; a unit test per bound, and the bounds live in one named constant.
- **Per 100 ml treated as per 100 g** for drinks: known and accepted (edge cases), but it makes logged
  kcal wrong by the density — keep an eye on it in the manual walk.
- **Saving the food before the log fails**: the user ends up with the food but no meal entry. Acceptable
  and idempotent (retry finds the existing food by barcode), but the toast must say "Couldn't add it",
  not hide the partial state. Test: create succeeds, meal save fails → retry makes no second food.
- **Barcode unique index `(user_id, barcode)`:** a second save of the same product must reuse, not
  fail (Prompt 7 / 10 tests). A 409 surfaced to the user would look like a broken button.
- **Limiter too tight or too loose:** too tight and the feature seems dead after a few users, too loose
  and OFF blocks our IP for everyone including the barcode scanner (same host family). The limit is
  configuration, and the spike's rate-limit finding sets its default.
- **Debounce missing on one client:** a keystroke-per-request client would burn the shared limit in
  minutes. Both clients have a debounce test.
