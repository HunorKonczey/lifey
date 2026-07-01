# 15 – Delta (incremental) sync design spike

Status: design only — no implementation in this doc (per
[docs/14-pagination-plan.md](14-pagination-plan.md) Phase 3 / Prompt 3.1).

## 0. Scope

**Pilot: the nutrition `foods` entity only.** The mechanism below (an
`updated_at`/`deleted_at` pair + a DB trigger + an `updatedSince` query param +
a mobile per-entity cursor) is meant to be a repeatable recipe — once Foods is
proven out in production, the same four pieces get added to the next entity,
one at a time. This doc does not implement or schedule that rollout; it only
designs and validates the pattern against Foods.

**Mobile-only.** The web app has no persisted local cache — `FoodsView`
re-queries the Phase 2 paged+searchable endpoint on every page load, so plain
pagination is already a complete, permanent solution for it. Delta sync exists
purely to shrink `PullEngine.pullAll()`'s transfer cost on mobile, which today
re-fetches the entire catalog (Phase 2 chunked that transfer; it didn't reduce
it). Nothing here changes the web contract from Phase 2.

## 1. The `updatedSince` query contract

Adds one more **optional** parameter to the existing paged+searchable handler
introduced in Phase 2 (`GET /api/v1/foods` with a `page` param) — not a new
endpoint or path:

```
GET /api/v1/foods?page=0&size=200&updatedSince=2026-07-01T10:15:30Z
```

