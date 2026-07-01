# 14 – Pagination / lazy loading plan

Status: proposed
Author: planning doc (implement in phases)
Scope: Foods tab first, then every long list (meals, recipes, exercises, sessions, …)

## 1. Problem

Lists grow unbounded over time (foods catalog, meals history, workout sessions, …).
Today every list:

1. **Loads the whole table into memory.** The controller is a `StreamNotifier`
   wrapping `repository.watchAll()`, which runs `SELECT * FROM foods ORDER BY name`
   with **no LIMIT** and maps *every* row to a domain object on *every* change
   (`food_repository.dart:19`, `food_controller.dart:13`). `ListView.builder`
   only builds visible tiles, but the full `List<Food>` is still materialized and
   re-mapped on each DB write.
2. **Pulls the whole table over the network.** `PullEngine._pullFoods` does
   `GET /foods` which returns **all** rows (`FoodController.findAll`), then
   `_deleteMissing` reconciles the full set (`pull_engine.dart:59`). With 10k+
   foods this is a multi-MB response on every `pullAll()`.

So "show 30–50, then load more" actually splits into **two independent problems**:

| Layer | Symptom at scale | Fix |
|-------|------------------|-----|
| UI / local DB | Big in-memory list, slow re-map on every write | **Phase 1** – page the local query |
| Network / sync | Multi-MB full-table pull on every refresh | **Phase 2 + 3** – pageable endpoints + delta sync |

> Important: the UI reads the **local DB**, not the server. "Infinite scroll that
> calls the backend" is *not* how this app works — the list scrolls over locally
> cached rows. The backend pagination (Phase 2/3) is about making the *sync pull*
> cheap, not about feeding the scroll.

## 2. Architecture decision

- **Phase 1 (UI pagination over the local cache)** is the primary, low-risk
  deliverable and exactly matches the request: list 30–50, scroll to the bottom
  to trigger the next page. Self-contained per feature, no backend or sync
  changes, fully offline-compatible.
- **Phase 2 (pageable + searchable backend endpoint)** makes the API able to
  serve pages, and now has two real consumers: the mobile sync pull *and* the
  web `FoodsView` table, which today fetches the whole catalog and filters
  client-side — the same unbounded-response problem this phase exists to fix.
  Keep it backward compatible so nothing breaks while callers migrate.
- **Phase 3 (incremental / delta sync)** is mobile-only and the real long-term
  scalability fix for the sync pull: only pull rows changed since the last sync
  (`updatedSince` cursor + soft-delete tombstones), so the pull cost is
  proportional to *changes*, not table size. Web has no local cache to keep
  converged, so it stays on Phase 2's plain pagination indefinitely.

Ship Phase 1 first — it delivers the visible UX. Phase 2 should follow fairly
soon after, since the web table is unbounded today; Phase 3 is a separate,
larger track that can land later once the catalog is actually large enough to
justify the sync-contract change.

Recommended page size: **40** (inside the 30–50 band), tunable via one constant.

---

## Phase 1 — UI pagination over the local cache (Foods first)

### Goal
The Foods tab shows the first 40 foods, and loading more (next 40) happens when
the user scrolls near the bottom. Search/sort still work; offline still works.

### Design
Keep the offline-first watch-stream model but make the query bounded:

- Repository gains `watchPaged({required int limit})` (or `watchPage(int page)`)
  that applies `..limit(limit)` to the Drift query. Drift re-emits when the table
  changes, so optimistic create/edit/delete still update the visible page live.
- Controller holds the current page size in state; "load more" grows the limit
  by `pageSize` and the stream re-emits the larger window. A growing-`LIMIT`
  (windowed) approach is simplest and keeps a single live stream; a true
  keyset/offset multi-stream approach is more complex and not needed for a local
  SQLite read.
- Track `hasMore` by requesting `limit + 1` and trimming, or by comparing the
  returned count to the requested limit.
- Presentation: `ListView` with a trailing loader item; a `ScrollController` (or
  `NotificationListener<ScrollEndNotification>`) calls `loadMore()` when near the
  end. Reset to the first page on pull-to-refresh and when a search query changes.

