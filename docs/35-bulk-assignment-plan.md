# Bulk Assignment Plan (Roadmap #15)

Goal: assign a workout template or recipe to multiple clients in **one
request** — a real server-side bulk operation extending the existing
`AssignmentController`, replacing the web drawer's current workaround of
firing N parallel single-client POSTs.

## Current state

Backend (`com.lifey.trainer`):

* **`POST /api/v1/trainer/assignments`** (`AssignmentController.assign`)
  takes a single `{clientId, contentType, sourceId}` and deep-copies the
  trainer's template/recipe into that client's account
  (`ContentAssignmentServiceImpl.assign`), in one transaction:
  * `requireActiveClient` guard → `NotYourClientException` (403).
  * Re-assigning the same (trainer, client, type, source) throws
    `DuplicateResourceException` → 409 (`GlobalExceptionHandler`).
  * Referenced exercises/foods are copy-or-reused per client
    (`origin_trainer_id` + `origin_source_id` lookup); food name conflicts
    are disambiguated per the *client's* language (`MailLanguageResolver`).
  * A `content_assignments` fact row records the action; `unassign`
    hard-deletes the row and soft-deletes the client's copy.
* **`GET /api/v1/trainer/assignments/clients?contentType&sourceId`** returns
  the client ids already holding this content — feeds the drawer's
  pre-checked/locked rows.
* `AssignmentResponse.previouslyAssigned` is vestigial: the service now
  *throws* on duplicates instead of re-copying, so it is always `false`.
* Live propagation of later edits (`AssignedContentSyncListener` →
  `propagateTemplateUpdate`/`propagateRecipeUpdate`) iterates the fact rows —
  bulk just means more rows, no change needed.
* No DB constraint enforces fact-row uniqueness; only the `existsBy…` check
  in the service (racy across concurrent requests).
* Latest Flyway migration: **V60**.

Web (`web/src/features/trainer`):

* `AssignToClientDrawer` **already has multi-select UX** (search, checkbox
  list, already-assigned rows locked). Submitting runs
  `Promise.allSettled(clientIds.map(id => trainerApi.assign(...)))` and then
  a four-way toast matrix (all ok / all failed / partial / partial-duplicate,
  keys `assignedMultiple`, `assignedPartial`,
  `assignedPartialAlreadyAssigned`, `alreadyAssignedFailed` in
  `messages/hu.json` + `en.json`). Partial failure leaves the system in a
  "some clients got it, some didn't" state the trainer must untangle
  manually.
* Covered by `web/e2e/trainer-flow.spec.ts` (testids
  `assign-to-client-drawer`, `assign-drawer-client-row`,
  `assign-drawer-submit`).

Mobile:

* **Zero involvement.** Copies land in the client's account and arrive via
  the normal delta sync; nothing on the phone knows or cares whether the
  assignment was solo or bulk.

## Design decisions

**Evolve the existing endpoint instead of adding a `/bulk` sibling.**
`AssignmentRequest.clientId: Long` becomes `clientIds: List<Long>`
(`@NotEmpty`, `@Size(max = 100)`), same route, same controller method. The
app is unreleased and the only caller is the web drawer, so there is no
back-compat surface; a parallel `/assignments/bulk` endpoint would leave two
code paths doing the same thing forever. A single client is simply a bulk of
one.

**One transaction, all-or-nothing, with "already assigned" as a skip — not
an error.** Semantics per request:

* Every requested client must be an active client (`requireActiveClient`
  each) — one revoked client fails the whole request with 403. This is a
  UI-state-went-stale case, not a business outcome to report per-row;
  atomically failing keeps zero partial state to explain.
* The source must exist and be owned by the trainer — else 404, whole
  request.
* Clients that already hold this content are **skipped and reported**, not
  failed. In a bulk context a duplicate is not an error: the drawer locks
  those rows anyway, so a duplicate can only appear through a race (another
  tab, double submit) — and idempotent skip makes retries safe.
* Any unexpected copy failure rolls back everything (same guarantee the
  single-assign transaction gives today, now for the whole batch).

*Rejected alternative*: per-client independent transactions returning a
per-row status list — this is what the UI currently emulates client-side.
It forces the four-way toast matrix to survive, can leave half-assigned
batches, and buys nothing: the only per-row "failure" worth tolerating is
the duplicate, which skip-semantics already absorb.

