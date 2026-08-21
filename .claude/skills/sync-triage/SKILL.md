---
name: sync-triage
description: Diagnose offline-sync bugs in the Flutter app — a local change that never reaches the backend, a server change that never appears on the phone, a row stuck on "syncing", a duplicate or vanished entity, an entity that syncs on one device but not another. Use when data is wrong or missing across the client/server boundary rather than wrong on screen. Not for pure UI bugs and not for adding new synced entities (use flutter-feature-slice for that).
---

# Sync triage

Sync has two independent halves, and the first job is deciding which one is
broken. Guessing wastes the most time here.

| Symptom | Broken half | Start at |
|---|---|---|
| Local change never reaches the server | **push** | `pending_operations` (§2) |
| Server change never appears on the phone | **pull** | `PullEngine` (§4) |
| Row shows a sync marker forever | **push** | operation status (§2) |
| Row reappears after being deleted | either | §3 and §4 |
| Duplicate rows after a sync | **pull** | the entity's `_upsertX` (§4) |
| Works on one device, not another | **pull** | that device's cursor (§4) |

The whole push path is ~2500 lines under `mobile/lib/core/sync/`. Read
`sync_engine.dart` and `outbox_writer.dart` before theorising — their doc
comments record the bugs that already happened here, and a new report is very
often one of them.

## 1. Reproduce it in a test first

Sync bugs are timing-dependent by nature and nearly impossible to confirm by
tapping. The repo has a harness for this — copy
`test/core/sync/food_update_http_method_test.dart`:

```dart
db = AppDatabase(NativeDatabase.memory());
dio = Dio(BaseOptions(baseUrl: 'http://test'));
dio.httpClientAdapter = _RecordingAdapter();   // records method + path, fakes {"id": N}
syncEngine = SyncEngine(db, dio);
```

That gives you the exact HTTP verbs and paths a local operation produces, with
no network. Offline is simply an adapter that throws. A fix without a test that
fails before it is not finished — every entry in §3 was silent in production.

## 2. Push path: read the outbox

Every local write enqueues a `pending_operations` row. Its `status` is the
whole story:

| status | Meaning | Retried? |
|---|---|---|
| `pending` | queued, waiting for a drain | yes, every trigger |
| `syncing` | request currently in the air | — |
| `failed`, `lastError` starting `[network] ` | connectivity failure | yes, automatically |
| `failed`, any other `lastError` | server rejected it (4xx/5xx, validation) | **no** — parked until someone retries it |

In the app, `syncStatusByClientIdProvider` derives this per `clientId` and
`SyncStatusIndicator` renders it. In a test or a debug session, read the table
directly:

```dart
final ops = await db.select(db.pendingOperations).get();
// clientId, entityType, operation, status, lastError, dependsOnClientId, payloadJson
```

Three questions, in order:

1. **Is there an operation row at all?** If not, the repository never enqueued
   one — the bug is in the feature's `data/` layer, not in sync. A repository
   that writes the local row and forgets `enqueueCreate` looks perfectly
   correct on screen.
2. **Is it blocked?** `dependsOnClientId` set, or a `clientRef:` marker in the
   payload whose target has no `serverId` yet, means the engine is deliberately
   holding it (`SyncEngine._isBlocked`). Then the real question is why the
   *parent* never synced — chase that one instead.
3. **Is it parked?** A non-`[network]` `failed` never retries on its own. Read
   `lastError`: it is the server's message. Fix the cause, then
   `OutboxWriter.resetFailed(entityType)` re-arms every parked op of that type.

## 3. Known failure classes on the push side

Each of these already happened; the code comments name them.

- **Stranded `syncing`.** The app was killed while a request was open, leaving
  the row `syncing` forever — and, because later updates queue behind an
  unsynced create, the entity's whole future was stuck too, showing a neutral
  "syncing…" marker rather than an error. `SyncEngine._reclaimStaleSyncing`
  requeues these at the start of every drain. Most likely after a long
  backgrounded cardio session. If you see it again, ask why the reclaim did not
  run, not whether it exists.
- **Two rows for one `clientId`.** An update queued behind a pending create
  gives that `clientId` two operation rows; any `getSingleOrNull()` over
  `clientId` alone throws "Too many elements" — which used to crash every sync
  pass silently, because `OutboxWriter._kick()` never awaits `sync()`. Filter by
  `clientId` **and** `operation` when you query the outbox.