### Files
- `mobile/lib/features/nutrition/data/food_repository.dart` — add paged watch.
- `mobile/lib/features/nutrition/application/food_controller.dart` — page-size
  state + `loadMore()`.
- `mobile/lib/features/nutrition/presentation/foods_tab.dart` — scroll trigger +
  footer loader.

### Acceptance
- Cold open shows 40 items; scrolling appends 40 at a time until exhausted.
- Create/edit/delete still reflect immediately in the visible window.
- Works fully offline; pull-to-refresh resets to page 1.
- No change to backend or sync.

### Prompt 1.1 — paged repository + controller (Foods)
```
Read mobile/lib/features/nutrition/data/food_repository.dart,
mobile/lib/features/nutrition/application/food_controller.dart, and
mobile/lib/features/nutrition/presentation/foods_tab.dart.

Add UI-level pagination to the Foods tab that reads from the local Drift cache
(do NOT call the backend for paging — the list reads the local DB).

Repository: add a method that watches foods ordered by name but bounded by a
limit, e.g. `Stream<List<Food>> watchPaged({required int limit})`, applying
`..limit(limit)` to the existing query. Keep the pending-delete filtering from
watchAll. Keep watchAll if other callers use it.

Controller (FoodController): introduce a page size constant of 40. Keep a current
limit in the notifier, starting at 40. build() should watch watchPaged with the
current limit. Add `loadMore()` that increases the limit by the page size and
re-subscribes so the stream re-emits the larger window. Expose whether more rows
may exist (request limit+1 and trim, or compare returned count to the limit).
Reset the limit back to 40 in refresh().

Keep the offline-first model intact: optimistic create/edit/delete must still
update the visible window live. Follow the existing four-layer conventions and
run `dart run build_runner build` if any @riverpod-annotated provider changed.
```

### Prompt 1.2 — infinite-scroll UI (Foods)
```
Read mobile/lib/features/nutrition/presentation/foods_tab.dart and the updated
food_controller.dart.

Wire the Foods ListView to trigger loadMore() when the user scrolls near the
bottom (within ~300px of the end), using a ScrollController or a
NotificationListener<ScrollNotification>. Show a small loading footer item while
more rows may exist, and stop showing it once the list is exhausted. Make sure
pull-to-refresh resets back to the first page. Keep Dismissible swipe-to-delete
and tap-to-edit working. Don't fetch from the network here — paging is purely
over the local cache.
```

### Prompt 1.3 — roll out to the other long lists
```
Apply the same local-cache pagination pattern (page size 40, growing-limit
watch + scroll-triggered loadMore + footer loader, reset on refresh) used for the
Foods tab to these tabs, one at a time, reading only each feature's
data/application/presentation files:
- mobile/lib/features/nutrition/presentation/meals_tab.dart
- mobile/lib/features/recipes/presentation/recipes_tab.dart
- mobile/lib/features/workouts/presentation/exercises_tab.dart
- mobile/lib/features/workouts/presentation/sessions_tab.dart
For each, mirror the repository watchPaged + controller loadMore changes. Keep
each feature's existing ordering (e.g. meals/sessions likely by date desc).
```

---

## Phase 1 status (as of this revision)

Foods and Meals have already shipped Phase 1 on mobile:
`FoodRepository.watchPaged`/`FoodController.loadMore` (`mobile/lib/features/nutrition/data/food_repository.dart`,
`mobile/lib/features/nutrition/application/food_controller.dart`) windowed-scroll the
Foods tab, and the same pattern is live for Meals. Recipes/Exercises/Sessions
(Phase 1.3) are still open.

Critically, Phase 1 also already added `foodSearchProvider`
(`food_controller.dart`), a **second, unbounded** stream over
`FoodRepository.watchAll()` used only by the meal-entry autocomplete
(`mobile/lib/features/nutrition/presentation/widgets/add_meal_entry_sheet.dart`).
It deliberately bypasses the paginated window so a user can find *any* food by
name while logging a meal, regardless of how far they've scrolled the Foods tab.
This is a hard constraint on everything below: **whatever Phase 2/3 do to the
sync pull, the local mobile foods table must still end up a complete, current
mirror of the server catalog** — paging/delta only change how it gets there, not
what it contains. Breaking that silently breaks food autocomplete.

