# 84 – Food search by name in OpenFoodFacts

Status: proposed — Prompt 0 (spike) done 2026-10-06 and D12 decided (option B: Hungarian + Hungary, then English); Prompts 1–3 (backend client, search service, cache + limiter) built, Prompts 4–11 not started
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
   OFF **in the user's language first (HU or EN, from the language setting)** — for a Hungarian
   user **restricted to products sold in Hungary**. If that search returns **nothing usable**, the backend
   searches again **in English, without the country restriction**, and says so (`fellBackToEnglish`).
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
limiter, a User-Agent we cannot set from a browser. **Cost, found in the spike:** OFF's API page says that
when requests come from the users directly (a mobile app) "the rate limits apply per user", while through
our proxy every Lifey user shares one budget. So the proxy is only the right call if cache + limiter (D7)
keep us well under the limit; if the real traffic proves otherwise, calling OFF from the client is the
escape hatch (the endpoint's response shape would stay the same, the client would build it).

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
      "caloriesPer100g": 110, "proteinPer100g": 14, "carbsPer100g": 2.4, "fatPer100g": 4.9 }
  ]
}
```

At most 20 items; no paging in v1. `lang` is only `hu` or `en` (anything else → `en`). There is no
per-item "name language": OFF's own `lang` field is unreliable (Hungarian products are often tagged `en`,
see Spike results), so the response only says which language the **search** ran in.

### D3 The client sends the language; the backend does not guess it
`LanguagePreference` is `SYSTEM | ENGLISH | HUNGARIAN`; `SYSTEM` is resolved from the device or
browser, which only the client knows. Web sends `useLocale()`, mobile sends the app's resolved
locale (`AppLocalizations.of(context).localeName`). Rejected: reading `Accept-Language` — the
Flutter client's header does not follow the in-app language override.

### D4 Language-first (Hungary-restricted for `hu`), then English — only on "nothing usable", never on an error
Flow in a new `FoodNameSearchService` (package `nutrition/food/service/`):

1. `lang == en` → one search, `langs=en`, no country restriction.
2. `lang == hu` → search `langs=hu` **restricted to Hungary** (D12). If the **filtered** result (D6) is
   empty → search `langs=en`, **no country restriction**, once; set `fellBackToEnglish=true`,
   `language="en"`.
3. If a search **fails** (timeout, 5xx, 429) → return `status=UNAVAILABLE` / `RATE_LIMITED` with
   whatever is already known. **Do not** run the English search as a retry: showing English hits
   because the Hungarian call timed out would look like "nothing from Hungary" and is a silent lie.

Spike findings behind it: `langs` is not a filter, it picks which language subfields are searched, so
`hu` and `en` return almost disjoint sets (1 shared product of 14–20 for "csirkemell"). With the Hungary
restriction a Hungarian search is empty for **2 of 20** test terms (tojás, sütőtök); the English pass
mostly pays off for a Hungarian-language user who types an English product or brand ("pumpkin",
"snickers") — and a Hungarian word typed in the English pass finds nothing ("sütőtök" → 0 hits both ways).
That is what was asked for; the section note (§3.1) says what the shown results are.

Rejected: merging both languages into one list (doubles the calls, duplicates every product that
exists in both; `langs=hu,en` in one call was **not** shown to combine usefully and is not used), falling
back whenever there are fewer than N results (the requirement is "nothing came back"; a threshold is an
invented rule), and a third "hu without the country" step (option C of D12 — one more OFF call per miss
for results D12 exists to remove).

### D5 Which OFF endpoint: search-a-licious, behind a second base URL
Probed live on 2026-10-06 with "csirkemell": both `GET /cgi/search.pl` (v1, `world.openfoodfacts.org`)
and `GET https://search.openfoodfacts.org/search?q=…&langs=hu` (search-a-licious) answer. Choice:
**search-a-licious** (the OFF-recommended full-text search, language parameter, small field list via
`fields=`). New property `lifey.openfoodfacts.search-base-url` (default
`https://search.openfoodfacts.org`, env `OPENFOODFACTS_SEARCH_BASE_URL`) in `OpenFoodFactsProperties`,
and a second `RestClient` bean (`openFoodFactsSearchRestClient`) in `OpenFoodFactsConfig` with the same
User-Agent and the timeouts above.
The barcode client keeps `world.openfoodfacts.org`. **Spike confirmed:** search-a-licious answered every
one of ~50 requests (spaced 7 s) with 200 in ~0.2 s, while v1 `search.pl` returned **503 on 4 of 5**
requests at a lower rate than OFF's documented limit — so v1 is rejected, not just "older". Request:
`GET /search?q=<sanitised>&langs=<hu|en>&page_size=20&fields=code,product_name,product_name_hu,product_name_en,brands,lang,countries_tags,nutriments`.
Timeout: **connect 2 s / read 3 s** per call (typical latency is 0.2 s); the Hungarian + English passes
are sequential, so the worst case for one user request is ~6 s, which the client's own timeout must allow.

