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
- **Phase 2 (pageable backend endpoints)** makes the API able to serve pages.
  Keep it backward compatible so nothing breaks while the pull is migrated.
- **Phase 3 (incremental / delta sync)** is the real long-term scalability fix:
  only pull rows changed since the last sync (`updatedSince` cursor + soft-delete
  tombstones), so the pull cost is proportional to *changes*, not table size.

Ship Phase 1 first — it delivers the visible UX. Phases 2–3 are a separate track
that can land later when the catalog actually gets large.

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

## Phase 2 — Pageable backend list endpoints (sync payload)

### Goal
Backend list endpoints can return pages so the sync pull no longer transfers the
whole table in one response. Backward compatible: existing non-paged callers keep
working until the pull is migrated.

### Design
- Use Spring Data `Pageable`. Add an overload/variant: `GET /api/v1/foods?page=0&size=200`
  returning a page envelope `{ "content": [...], "page": 0, "size": 200, "totalElements": N, "last": bool }`.
- Keep the existing `GET /api/v1/foods` (no params) returning the full list for
  backward compatibility, OR make the no-param call default to page 0 with a large
  size. Decide explicitly and document it in `docs/05-backend-api.md`.
- `FoodRepository` already extends `JpaRepository`, so `findAll(Pageable)` exists;
  add a service method `Page<FoodResponse> findAll(Pageable)` and map via the
  existing `FoodMapper`.
- Deterministic ordering is required for stable paging — order by `name, id` (or
  `id`) explicitly; never rely on insertion order.

> Note: page size for the **sync pull** (e.g. 200–500) is unrelated to the UI page
> size (40). The pull pages purely to cap response size / avoid timeouts.

### Files
- `backend/.../food/FoodController.java`, `FoodService.java`, `FoodServiceImpl.java`.
- `docs/05-backend-api.md` (document the contract).
- Tests: `FoodControllerTest`, `FoodServiceImplTest`.

### Prompt 2.1 — pageable endpoint (Foods)
```
Read backend/src/main/java/com/lifey/nutrition/food/FoodController.java,
FoodService.java, FoodServiceImpl.java, FoodMapper.java, FoodRepository.java and
the existing controller test FoodControllerTest.java.

Add Spring Data Pageable support to the foods list endpoint without breaking the
current contract. Add a service method `Page<FoodResponse> findAll(Pageable
pageable)` backed by `foodRepository.findAll(pageable)` mapped with FoodMapper,
with deterministic ordering by name then id. Expose it on GET /api/v1/foods using
@PageableDefault(size = 200) and a stable sort, returning the page content plus
pagination metadata (page, size, totalElements, last). Keep backward
compatibility: a request with no page/size params must still return all foods in
a single response (either keep the existing List endpoint or default size large
enough) — pick one approach, implement it, and note the decision in a comment.
Add a Service interface method + Impl per project conventions. Update
docs/05-backend-api.md with the new query params and response shape. Add/extend
tests covering the first page, the last page, and the no-params backward-compat
case. Use Java 24, constructor injection, Maven; do not add new frameworks.
```

### Prompt 2.2 — paged sync pull (mobile)
```
Read mobile/lib/core/sync/pull_engine.dart.

Migrate _pullFoods to consume the paged foods endpoint: loop GET
/foods?page=N&size=200 accumulating all pages until `last` is true, building the
same `seen` set across all pages before calling _deleteMissing('foods', seen).
The reconciliation semantics must stay identical to today (full set is still
materialized locally for offline use — paging only chunks the transfer). Add a
small shared helper to fetch all pages of a paged endpoint so other _pull*
methods can reuse it. Do not change the pending-operation skip logic.
```

---

## Phase 3 — Incremental / delta sync (the real scalability fix)

### Goal
Stop re-pulling the entire table on every sync. Pull only rows changed since the
last successful sync. This is what actually keeps cost flat as the catalog grows;
Phase 2 alone still transfers everything (just in chunks).

### Design (larger, separate track)
- Backend: every syncable entity exposes `updatedAt` (already on `BaseEntity`?
  verify) and supports `GET /foods?updatedSince=<ISO timestamp>` returning only
  rows changed/created after that instant, ordered by `updatedAt, id`.
- Soft deletes: a hard-deleted row currently vanishes, so a delta pull can't tell
  the client to delete it. Introduce tombstones — a `deletedAt` column (or a
  `deletions` feed) so `updatedSince` can report removals. This replaces the
  `_deleteMissing` full-scan, which is incompatible with delta sync.
- Mobile: persist a per-entity `lastSyncedAt` cursor; pass it as `updatedSince`;
  apply upserts for returned rows and deletes for returned tombstones; advance the
  cursor to the newest `updatedAt` seen.
- Decide cursor safety (use server clock, handle equal timestamps via `>=` plus
  id, overlap window to avoid missing concurrent writes).

> This is a meaningful change to the sync contract and the `_deleteMissing`
> reconciliation model — scope it as its own design doc + migration before
> implementing. Flag explicitly: it requires a Flyway migration (tombstone
> column/index) and a coordinated backend+mobile rollout.

### Prompt 3.1 — design spike
```
Produce a design doc (docs/15-delta-sync.md) for incremental sync of the nutrition
foods entity as a pilot. Cover: the updatedSince query contract and response
ordering; the tombstone/soft-delete strategy to propagate deletions (Flyway
migration sketch); the mobile per-entity lastSyncedAt cursor and how it replaces
PullEngine._deleteMissing; clock-skew / equal-timestamp / concurrent-write edge
cases; and a backward-compatible rollout sequence (backend first, then mobile).
Do not write implementation code yet — this is the design and migration plan.
```

---

## 3. Suggested order of work

1. **Phase 1.1 + 1.2** — Foods tab pagination (visible win, ship first).
2. **Phase 1.3** — roll out to meals / recipes / exercises / sessions.
3. **Phase 2.1 + 2.2** — pageable foods endpoint + paged pull (when payload size
   becomes a real problem).
4. **Phase 3** — delta sync design spike, then implement per entity.

Phase 1 is independently shippable and reversible. Don't start Phase 3 until
Phase 2 is in place and the catalog is actually large enough to justify the sync
contract change.
```