A web frontend has also since shipped (`web/src/features/nutrition/components/FoodsView.tsx`).
It currently calls `foodApi.list()` → `GET /api/v1/foods` for the **entire**
table and does search/pagination client-side (`DataTable`'s built-in
25-rows-per-page slicing, plus a client-side `.filter()` by name). This is the
exact same unbounded-response problem Phase 2 was designed to fix — so Phase 2
now has two consumers to serve, not one, and that reshapes its design below.

---

## Phase 2 — Pageable + searchable backend endpoint (serves web *and* the mobile sync pull)

### Goal
One backend capability, two consumers, different needs:

| Consumer | Needs | Page size |
|---|---|---|
| Mobile sync pull (`PullEngine._pullFoods`) | ALL rows, no search, just chunked so no single response is huge | ~200–500 |
| Web `FoodsView` | True server-side pagination **and** server-side search — it must stop fetching the whole table up front | ~25–50 (matches `DataTable`'s current page size) |

Both are satisfied by the same paged+searchable endpoint; only the query params
differ. Backward compatible: today's unpaged callers keep working unchanged.

### Design
- **Same path, param-switched handlers** — avoids inventing a second URL for what
  is conceptually the same resource, and Spring supports this cleanly via
  `@GetMapping` `params` matching on `FoodController`:
  - `@GetMapping(params = "!page")` — today's behavior, byte-for-byte: returns
    `List<FoodResponse>`, unpaged, full catalog. This is the backward-compat
    story — no query params means nothing changed.
  - `@GetMapping(params = "page")` — new: takes a Spring Data `Pageable`
    (`page`, `size`, `sort`) plus an optional `search` param (case-insensitive
    `name` contains-match). Returns `Page<FoodResponse>` directly — Spring Boot
    serializes `Page<T>` to `{ content, totalElements, totalPages, number,
    size, last, ... }` with no hand-rolled envelope needed.
- `@PageableDefault(size = 200, sort = {"name", "id"})` on the paged handler —
  `id` is the tiebreaker required for deterministic paging (unchanged from the
  original plan). Web overrides `size` down to its own page size per request.
- Repository: add
  `Page<Food> findByHiddenFalse(Pageable pageable)` and
  `Page<Food> findByHiddenFalseAndNameContainingIgnoreCase(String search, Pageable pageable)`;
  the service picks the search variant only when `search` is non-blank. Reuses
  the existing "hidden foods never appear in pickers/catalog" rule
  (`FoodServiceImpl.findAll`) for both.
- Deterministic ordering (`name, id`) applies to both variants; never rely on
  insertion order.

### Web pagination/search — decision to make explicit
`DataTable` currently sorts and paginates whatever `rows` array it's handed,
client-side. Once `FoodsView` only holds one server page at a time (25–50 rows),
that breaks for two reasons: (1) client search would only search the current
page, and (2) client column-sort would only sort the current page. Resolve both
by making search and sort server-driven for Foods specifically:
- The search box drives the `search` query param (debounce ~300ms so it isn't
  refetching on every keystroke).
- Column-sort clicks map to the `sort` param passed to `Pageable` instead of
  local `Array.sort`.
- Give `DataTable` an optional controlled-pagination/controlled-sort mode (page,
  totalPages, onPageChange, sortKey, sortDir, onSortChange) that, when present,
  skips its internal slicing/sorting and just renders the rows it's given.
  Every other table (recipes, exercises, workout templates/sessions) keeps using
  today's client-side mode unchanged — those catalogs are expected to stay small
  and don't need this.

> Note: page size for the **sync pull** (200–500) is unrelated to the **UI** page
> size, which is unrelated again to the web table's page size (25–50). All three
> just set different `size` values against the same endpoint.

### Files
- `backend/.../food/FoodController.java`, `FoodService.java`, `FoodServiceImpl.java`, `FoodRepository.java`.
- `docs/05-backend-api.md` (document the contract).
- Tests: `FoodControllerTest`, `FoodServiceImplTest`.
- `web/src/features/nutrition/api.ts`, `web/src/lib/api/queryKeys.ts`,
  `web/src/features/nutrition/components/FoodsView.tsx`, `web/src/components/data/DataTable.tsx`.
- `mobile/lib/core/sync/pull_engine.dart`.

### Prompt 2.1 — pageable + searchable endpoint (Foods) — backend
```
Read backend/src/main/java/com/lifey/nutrition/food/FoodController.java,
FoodService.java, FoodServiceImpl.java, FoodMapper.java, FoodRepository.java and
the existing controller test FoodControllerTest.java.

Add a second GET /api/v1/foods handler, split from the existing one by Spring's
params matching so both can coexist on the same path:
- @GetMapping(params = "!page") — today's findAll(), completely unchanged
  (List<FoodResponse>, unpaged, backward compatible for any existing caller).
- @GetMapping(params = "page") — new handler taking a Pageable (page, size,
  sort) plus an optional `search` request param (case-insensitive name
  contains-match), defaulted via @PageableDefault(size = 200, sort = {"name",
  "id"}). Returns Page<FoodResponse> as-is (let Spring Boot serialize Page<T>
  natively — content/totalElements/totalPages/number/size/last — do not hand-rig
  a custom envelope).

Add repository methods Page<Food> findByHiddenFalse(Pageable pageable) and
Page<Food> findByHiddenFalseAndNameContainingIgnoreCase(String search, Pageable
pageable). Add matching service interface + impl methods (search variant used
only when `search` is non-blank), mapping rows through the existing FoodMapper.
Keep the "hidden foods excluded from catalog listings" rule consistent with
findAll(). Update docs/05-backend-api.md documenting both the unpaged and paged
contract (query params, response shape, and that `page` presence is the switch).
Add/extend tests: first page, last page, search hit/miss, and the no-params
backward-compat case returning the full unpaged list. Use Java 24, constructor
injection, Maven; do not add new frameworks.
```

### Prompt 2.2 — migrate web Foods table to server pagination + search
```
Read web/src/features/nutrition/components/FoodsView.tsx,
web/src/features/nutrition/api.ts, web/src/lib/api/queryKeys.ts, and
web/src/components/data/DataTable.tsx. Backend now exposes
GET /api/v1/foods?page=&size=&search=&sort= returning a Spring Page<FoodResponse>
(see docs/05-backend-api.md) — read that section for the exact response shape.

Replace FoodsView's foodApi.list() + client-side name filter with a paginated,
server-searched query: add foodApi.page({ page, size, search, sort }) to api.ts,
a queryKeys.foods.page(params) key, and drive page/search/sort as component
state, debouncing the search input (~300ms) before it hits the query key so
typing doesn't refetch on every keystroke. Reset to page 0 whenever the search
term or sort changes.

Extend DataTable with an optional controlled-pagination/controlled-sort mode
(current page, total pages, onPageChange, sortKey, sortDir, onSortChange) that,
when provided, renders exactly the rows passed in and delegates paging/sorting
to the caller instead of doing its own client-side slicing/sorting — but do NOT
change its default (uncontrolled) behavior, since recipes/exercises/workout
tables still rely on it staying client-side. Wire FoodsView's table into the new
controlled mode. Keep the barcode-lookup flow, editor panel, and empty/error
states working as they are today.
```

### Prompt 2.3 — paged sync pull (mobile)
```
Read mobile/lib/core/sync/pull_engine.dart and
mobile/lib/features/nutrition/application/food_controller.dart (specifically
foodSearchProvider and FoodRepository.watchAll — do not touch these, just
understand why they exist: unbounded local search for meal-entry autocomplete).

Migrate _pullFoods to consume the paged foods endpoint: loop GET
/foods?page=N&size=200 (no `search` — the pull always wants everything)
accumulating all pages until `last` is true, building the same `seen` set across
all pages before calling _deleteMissing('foods', seen). The reconciliation
semantics must stay identical to today, and the local `foods` table must still
end up containing every non-hidden server row after the pull completes — paging
only chunks the transfer, it must not leave the local cache partial. (This
matters concretely: foodSearchProvider's autocomplete depends on the local table
being complete, not just the currently-scrolled window.) Add a small shared
helper to fetch all pages of a paged endpoint so other _pull* methods can reuse
it later. Do not change the pending-operation skip logic.
```

---

## Phase 3 — Incremental / delta sync (mobile-only; the real scalability fix)

### Goal
Stop re-pulling the entire table on every mobile sync. Pull only rows changed
since the last successful sync. This is what actually keeps cost flat as the
catalog grows; Phase 2 alone still transfers everything (just in chunks).

**This track is mobile-only.** The web app isn't offline-first and holds no
persisted local mirror — every `FoodsView` page load just re-queries the Phase 2
paged+searchable endpoint on demand, so plain pagination is a complete,
permanent solution for web. A delta/cursor mechanism buys web nothing (there's
no local cache to keep converged) and should not be built for it. Delta sync
exists purely to shrink `PullEngine.pullAll()`'s cost on mobile.

### Design (larger, separate track)
- Backend: every syncable entity exposes `updatedAt` (already on `BaseEntity`?
  verify) and supports `GET /foods?updatedSince=<ISO timestamp>` returning only
  rows changed/created after that instant, ordered by `updatedAt, id`.
- Soft deletes: a hard-deleted row currently vanishes, so a delta pull can't tell
  the client to delete it. Introduce tombstones — a `deletedAt` column (or a
  `deletions` feed) so `updatedSince` can report removals. This replaces the
  `_deleteMissing` full-scan, which is incompatible with delta sync (it requires
  fetching the full table to diff against, which is exactly what delta sync
  stops doing).
- Mobile: persist a per-entity `lastSyncedAt` cursor; pass it as `updatedSince`;
  apply upserts for returned rows and deletes for returned tombstones; advance
  the cursor to the newest `updatedAt` seen.
- Decide cursor safety (use server clock, handle equal timestamps via `>=` plus
  id, overlap window to avoid missing concurrent writes).
- **Local-cache completeness invariant carries over from Phase 2**: the first
  sync for a device must still be a full pull (delta sync only kicks in once a
  `lastSyncedAt` cursor exists), and every delta applied afterward must keep the
  local `foods` table converged with the server, deletions included. Add an
  explicit acceptance check for this: after any delta pull, meal-entry
  autocomplete (`add_meal_entry_sheet.dart`'s `foodSearchProvider`) must still
  surface every non-hidden food that exists server-side, including ones created
  long before the device's most recent sync — not just recently-changed rows.

> This is a meaningful change to the sync contract and the `_deleteMissing`
> reconciliation model — scope it as its own design doc + migration before
> implementing. Flag explicitly: it requires a Flyway migration (tombstone
> column/index) and a coordinated backend+mobile rollout.

### Prompt 3.1 — design spike
```
Produce a design doc (docs/15-delta-sync.md) for incremental sync of the nutrition
foods entity as a pilot. Cover: the updatedSince query contract and response
ordering; the tombstone/soft-delete strategy to propagate deletions (Flyway
migration sketch); the mobile per-entity lastSyncedAt cursor, how a device with
no cursor yet still does a full initial pull, and how the cursor mechanism
replaces PullEngine._deleteMissing; clock-skew / equal-timestamp /
concurrent-write edge cases; an explicit acceptance criterion that the local
foods table (and therefore foodSearchProvider's meal-entry autocomplete, see
food_controller.dart) stays a complete mirror of the server catalog after every
delta pull, not just a window of recent changes; and a backward-compatible
rollout sequence (backend first, then mobile). Note explicitly that this track
is mobile-only — the web frontend has no local cache and stays on Phase 2's
plain pagination indefinitely. Do not write implementation code yet — this is
the design and migration plan.
```

---

## 3. Suggested order of work

1. **Phase 1.1 + 1.2** — Foods tab pagination — **done**.
2. **Phase 1.3** — roll out to recipes / exercises / sessions (meals already
   done alongside foods).
3. **Phase 2.1** — pageable + searchable `/foods` endpoint (backend).
4. **Phase 2.2** — migrate web `FoodsView` to server pagination + search — do
   this promptly once 2.1 ships, since the web table is the one actively
   fetching the full catalog on every load today.
5. **Phase 2.3** — paged mobile sync pull (once payload size is a real problem;
   less urgent than 2.2 since the pull already works, just not cheaply).
6. **Phase 3** — delta sync design spike, then implement for mobile only.

Phase 1 is independently shippable and reversible. Don't start Phase 3 until
Phase 2 is in place and the catalog is actually large enough to justify the sync
contract change.