### D6 Filtering lives in the backend, one function, and is strict
An OFF hit becomes an item only if **all** hold:

- it has a non-blank product name: **`product_name_<lang>` if present, else `product_name`** (the
  product's main-language name; verified: `product_name_hu` is set on 15 of 20 "tej" hits, including an
  English-tagged product whose Hungarian name is "Magyar Tej 1,5%");
- it has `energy-kcal_100g` **and** `proteins_100g` (same rule as `hasUsableNutrition` in
  `BarcodeLookupServiceImpl`, so a name hit and a barcode hit are interchangeable);
- the numbers are **plausible**: kcal ≤ 900, and each of protein / carbs / fat ≤ 100 per 100 g
  (community data contains typos like 9 000 kcal);
- the user does not already own that barcode (`FoodRepository.findByUserIdAndBarcode`) — it is already
  in their own list, and saving it again would hit the `(user_id, barcode)` unique index from
  `V40__foods_exercises_ownership.sql`.

Carbs and fat may be `null` (OFF often lacks them); clients treat `null` as 0, as the barcode flow
does today. The "usable" check of D4 runs on this filtered list. Measured on 30 terms (Spike results):
73–78 % of hits survive; the drops are "no kcal/protein" (15–17 %), "kJ only" (5–8 %), "no name" (≤2 %)
and "implausible" (≤1 %). **The filter does not fix relevance:** OFF also matches the brand field, so
"alma" returns a German salad from the brand *Alma*, and Hungarian terms return French/Dutch products
with Hungarian-sounding brands (see D12).