- **Swallowed exceptions.** `_kick()` is fire-and-forget by design. An
  exception thrown inside a drain therefore surfaces nowhere. When a symptom is
  "nothing happens at all", `await` the sync explicitly in a test before
  concluding the code path is never reached.
- **Delete that un-deletes.** `enqueueDelete` returns whether a server-side
  delete was queued. `true` means the local row must stay (hidden via
  `blockedByActiveDelete`) until the server confirms; deleting it locally
  destroys the `serverId` the DELETE needs. A row that reappears after a
  rejected delete is the system working as designed — check whether the caller
  honoured the contract before "fixing" it.
- **Dangling `clientRef:`.** A reference to an entity that was deleted before
  it ever synced can never resolve; `_resolvePayload` parks the operation as
  failed rather than blocking it forever. Expect this after a delete-then-edit
  sequence offline.

## 4. Pull path: read the cursor

`PullEngine.pullAll()` runs one `_guard(entity, _pullX)` per entity. `_guard`
catches everything and continues, so **one broken entity never stops the
others** — and never fails loudly either. Its `debugPrint` lines are the
cheapest signal you have:

```
PullEngine: weight_entries OK
PullEngine: meals FAILED (409), continuing
```

Then check, in order:

1. **Is the entity in `pullAll` at all?** A new entity wired for push but not
   for pull syncs out and never back — invisible until a reinstall or a second
   device.
2. **Cursor state.** No cursor → full pull; a cursor → delta pull with
   `?updatedSince`. A device that "doesn't get updates" usually has a cursor
   ahead of the data it is missing. Clear the row in `sync_cursors` for that
   entity to force a full pull and confirm.
3. **The pending-operation guard.** Every `_upsertX` starts with
   `if (await _hasPendingOperation(existingClientId)) return;` — the pull must
   never overwrite an unsynced local edit. A missing guard shows up as "my edit
   got reverted a minute later".
4. **Tombstones.** A delta response row with `deletedAt != null` must go to the
   entity's tombstone handler. Missing that, deletions made elsewhere never
   reach this device.
5. **Matching by `serverId`.** `_upsertX` resolves the local `clientId` from
   the server id; if it inserts unconditionally instead, you get duplicates on
   every pull.

The 10-second `_cursorOverlap` is deliberate (`docs/15-delta-sync.md` §4(c)) —
re-applying a row is idempotent, so a small overlap is the cheap defence
against clock skew. Rows arriving twice is not the bug.

## 5. When the client is innocent

The mobile side can only sync what the backend reports. Check these before
digging further into Dart:

- **`updated_at` not bumped.** It is maintained by `SyncableEntity`'s
  `@PrePersist`/`@PreUpdate`. A write that only touches *child* rows
  (`exercise_sets`, `cardio_splits`, `workout_session_exercises`) does not touch
  the parent, so the parent's `updated_at` must be bumped explicitly — otherwise
  the change exists on the server and no delta feed ever mentions it.
- **Hard delete instead of a tombstone.** A row that vanishes server-side is
  invisible to delta sync; clients keep it forever.
- **Hibernate's flush order.** For a full-replace child collection
  (`clear()` then re-insert the same indexes), Hibernate flushes inserts before
  deletes and trips the unique constraint — deterministically, on the second
  update onward. The fix is an explicit `repository.flush()` between the clear
  and the re-insert; commit `5b39043` did exactly this for `cardio_splits` and
  `cardio_waypoints`. A 500 in `lastError` on a session update is the signature.
- **Missing `?updatedSince` endpoint.** Without it the client can only full-pull.

## 6. Rules for the fix

- Fix the cause, then re-arm the parked operations (`resetFailed`) — do not
  hand-edit `pending_operations` to make a symptom go away.
- Never resolve a stuck entity by dropping its outbox rows unless the user's
  data is genuinely disposable; `discard` exists but it silently abandons a
  write the user believes was saved.
- Every fix gets a regression test using the harness in §1.
- If the bug came from a rule that was not written down, add the rule to the
  relevant skill or doc comment in the same change. That is how the list in §3
  got there.