- `updatedSince` (ISO-8601 instant, optional). When present, the handler
  switches its underlying query from `findByHiddenFalse(...)` /
  `findByHiddenFalseAndNameContainingIgnoreCase(...)` to a **new**,
  visibility-unaware query: `findByUpdatedAtGreaterThanEqual(since, pageable)`.
  This must *not* filter on `hidden` — the delta feed is a change-log, not a
  catalog view, and it needs to surface tombstoned rows (which have
  `hidden = true`, see §2) as well as any future edit to an already-hidden
  shadow food (a quick-macro meal entry's private `Food` row).
- Response reuses the existing `Page<FoodResponse>` envelope from Phase 2,
  with one additive field: `FoodResponse.deletedAt` (nullable `Instant`,
  always `null` except for tombstoned rows). Every existing consumer
  (web, current mobile parsing) already ignores unknown/absent fields, so this
  is backward compatible.
- **Ordering: `updated_at ASC, id ASC`**, always — ascending, not descending.
  The client processes pages in order and derives its next cursor from the
  *last* row of the *last* page, which is only guaranteed to be the newest
  timestamp in the result set if the whole set is ascending. (Phase 2's own
  paged browsing endpoints are unaffected — they keep `name, id` ordering;
  `updatedSince` implies switching the `Sort` used for that request only.)
- `search` and `updatedSince` are independent, optional, and technically
  composable (nothing stops passing both), but in practice only one consumer
  uses each: web drives `search`, the mobile pull drives `updatedSince`.
- The response envelope also needs one addition beyond `Page<FoodResponse>`:
  a top-level `serverTime` (the DB's `now()` at query time), needed to seed a
  brand-new device's cursor when the very first delta-capable pull returns
  zero rows (§4, edge case d).

## 2. Soft-delete → tombstones

Today, `FoodServiceImpl.delete()` sets `hidden = true` (see the existing
doc-comment on that method) — but `hidden` is dual-purpose: it also marks
quick-macro shadow foods that were **never deleted**, just never meant to
appear in catalog pickers. Reusing `hidden` as the delta-sync deletion signal
would conflate those two cases, so this introduces a **new, single-purpose**
column instead:

```sql
-- V27__food_delta_sync.sql (illustrative — do not apply yet)

ALTER TABLE foods
    ADD COLUMN updated_at timestamptz NOT NULL DEFAULT now(),
    ADD COLUMN deleted_at timestamptz;

-- updated_at must be correct even for writes that don't go through the
-- application layer (data fixes, future batch jobs) — a DB trigger is more
-- robust here than relying on every code path remembering to touch a
-- @PreUpdate-annotated field.
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER foods_set_updated_at
  BEFORE UPDATE ON foods
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Composite so the delta query's WHERE + ORDER BY is index-backed.
CREATE INDEX idx_foods_updated_at ON foods (updated_at, id);
```

- `FoodServiceImpl.delete()` gains one line: set `deletedAt = Instant.now()`
  alongside the existing `hidden = true`. The trigger then bumps `updated_at`
  for that same row automatically — the delete shows up in the next
  `updatedSince` pull with no special-casing in the query itself, it's just
  another changed row that happens to carry a non-null `deletedAt`.
- Tombstones are **never hard-deleted** — a client that hasn't synced in a
  long time must still be able to see the deletion whenever it does resync.
  Retention/cleanup of very old tombstones is out of scope for the pilot;
  flag it as a future concern once there's real usage data on how stale a
  client is ever allowed to get.

## 3. Mobile: per-entity cursor, replacing `_deleteMissing` for the delta path

New local state: a `sync_cursors` Drift table, one row per entity —
`entity_type TEXT PRIMARY KEY, last_synced_at TEXT` (ISO instant) — mirroring
the existing singleton-row pattern already used for `userSettingsTable`.

`PullEngine._pullFoods` gains **two branches**, selected by whether a cursor
exists yet for `'foods'`:

- **No cursor (first sync ever, or first sync since this device installed the
  delta-sync-capable app build):** unchanged from Phase 2.3 — loop
  `GET /foods?page=N&size=200` (no `updatedSince`) via the existing
  `_getAllPages` helper, upsert everything returned, then call
  `_deleteMissing('foods', seen, additionalWhere: 'AND hidden = false')`
  exactly as today. This is still correct for a full pull specifically because
  the *paged, non-delta* endpoint still excludes hidden rows the same way it
  always has — `_deleteMissing`'s existing hidden-aware full-scan diff is only
  ever run against that same excluded-hidden result set, so nothing about it
  needs to change. After this pull succeeds, seed the cursor: take the max
  `updatedAt` across all rows returned (see §4 for why not "now"); if the
  catalog was empty, seed from the paged response's `serverTime` field instead.
- **Cursor present (every sync after the first):** loop
  `GET /foods?page=N&size=200&updatedSince=<cursor>`, again via
  `_getAllPages` (or a small variant of it that also threads `updatedSince`
  through). For each row: if `deletedAt != null`, delete the local row
  (same pending-operation skip guard as every other write-reconciliation path
  today); otherwise upsert, identical to the existing per-row logic. **Do not
  call `_deleteMissing` on this path at all** — deletions are now explicit,
  per-row, carried by the feed itself, which is exactly what makes this
  path cheap: cost is proportional to *changes*, not to the full table size.
  Advance the cursor to the max `updatedAt` seen in this pull (minus the
  overlap window, §4); if zero rows came back, leave the cursor untouched.

## 4. Clock-skew / equal-timestamp / concurrent-write edge cases

**(a) Never derive the cursor from the client's wall clock.** If the mobile
device's clock runs ahead of the server's, and it sets its next cursor to its
own "now" after a successful pull, a row that commits on the server with a
timestamp before the client's inflated "now" — but after the client's actual
last real sync — would be silently skipped forever. The cursor must always be
derived from `updated_at` values *actually returned in the response*, never
from the client's clock.

**(b) The tied-timestamp problem.** If the query is a strict
`updated_at > cursor`, and a second row commits with the *exact same*
timestamp as the row that became the cursor (plausible if multiple rows are
touched in one transaction, or two requests land in the same clock tick), a
strict `>` will skip it forever — real, silent data loss at the boundary.
Mitigating this rigorously requires a **compound cursor** (`(timestamp, id)`
pair, querying `WHERE (updated_at, id) > (:cursorTime, :cursorId)`), which
adds persistence and comparison complexity. For the pilot, prefer the simpler
mitigation in (c) below (an overlap window) over a compound cursor — it
already covers this case in practice, since a re-pulled boundary row is just a
harmless idempotent re-upsert, not a duplicate or a conflict. Revisit a
compound cursor only if the overlap window ever proves insufficient.

**(c) Read-time visibility skew (the subtler, real risk).** Two concurrent
writes can commit out of timestamp order from a reader's point of view: a
transaction that *started* earlier (and will eventually get an earlier
`updated_at` via `now()` at commit time under Postgres' read-committed
semantics) can still *commit and become visible* after a later-started
transaction that got a later timestamp. A delta pull that lands in the gap
between the later transaction's commit and the earlier one's would see the
later row, advance its cursor past it, and then miss the earlier row
permanently once it finally commits (its timestamp is now behind the already
-advanced cursor). Mitigation: apply a small **overlap window** — when
computing the *value to send as `updatedSince`* on the *next* request, use
`max(updated_at) - overlapWindow` (suggest 10s) rather than the raw max. This
re-fetches a handful of already-applied rows every pull (harmless — upserts
are idempotent), in exchange for a strong guarantee that any transaction that
was still in flight during the previous pull gets picked up on the following
one. This is the standard mitigation for the same problem in CDC-style
pipelines, and it also covers (b) in the vast majority of cases without extra
cursor complexity.

**(d) First pull, empty catalog.** A first-ever pull can't derive a cursor
from row data if there are zero rows. The response envelope's `serverTime`
field (§1) exists specifically for this: seed the cursor from that instead,
still minus the overlap window.

**(e) Devices upgrading from a pre-delta-sync app build.** Such a device has
a complete local cache but no cursor row yet — it simply takes the "no
cursor" branch once after upgrading (one full paged pull, same cost as today,
a one-time thing), then switches to delta pulls from then on. No special
migration handling needed on the mobile side beyond "no cursor row found."

## 5. Acceptance criteria

- After any delta pull (cursor-present branch), the local `foods` table must
  still contain **every** non-hidden, non-deleted server-side food — not just
  ones changed recently. Concretely: **meal-entry autocomplete
  (`add_meal_entry_sheet.dart`'s `foodSearchProvider`, which watches
  `FoodRepository.watchAll()`) must continue to find every food, including
  ones created long before the device's most recent sync.** This is the
  existing hard invariant from Phase 2 carried forward — delta sync changes
  how the local table gets updated, never what it ultimately contains.
- A food deleted server-side while a device was offline is removed from that
  device's local cache on its next sync, via the tombstone in the feed — not
  via a full-table diff.
- A device syncing for the very first time (or for the first time after
  upgrading) still gets a full, correct catalog via the unchanged Phase 2.3
  bootstrap path.
- No behavior change for any caller that never passes `updatedSince` — the
  paged/searchable/unpaged contracts from Phase 2 are untouched.

## 6. Rollout sequence (backward compatible, backend first)

1. **Backend:** ship the Flyway migration (`updated_at`/`deleted_at` + trigger
   + index) and the `updatedSince`-aware branch of the paged handler. Fully
   additive — no existing caller (web, current mobile builds) passes
   `updatedSince`, so behavior for them is unchanged. Add the one-line
   `deletedAt` set to `FoodServiceImpl.delete()` in the same deploy; it's
   inert until a client starts reading it.
2. **Backend:** validate in isolation — hit the new param manually / via
   integration tests, confirm ordering, tombstone visibility, and that
   omitting `updatedSince` is byte-for-byte identical to before.
3. **Mobile:** add the `sync_cursors` table (new Drift migration), implement
   the two-branch `_pullFoods`, ship. Older installed app versions keep
   calling the Phase 2.3 paged-only pull against the same backend, unaffected
   — this is a mobile-side opt-in, not a breaking contract change.
4. Only after the Foods pilot has run in production long enough to trust the
   overlap-window mitigation and the tombstone lifecycle, repeat steps 1–3 for
   the next entity (meals, recipes, exercises, sessions), one at a time.