### D7 A small hand-rolled cache and a global limiter — no new dependency
OFF's API page (read 2026-10-06) sets **10 requests/min/IP for search (`/api/v*/search`, `/cgi/search.pl`)**,
15/min/IP for product reads, says not to use search for search-as-you-type ("you would be blocked very
quickly"), reserves an IP ban, and returns 503 on its global limits. It does **not** state a limit for
the search-a-licious host (`search.openfoodfacts.org`) — we did not try to find it by exceeding it. We
assume the same order of magnitude. Note the barcode lookup already shares the 15/min product-read budget
through the same proxy. Every Lifey user shares one egress IP, so:

- `OffSearchCache`: bounded LRU with TTL (e.g. 500 entries, 10 min), key = `lang + normalised query`
  (**the language is part of the key** — a Hungarian result must never answer an English request).
  Only `OK` results are cached; `UNAVAILABLE` is not.
- `OffSearchLimiter`: one global limit (configurable, `lifey.openfoodfacts.search-per-minute`, **default
  8** — under the documented 10, and one user request can cost two OFF calls because of D4); over it
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

### D11 The typed text is sanitised before it becomes the OFF query
search-a-licious takes **Lucene query syntax**: the spike showed `categories_tags:"en:beverages" tej`
works as a filter, and `tej:`, `"tej`, `a OR`, `tej*` are all accepted without an error. A user typing a
colon or a quote would silently change what is searched. The service keeps letters, digits, spaces,
`-` and `'`, drops everything else, collapses spaces, then applies the 3-character minimum. Rejected:
passing the text through (surprising results, and a user could address any indexed field), and escaping
each special character (more code for the same outcome here). The Hungary restriction (D12) is appended
**after** the sanitised text as a fixed clause, so a user can never alter or drop it.

### D12 For `hu`, search only products sold in Hungary — decided: option B
Decided 2026-10-06 (options were: A language only; **B Hungarian + Hungary, then English**; C Hungarian +
Hungary, then Hungarian without the country, then English). The Hungarian pass appends the clause
`countries_tags:"en:hungary"` (a constant `en:hungary`, in `OpenFoodFactsProperties` as
`hu-country-tag` so it is not buried in code). It acts as a **filter**, not a boost: re-measured on the
same 20 terms (Spike results) every one of 263 returned hits is tagged Hungary, and the usable share is
unchanged (73 %). It removes the brand/foreign noise (`alma` → only Hungarian products instead of the
German salad). The English pass and `lang == en` have **no** country restriction.

Accepted costs: a product sold in Hungary but not tagged so is missed (it can still be found by barcode
or in the English pass); a Hungarian-language user travelling abroad searches Hungarian products only
(the checkbox is the off-switch, and the English pass is unrestricted); the country is tied to the
language, not to a country setting — a user setting would be a later change (Non-goals).

## 3. UI spec

### 3.1 Web — `web/src/features/nutrition/components/addFood/`
- `FoodSearchPane.tsx`: under the filter chips, a `Checkbox` (`@/components/ds`) "Search OpenFoodFacts
  too". Below the own results a section label "From OpenFoodFacts" and rows in the same shape as own
  rows (name, `Brand · kcal / 100 g`, a small "OFF" tag). While loading: a one-line skeleton, not a
  spinner over the list. Notes under the section, one at a time:
  `fellBackToEnglish` → "Nothing found among products sold in Hungary — showing English-language results from everywhere."; `UNAVAILABLE` → "OpenFoodFacts
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

## Prompt 0 — Spike: confirm what OFF really does ✅ (2026-10-06)
Questions asked, answers in "Spike results" below: what `langs` does; which fields give a usable name and
nutriments; the rate limit; how many real Hungarian/English terms survive the D6 filter; v1 vs
search-a-licious. Verification gate "stop if the Hungarian survival rate is poor": **passed** (73 %, 19 of
20 terms had at least one usable hit); D1, D4, D5, D6, D7 were edited from the findings, D11 added, D12
opened and then decided (option B).

### Spike results (all numbers from live calls on 2026-10-06, `User-Agent: Lifey-planning/1.0 (…)`)

**What `langs` does.** Per OpenAPI (`/openapi.json`): "language-specific subfields to choose in which
subfields we're searching in", default `['en']`. It is a **search-field selector, not a result filter**.
"csirkemell": `hu` → 14 hits, `en` → 20, only 1 shared. Products from any country can appear in either.

**Fields.** `product_name` is the product's main-language name; `product_name_hu` / `product_name_en`
exist when someone entered them (15 of 20 for "tej"). `lang` is the *product's* main language and cannot
be trusted for "is this Hungarian": "Milk 1,5%" (Alföldi Tej, sold in Hungary) is `lang: en`. `nutriments`
carries `energy-kcal_100g`, `energy-kj_100g`, `proteins_100g`, `carbohydrates_100g`, `fat_100g`;
`countries_tags` carries `en:hungary` etc.

**Survival under the D6 filter** (page_size 20, one request per term, 7 s apart):

| | terms | raw hits | usable | no kcal/protein | kJ only | no name | implausible |
|---|---|---|---|---|---|---|---|
| Hungarian, `langs=hu` | 20 | 280 | 205 (73 %) | 47 (17 %) | 22 (8 %) | 5 (2 %) | 1 |
| English, `langs=en` | 10 | 200 | 157 (78 %) | 30 (15 %) | 10 (5 %) | 1 | 2 |

- Hungarian terms: csirkemell, tej, kenyér, túró, paradicsom, sajt, tojás, rizs, burgonya, alma, banán,
  joghurt, kolbász, sonka, tészta, olaj, vaj, zabpehely, lazac, sütőtök. Fewest raw hits: tojás 3,
  burgonya 3, banán 6, zabpehely 6, lazac 7; **sütőtök 0** (and 0 in English too; "pumpkin" gives 20).
- English terms: snickers, coca cola, nutella, greek yogurt, oatmeal, peanut butter, whey protein, olive
  oil, almond milk, chicken breast — each at least 9 usable.
- kJ-only products are the single biggest *avoidable* loss (up to 5 of 20 for "sonka"); deriving kcal
  from kJ stays a Non-goal for v1.
- **Relevance, not coverage, is the weak side:** brand-field matches ("alma" → brand *Alma*, "joghurt" →
  brand *Joghurt*), foreign products with Hungarian-looking brands, products whose only name is another
  language. A Hungary country filter fixes most of it (D12).

**Hungary restriction (D12), re-measured the same day on the same 20 terms** with
`<term> countries_tags:"en:hungary"`, `langs=hu`: 263 raw hits (vs 280 without), **193 usable = 73 %**
(vs 205 = 73 %), **every hit tagged `en:hungary`**; empty terms: **tojás** (2 raw, 0 usable) and
**sütőtök** (0) — so 2 of 20 go to the English pass; the others keep 4–18 usable. The first two rows are
now plausible products for the term (`alma` → Meggy Szilva Alma, Alma-málna gyümölcspüré; `túró` → Túró
Rudi, félzsíros túró).

**Query syntax.** Lucene: field filters work in `q` (`categories_tags:"en:beverages" tej` → 4 hits);
malformed input (`tej:`, `"tej`, `a OR`) does not error, it just searches something else → D11.

**Latency / limits.** Every search-a-licious call: 200 in 0.2–1.2 s, no rate-limit headers in the response
(`nginx`, no `Retry-After`), none refused in ~50 requests at ~8/min. v1 `world.openfoodfacts.org/cgi/search.pl`
returned **503 on 4 of 5** calls at the same pace (the OFF docs say 503 is also what its global limit
returns) — rejected. Documented limits (OFF API page): 10 req/min/IP for search, 15 req/min/IP for product
reads, "don't use it for a search-as-you-type feature", "if your requests come from your users directly (ex:
mobile app), the rate limits apply per user" → D1 and D7. **Not tested on purpose:** exceeding the
search-a-licious limit (an IP ban would also take the barcode scanner down).