Batch size is bounded by roster reality (the codebase's standing "trainer
rosters are small" assumption, see `propagateTemplateUpdate`'s accepted
N+1); ~10 entity inserts per client × ≤100 clients is a comfortable single
transaction. The `@Size(max = 100)` cap is a sanity rail, not a tuning
knob.

**Response = what happened, per group.** New `BulkAssignmentResponse`:

```json
{
  "assignments": [
    { "clientId": 7, "assignmentId": 91, "copiedId": 412, "assignedAt": "…" }
  ],
  "skippedClientIds": [3]
}
```

Status 201 (something may have been created; an all-skipped request still
returns 201 with an empty `assignments` array — simpler than branching the
status on content). `previouslyAssigned` disappears along with the old
single `AssignmentResponse` usage in this flow; `skippedClientIds` carries
that information properly.

**Load the source once, copy N times.** `assignTemplate`/`assignRecipe`
currently re-fetch the source per call; the bulk loop hoists the
`findByIdAndUserId` + ownership check out of the loop and passes the loaded
source in. Per-client behavior inside the loop is untouched: exercise/food
copy-reuse, food-name disambiguation in the *client's* language, and recipe
image copying all already operate per client and work in a loop as-is.

**The internal single-assign path survives unchanged.**
`resolveClientCopy` (the implicit-assignment path used by schedules and
program assignments) keeps calling a single-client service method with the
existing duplicate-throws semantics. Refactor shape in
`ContentAssignmentServiceImpl`:

* `assign(request)` → orchestrates the bulk: guards, source load, loop of
  `assignOne(trainerId, clientId, source…)`, skip collection, response.
* `assignOne(...)` — the existing single-client body (duplicate check that
  *throws* stays here for the `resolveClientCopy` call site; the bulk loop
  pre-filters duplicates with `existsBy…` and never triggers it).

**Harden the duplicate check with a DB unique index (V61).** The `existsBy`
pre-check is racy between concurrent requests; since `unassign` hard-deletes
the fact row, `(trainer_id, client_id, content_type, source_id)` is a true
invariant:

```sql
-- V61__content_assignments_unique.sql
create unique index content_assignments_unique_idx
    on content_assignments (trainer_id, client_id, content_type, source_id);
```

A lost race then surfaces as a constraint violation → the batch rolls back
and the retry skips cleanly. Cheap insurance, one line, no code change
required for the happy path.

## Milestones

### M1 — Backend

* `V61__content_assignments_unique.sql` (above).
* `AssignmentRequest`: `clientId` → `@NotEmpty @Size(max = 100)
  List<Long> clientIds`. Dedupe ids server-side (`LinkedHashSet`) before
  processing.
* New `dto/BulkAssignmentResponse` (+ nested/record item
  `BulkAssignmentItem {clientId, assignmentId, copiedId, assignedAt}`).
  `AssignmentResponse` stays for the internal path but drops from the
  controller; if `previouslyAssigned` is then dead, delete the field.
* `ContentAssignmentService`/`Impl`: `assign` returns
  `BulkAssignmentResponse`; extract `assignOne`; hoist source loading; skip
  already-assigned clients into `skippedClientIds`. `requireActiveClient`
  loop runs *before* any copying so the 403 fires with zero writes (belt and
  suspenders — the transaction would roll back anyway).
* `AssignmentController.assign` — same route/status, new request/response
  types; update the `@Operation` description (mention skip semantics).
* Swagger/OpenAPI output is regenerated automatically; no doc task.

### M2 — Web

* `types.ts`: `AssignmentRequest.clientIds: number[]`; add
  `BulkAssignmentResponse`.
* `api.ts`: `assign` keeps its name, new body/response types — still one
  function, now one HTTP call.
* `AssignToClientDrawer`: the mutation becomes a single
  `trainerApi.assign({ clientIds: newClientIds, contentType, sourceId })`.
  Toast logic collapses:
  * `assignments.length > 0 && skipped == 0` → existing `assigned`/
    `assignedMultiple` success toast, close drawer.
  * `skippedClientIds.length > 0` → success toast with a skipped-count
    variant (new key `assignedWithSkipped`), close drawer (skips are not
    failures).
  * HTTP error (403 stale roster / 404 deleted source / network) → single
    `assignFailed` error toast, invalidate `trainerClients` so the roster
    refreshes.
  * Delete the now-dead keys from `hu.json`/`en.json`
    (`assignedPartial`, `assignedPartialAlreadyAssigned`,
    `alreadyAssignedFailed`) and the `ApiError`-instanceof 409 sniffing.
