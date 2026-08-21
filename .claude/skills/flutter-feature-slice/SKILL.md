---
name: flutter-feature-slice
description: Add a new feature or a new synced entity type to the Flutter app under mobile/lib/features/. Use when building a user-facing feature that stores data — the offline-first slice of domain model, Drift table, repository plus outbox, Riverpod controller, screens, pull-sync and tests — or when an existing feature gains a new entity that must reach the backend. Not for UI-only tweaks inside an existing feature, and not for backend or web work.
---

# New feature slice (Flutter, offline-first)

Every write in this app goes to the local Drift database first and reaches the
backend through the outbox. A feature that calls `dio` directly, or skips a
registration point below, appears to work in development and then silently
fails to sync. Work through the steps in order.

## Read first

- `mobile/CLAUDE.md` — stack and layer rules.
- `lib/features/water/` — the smallest complete slice (2 entities, both
  synced, one with a relation). Use it as the shape to copy.

Read a second feature only if this one has something water doesn't (child rows,
pagination, a singleton).

Providers in this app are hand-written — `Notifier`/`StreamNotifier`/
`AsyncNotifier` subclasses plus their `*Provider`. There is no `@riverpod`
annotation anywhere in `lib/`; don't add one. `build_runner` is needed for
**drift** (`app_database.g.dart`), never for providers.

## 1. Domain model — `lib/features/<feature>/domain/<entity>.dart`

Plain Dart class, `const` constructor, final fields. No Drift types, no JSON
codecs, no Riverpod.

```dart
/// A logged water intake event (`/water-entries`).
class WaterEntry {
  const WaterEntry({required this.clientId, required this.consumedAt, this.id});

  final String clientId;   // local primary key, stable for life
  final int? id;           // server id — null until the create syncs
}
```

## 2. Drift table — `lib/core/local_db/tables/<feature>_tables.dart`

```dart
@DataClassName('WaterEntryRow')
class WaterEntries extends Table {
  @override
  String get tableName => 'water_entries';        // explicit, snake_case

  TextColumn get clientId => text()();
  IntColumn get serverId => integer().nullable()();
  RealColumn get volumeLiters => real()();
  DateTimeColumn get consumedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {clientId};       // never the server id
}
```

Relations reference the **other table's `clientId`**
(`text().nullable().references(WaterSources, #clientId)()`), never a server id —
the referenced row may not have synced yet.

## 3. Register the table and migrate

In `lib/core/local_db/app_database.dart`:

1. Add the table class to `@DriftDatabase(tables: [...])`.
2. Bump `schemaVersion` by one.
3. Add a new `if (from < <newVersion>) { ... }` branch at the **end** of
   `onUpgrade`, with a one-line comment saying what it does. Use
   `m.createTable(...)` for a new table, `_addColumnIfMissing(m, table, table.col)`
   for a new column. **Never edit an existing branch** — it has already run on
   users' devices.
4. Regenerate:

```bash
cd mobile && dart run build_runner build --delete-conflicting-outputs
```

Never hand-edit `app_database.g.dart`.

## 4. Register the entity for sync

In `lib/core/sync/entity_sync_config.dart`:

```dart
'water_entry': EntitySyncConfig(tableName: 'water_entries', basePath: '/water-entries'),
```

- `tableName` must match the table's `tableName` override exactly.
- `basePath` is the REST collection; the engine derives POST `/x`,
  PUT `/x/{serverId}`, DELETE `/x/{serverId}` from it.
- If the entity owns child/junction rows, pass `cleanupChildren` — a function
  that deletes those rows once the server confirms the parent's delete.
- Add the table name to `allEntityTableNames` in the same file. Skipping this
  breaks `clientRef` resolution for anything pointing at this entity.

## 5. Repository — `lib/features/<feature>/data/<entity>_repository.dart`

The only layer that touches the database and the outbox. **It must never call
`dio`.** Takes `AppDatabase` and `OutboxWriter` in the constructor; exposes a
provider at the bottom of the file.

**Create** — local row first, then the outbox entry:

```dart
final clientId = newClientId();
await _db.into(_db.waterEntries).insert(WaterEntriesCompanion.insert(...));
await _outbox.enqueueCreate(
  clientId: clientId,
  entityType: 'water_entry',
  payload: {
    'consumedAt': consumedAt.toUtc().toIso8601String(),  // always UTC ISO-8601
    if (sourceClientId != null) 'sourceId': clientRef(sourceClientId),
  },
  dependsOnClientId: sourceClientId,   // hold until the parent create syncs
);
```

Foreign keys in a payload go through `clientRef(...)`, never a raw server id.
`dependsOnClientId` is harmless when the parent already synced.

**Update** — `_outbox.enqueueUpdate(...)`; it handles the "create still
pending" case itself.

**Delete** — read the return value, it is a contract:

```dart
final queuedServerDelete = await _outbox.enqueueDelete(
  clientId: clientId, entityType: 'water_entry');
if (!queuedServerDelete) {
  // never synced — nothing will ever go out, so drop the row now
  await (_db.delete(_db.waterEntries)..where((t) => t.clientId.equals(clientId))).go();
}
// true: leave the row in place. SyncEngine deletes it once the server confirms;
// hide it from list UIs with blockedByActiveDelete() instead.
```

**Reads** — Drift watch streams, never a one-shot query, so the UI updates the
moment a local write lands. Filter rows with an in-flight delete:

```dart
return combineLatest2(rows$, pendingOps$, (rows, ops) {
  final blocked = blockedByActiveDelete(ops);
  return rows.where((r) => !blocked.contains(r.clientId)).map(_toDomain).toList();
});
```

Compute date boundaries **inside** the stream's `map`, not in a SQL `where` —
a boundary baked in at query-build time goes stale at midnight.

## 6. Controller — `lib/features/<feature>/application/<name>_controller.dart`

Hand-written `StreamNotifier` wrapping the repository stream:

```dart
class WaterSourceController extends StreamNotifier<List<WaterSource>> {
  WaterSourceRepository get _repo => ref.read(waterSourceRepositoryProvider);

  @override
  Stream<List<WaterSource>> build() => _repo.watchAll();

  Future<void> addSource({...}) => _repo.create(...);
}

final waterSourceControllerProvider =
    StreamNotifierProvider<WaterSourceController, List<WaterSource>>(WaterSourceController.new);
```

If the screen has pull-to-refresh, `refresh()` does both halves — push then
pull — inside a `try/catch` that swallows connectivity errors:
`await ref.read(syncEngineProvider).sync();` then
`await ref.read(pullEngineProvider).pullAll();`.

Derived read-only values are plain `Provider`s over the controller's stream
(see `daily_water_totals_provider.dart`), not a second source of truth.

## 7. Pull — `lib/core/sync/pull_engine.dart`

Without this, the entity only ever goes **out**; a fresh install or a second
device sees nothing. Add, following `_pullWeightEntries` as the template:

1. `await _guard('<table_name>', _pullX);` in `pullAll()`, ordered so parents
   come before the entities that reference them.
2. `_pullX()` — read the cursor via `_getSyncCursor`, branch to
   `_pullXFull()` (no cursor) or `_pullXDelta(cursor)`.
3. `_pullXFull()` — `_getList(basePath)`, upsert each, collect `seen` server
   ids, `_deleteMissing(table, seen)`, then set the cursor to
   `maxUpdatedAt.subtract(_cursorOverlap)`.
4. `_pullXDelta(since)` — `_getAllPages(basePath, size: 200,
   extraQueryParameters: {'updatedSince': ...})`; rows with `deletedAt != null`
   go to the tombstone handler, the rest to the upsert.
5. `_upsertX(json)` — resolve the local `clientId` by server id;
   **`if (await _hasPendingOperation(existingClientId)) return;`** so a pull
   never overwrites an unsynced local edit; update if present, insert with a
   fresh `newClientId()` if not.

If the backend endpoint has no `updatedSince`/`deletedAt` support yet, wire the
full pull only and say so in the PR — do not fake a delta.

## 8. Presentation, routing, strings

- Screens in `presentation/`, sub-widgets in `presentation/widgets/`.
- Widgets read `ref.watch(<controller>Provider)` and call controller methods.
  They never touch the repository, the database, or `dio`.
- Register the route as a `GoRoute` in `lib/core/router/` — inside the shell
  branch if it is a tab, top-level otherwise.
- **All user-facing text goes through the ARB files.** Use the `localization`
  skill; no literal strings in widgets.

## 9. Tests — `mobile/test/features/<feature>/`

Mirror the `lib/` path. In-memory database, no mocking framework needed:

```dart
db = AppDatabase(NativeDatabase.memory());
```

To assert what actually goes to the network, install a recording
`HttpClientAdapter` on a `Dio` instance (see
`test/core/sync/food_update_http_method_test.dart`) and check the method and
path the sync engine produced. Cover at minimum: create enqueues the right
operation and payload, delete respects the `enqueueDelete` contract, and the
pull upsert skips rows with a pending local operation.

## 10. Verify — the same commands CI runs

```bash
cd mobile && dart run build_runner build --delete-conflicting-outputs && flutter analyze && flutter test
```

All three must be clean before the work is done.

## Definition of done

- [ ] `domain/`, `data/`, `application/`, `presentation/` all present (a thin
      layer is fine, a missing one is not)
- [ ] Table registered in `@DriftDatabase`, `schemaVersion` bumped, new
      `onUpgrade` branch added, no existing branch touched
- [ ] `entitySyncConfigs` entry **and** `allEntityTableNames` entry added
- [ ] Repository never imports `dio`; reads are watch streams
- [ ] `enqueueDelete`'s return value drives whether the local row is removed
- [ ] Pull path added to `PullEngine`, with the pending-operation guard
- [ ] Route registered; every string in the ARB files, EN **and** HU
- [ ] No hand-edited `*.g.dart`
- [ ] `build_runner` + `flutter analyze` + `flutter test` all clean