**Not answered by the spike (carry into the prompts):**
- the actual search-a-licious rate limit (undocumented) — watch for 429/503 in Prompt 1's tests against
  a stub and in the first real use, and tune `search-per-minute`;
- whether `langs=hu,en` in one call is worth anything (it returned a set that overlapped the Hungarian
  one on a single product); not used.

## Prompt 1 — Backend: OFF name-search client ✅ (2026-10-06)
- `OpenFoodFactsProperties`: add `searchBaseUrl`; `application.yml`: `search-base-url`,
  `search-per-minute` (default 8); `OpenFoodFactsConfig`: `openFoodFactsSearchRestClient` (connect 2 s, read 3 s).
- `OpenFoodFactsClient`: add `List<OffSearchHit> searchByName(String query, String lang, String countryTag, int limit)`
  (`countryTag` nullable; when set, the client appends ` countries_tags:"<tag>"` after the sanitised query);
  implement in `OpenFoodFactsClientImpl` with a new raw response record next to `OffApiResponse`
  (`@JsonIgnoreProperties(ignoreUnknown = true)`).
- The query sanitiser (D11) is a small pure function next to the client and unit-tested here.
- A transport failure is a typed exception (`OffUnavailableException`; `OffRateLimitedException` for 429 **and 503**, which is what OFF
  returns on its global limit), not an empty list — D4 depends on telling "nothing" from "failed".
Verification: `OpenFoodFactsClientImplTest` with a stub server (200 with hits, 200 empty, 429, 503, timeout) and the sanitiser cases from D11 (`tej:`, `"tej`, `a OR`, accents kept), and that the country clause is
appended verbatim and a query like `x countries_tags:"en:fr"` cannot replace it (the sanitiser removes the
colon and quotes). `OpenFoodFactsProperties` also gets `huCountryTag` (default `en:hungary`).
Mergeable alone: nothing calls it yet.