* Query invalidation unchanged: per-client `trainerAssignments.forClient`
  + `trainerAssignments.assignedClients(contentType, sourceId)`.

Mobile: nothing.

## Edge cases

* **Duplicate ids in `clientIds`** — deduped server-side; the response
  reports each client once.
* **Every requested client already has the content** — 201 with empty
  `assignments`, all ids in `skippedClientIds`; the drawer shows the
  skipped-variant toast. Idempotent double-submit therefore cannot error.
* **A client was revoked between drawer load and submit** — 403 for the
  whole batch, nothing written; the drawer surfaces the error and
  invalidates the client list. Skipping revoked clients silently was
  rejected: it would mask a roster change the trainer should see.
* **Source deleted between dialog open and submit** — 404, whole batch,
  nothing written.
* **Concurrent assign of the same content from two sessions** — the V61
  unique index turns the race into a constraint violation; one batch wins,
  the other rolls back fully and succeeds on retry via skip.
* **Shared exercises/foods across clients** — reuse is *per client*
  (`origin_trainer_id` + `origin_source_id` is client-scoped), so the loop
  cannot cross-contaminate; a client who already owns copies from an earlier
  assignment reuses them exactly as today.
* **Food-name conflict on some clients only** — disambiguation
  (`"… (Edzőtől)"` / `"… (From trainer)"`) is evaluated per client inside
  the loop, in that client's language — unchanged behavior, just verified in
  tests for the multi-client case.
* **Recipe image** — copied per client after each copy row is persisted
  (FK order), same as today; N clients → N image rows.
* **Live edit propagation after a bulk assign** — no change:
  `propagateTemplateUpdate`/`propagateRecipeUpdate` already iterate all fact
  rows for the source.

## Testing

Backend (extend the existing suites):

* `ContentAssignmentServiceImplTest`:
  * bulk happy path — N fact rows, N template/recipe copies, response lists
    every client, `skippedClientIds` empty;
  * skip path — mixed batch where some clients already hold the content;
  * dedupe — repeated ids create one assignment;
  * atomicity — one non-client in the batch → 403 and **zero** rows/copies
    persisted;
  * source not owned / deleted → 404, zero writes;
  * exercise reuse per client (client with a prior copy reuses it, fresh
    client gets a new one, in the same batch);
  * recipe image copied for every client;
  * `resolveClientCopy` (schedule/program path) still works and still
    throws on the fact-row-exists-but-copy-deleted duplicate case —
    unchanged semantics guard.
* `AssignmentControllerTest`: request validation (empty `clientIds`,
  > 100 ids, missing fields), 201 shape with skips, auth guard.

Web:

* `web/e2e/trainer-flow.spec.ts`: update the assign-drawer flow — select
  two clients, submit, assert a single network call and the success toast;
  reopen the drawer and assert both rows are now locked.
* No new unit-test surface: the drawer loses logic (the allSettled matrix)
  rather than gaining it.

## Out of scope (deliberate)

* **Bulk program assignment** — `AssignProgramDrawer` stays single-client:
  a program assignment carries a start date and per-client overlap rules,
  so batching it is a different design conversation (possible follow-up).
* **Bulk unassign** — no roadmap demand; unassign stays per-row on the
  assignments page.
* **Per-row partial results / async job semantics** — unnecessary at ≤100
  clients and this copy cost; revisit only if rosters stop being small.
* **Client notification on assignment** — no push exists for solo assign
  today; adding one is orthogonal (would slot into the docs/30 pattern).

## Suggested order & sizing

M1 → M2, a day-or-less each. M1 is shippable alone (the drawer's parallel
POSTs keep working against the old contract only until the DTO change lands,
so in practice M1+M2 merge together in one branch — the request-shape change
is breaking, which is fine pre-release). Rough split: backend 60%
(service refactor + tests), web 30% (drawer simplification), migration 10%.