*As built:* `OpenFoodFactsClient.searchByName(query, lang, countryTag, limit)` returns `OffSearchHit`s
(code, `product_name`, the searched language's name, distinct brands, kcal/protein/carbs/fat);
`OffSearchQuery.sanitize` is the D11 sanitiser (lower-cases — which also defuses upper-case `OR`/`AND`/`NOT` —
keeps accents, drops everything but letters, digits, spaces, apostrophes and hyphens *inside* a word).
Failures: `OffRateLimitedException` (429, 503) and `OffUnavailableException` (any other error status, timeout,
connection failure, unreadable body) in `nutrition/openfoodfacts/exception/`. `OpenFoodFactsConfig` has the
second `RestClient` (`openFoodFactsSearchRestClient`, connect 2 s / read 3 s); `OpenFoodFactsProperties` gained
`searchBaseUrl`, `searchPerMinute` (8) and `huCountryTag` (`en:hungary`), env `OPENFOODFACTS_SEARCH_BASE_URL` /
`OPENFOODFACTS_SEARCH_PER_MINUTE`. Tests (27 new, none needs Docker): `OffSearchQueryTest` 8,
`OpenFoodFactsClientImplTest` 16 (mapping, brand de-duplication, hu/en name choice, request parameters
asserted *decoded* and checked to be percent-encoded, the country clause appended and not replaceable by typed
text, limit clamp, no call for an unsearchable query, empty vs. failed, 429/503/500/400, timeout, bad body),
`OpenFoodFactsConfigTest` 3 (binding from the real `application.yml`, two distinct beans, env override).
Not done here, by design: the `searchPerMinute` value is only bound — the limiter that reads it is Prompt 3.

## Prompt 2 — Backend: language-first search with English backoff and filtering ✅ (2026-10-06)
- `FoodNameSearchService` + `Impl` (package `nutrition/food/service/`): D4 flow, D6 filter as one
  package-private function, dedupe against `FoodRepository.findByUserIdAndBarcode`.
- DTOs in `nutrition/food/dto/`: `OffSearchResponse`, `OffSearchItem`, `OffSearchStatus`.
Verification: `FoodNameSearchServiceImplTest` — hu hit (client called once, **with** the Hungary tag, no
fallback); hu empty → en hit (second call **without** a country tag, `fellBackToEnglish`); hu timeout →
`UNAVAILABLE` **and the English client is never called**; en request makes one call, no country tag; each D6 rule has a test (including the name rule: `product_name_hu` wins over `product_name`); an owned
barcode is dropped. The Hungary restriction (D12, option B) is implemented here.

*As built:* `FoodNameSearchService.search(query, lang)` (`nutrition/food/service/`) returns an
`OffSearchResponse(status, language, fellBackToEnglish, items)` (`nutrition/food/dto/`: `OffSearchStatus` OK /
UNAVAILABLE / RATE_LIMITED, `OffSearchItem`). It is deliberately **not** `@Transactional` — the OFF calls take
seconds and must not hold a connection. Three decisions made while building, none changes the plan's behaviour:
- **"Usable" is judged before the ownership drop.** A Hungarian result whose every hit the user already owns is
  still a Hungarian result (OK, empty list, no English pass); only a result with nothing usable *by the D6 filter*
  falls back. Tested explicitly.
- **`fellBackToEnglish` is true only when the English pass actually returned items.** If both passes find nothing
  the answer is OK / empty / `language: "hu"` / `fellBackToEnglish: false`, so the client shows "no results", not
  "showing English results" over an empty list.
- **Ownership is one query, not one per hit:** new `FoodRepository.findOwnedBarcodes(userId, barcodes)` (live
  foods only — `deletedAt IS NULL`) instead of 20 × `findByUserIdAndBarcode`.

Tests: `FoodNameSearchServiceImplTest` 19 (the D4 flows incl. both errors never reaching the English client, the
D6 bounds at 900 kcal / 100 g on both sides, name rule, carbs/fat absent, de-duplication, ownership) — all green
without Docker. `FoodOwnedBarcodesRepositoryTest` (real Postgres: user scope, tombstone excluded) compiles but
**has not been run here — Docker was unavailable**; it runs in CI. A JPQL error in the new query would also show
at application start-up.

**Known gap, for Prompt 7:** a *tombstoned* food still holds its barcode in the `(user_id, barcode)` unique
index. An OFF hit for that product is shown (the ownership query ignores tombstones, on purpose — the user does
not see that food any more), but saving it will answer 409, and "re-fetch foods and use the existing one" finds
nothing. Prompt 7 must decide how to handle it (likely: let `POST /foods` revive a tombstoned food with the same
barcode instead of failing — a small backend change — or save without the barcode).

## Prompt 3 — Backend: cache and global limiter ✅ (2026-10-06)
- `OffSearchCache` (bounded LRU + TTL, key `lang|normalised query`), `OffSearchLimiter`; wired into the
  service. Normalise like the web (`normalizeForSearch`: trim, lowercase, accents folded).
Verification: unit tests — second identical call is a cache hit (stub client called once); different
`lang` is a miss; `UNAVAILABLE` is not cached; limiter over the limit answers `RATE_LIMITED` without a
client call; TTL expiry with an injected clock.

*As built:* `OffSearchCache` (bounded LRU, 500 entries, 10 min TTL, access order, `Clock` injected) and
`OffSearchLimiter` (sliding window of call times over the last 60 s, size `search-per-minute`) are package-private
components in `nutrition/food/service/`, used by `FoodNameSearchServiceImpl.searchPass`. Decisions made while building:
- **The cache sits at the pass, not around the whole response.** What is stored is the quality-filtered pass result
  *before* the user's own foods are dropped — the same for everyone — and ownership is applied afterwards for the
  caller. (A cache around the finished response would have served user A's "you already own this" filtering to
  user B; a test pins it.) Key: `<lang>|<sanitised text>`; the Hungary restriction follows the language, so it is
  implied.
- **The key keeps accents.** The plan said "accents folded like the web"; that is only safe if OFF itself treats
  "turo" and "túró" alike, which the spike did not check, so a folded key could serve the wrong answer. Revisit if
  the hit rate proves low.
- **An empty pass is cached** (a repeated "sütőtök" does not call OFF again); a failed call is not.
- **A cache hit takes no permit; a real call takes one; a Hungarian search that falls back takes two.** Over the cap
  the pass throws `OffRateLimitedException` and the service answers `RATE_LIMITED` without calling OFF. A cap of
  `0` (or less) allows nothing — usable as an off switch via `OPENFOODFACTS_SEARCH_PER_MINUTE=0`.
- An unsearchable text (nothing left after sanitising) returns empty before the cache and the limiter: no call,
  no permit, nothing cached.
- The service now hands OFF the **sanitised** text (the client sanitises again, which is idempotent), so the cache
  key and the request cannot disagree.

Tests (all without Docker): `OffSearchCacheTest` 8 (miss/hit, language in the key, empty is an answer, TTL
boundary to the millisecond, replacing an expired entry, LRU eviction, copy-in and read-only-out),
`OffSearchLimiterTest` 5 (limit then refusal, a refusal is not a call, the window slides at exactly 60 s, 0 and
negative allow nothing, **64 threads on a limit of 8 get exactly 8**), and 13 more cases in
`FoodNameSearchServiceImplTest` (now 32): second identical search served from cache, a fallback caches both
passes, per-user ownership on a cached result, TTL expiry, over the cap without an OFF call, hits take no permit,
fallback costs two, the cap frees after a minute, cap 0, unsearchable text costs nothing.

Not covered here: the Spring wiring of the two components (a context test needs Postgres, as every
`@SpringBootTest` here does). Both have a single `@Autowired` constructor and take the existing `Clock` bean
(`ClockConfig`); the first CI run of the integration tests is the check.

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
  the existing one instead of failing. **Also the tombstone case from Prompt 2's known gap.**
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
- A country setting: the Hungary restriction follows the language (D12); other countries, or a user choice
  of country, are a later change.
- A shared server-side product table; per-user OFF quotas.
- Languages other than `hu`/`en`.

## Edge cases
- Query shorter than 3 characters, only spaces, or punctuation → no request, no section.
- The user types fast: only the last debounced query is sent; a late response for an older query is
  ignored (`useQuery` key / controller token).
- Same product returned twice (two OFF records with one barcode) → deduplicate by barcode in the service.
- A product the user already owns → dropped from OFF results (D6), it is in the own list.
- Product in `fellBackToEnglish` mode: the name is whatever OFF stores for it (usually English); the
  section note says the search ran in English, and the saved food keeps that name (the user can rename it).
- Beverages: OFF values are per 100 **ml** and we store per 100 g, so the "grams" of a drink are ml.
  Accepted for v1 (the barcode flow does the same today); the row does not say "ml".
- Typed Hungarian term in the English backoff finds nothing (spike: "sütőtök" → 0 hits both ways); the
  section then shows the "no results" line, not an error. The backoff pays off for brand and English
  product names ("pumpkin", "snickers").
- The user changes language in Settings with the dialog closed → next open uses the new language;
  cached results are keyed by language (D7).
- 429 / timeout → status note; own results unaffected; no automatic retry loop.
- Offline on mobile → checkbox disabled; own offline search unchanged.
- Hungarian-language user abroad: the Hungarian pass still shows only Hungarian products; the English pass
  (no restriction) is the way out, and so is the checkbox.
- A Hungarian term that has products only outside Hungary (tojás: 2 raw, 0 usable inside Hungary) goes to
  the English pass, where the Hungarian word usually finds nothing → "no results" line; the user then
  uses own foods, the barcode scanner or the macro entry.
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
- **The country clause silently missing or editable:** if it were dropped, Hungarian users would see the
  brand/foreign noise again with no error; if a user could alter it they could search other countries.
  Tests: it is present on the first `hu` call, absent on the English call and for `en`, and cannot be
  replaced by typed text (D11).
- **Relevance noise mistaken for coverage:** a list full of brand-matched, foreign products looks like "it works" in a
  coverage count. The manual walk must read the first five rows per term, not count hits (D12).
- **Debounce missing on one client:** a keystroke-per-request client would burn the shared limit in
  minutes. Both clients have a debounce test.
