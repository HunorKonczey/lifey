import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/client_ref.dart';
import 'package:lifey/core/sync/outbox_dependencies.dart';
import 'package:lifey/core/sync/outbox_writer.dart';
import 'package:lifey/core/sync/sync_engine.dart';
import 'package:lifey/core/sync/sync_status_provider.dart';

/// A create the server rejected for good stays parked as `failed`, and everything queued behind it
/// (a meal that references the food, an update of the same entity) is held back for as long as it
/// stays there. Those rows used to read as a neutral "waiting to sync", so the user saw the meal
/// syncing for ever with no hint that it was the food that needed attention.
class _NoopSyncEngine extends SyncEngine {
  _NoopSyncEngine(super.db, super.dio);

  @override
  Future<void> sync() async {}
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> insert(
    String clientId,
    String operation, {
    String status = 'pending',
    String? lastError,
    Map<String, dynamic> payload = const {},
    String? dependsOn,
  }) =>
      db.into(db.pendingOperations).insert(PendingOperationsCompanion.insert(
            clientId: clientId,
            entityType: 'food',
            operation: operation,
            payloadJson: jsonEncode(payload),
            dependsOnClientId: Value(dependsOn),
            status: Value(status),
            lastError: Value(lastError),
            createdAt: DateTime(2026, 10, 7),
          ));

  Future<List<PendingOperationRow>> ops() => db.select(db.pendingOperations).get();

  test('an operation that references a rejected create is blocked, with the rejection as its reason', () async {
    await insert('food', 'create', status: 'failed', lastError: 'Barcode already exists');
    await insert('meal', 'create', payload: {
      'entries': [
        {'foodId': clientRef('food')},
      ],
    });
    await insert('unrelated', 'create');

    final blocked = blockedByFailure(await ops());

    expect(blocked, {'meal': 'Barcode already exists'});
  });

  test('the blockage is followed through a chain of dependencies', () async {
    await insert('food', 'create', status: 'failed', lastError: 'rejected');
    await insert('recipe', 'create', payload: {'foodId': clientRef('food')});
    await insert('meal', 'create', payload: {'recipeId': clientRef('recipe')});

    expect(blockedByFailure(await ops()).keys, unorderedEquals(['recipe', 'meal']));
  });

  test('a network failure blocks nothing: it is retried by itself', () async {
    await insert('food', 'create', status: 'failed', lastError: '[network] timeout');
    await insert('meal', 'create', payload: {'foodId': clientRef('food')});

    expect(blockedByFailure(await ops()), isEmpty);
  });

  test('an explicit dependsOnClientId counts like a payload reference', () async {
    await insert('source', 'create', status: 'failed', lastError: 'nope');
    await insert('entry', 'create', dependsOn: 'source');

    expect(blockedByFailure(await ops()), {'entry': 'nope'});
  });

  test('the status provider shows a blocked entity as failed, with the root cause', () async {
    await insert('food', 'create', status: 'failed', lastError: 'Barcode already exists');
    await insert('meal', 'create', payload: {'foodId': clientRef('food')});
    final rows = await ops();
    final container = ProviderContainer(overrides: [
      pendingOperationsProvider.overrideWith((ref) => Stream.value(rows)),
    ]);
    addTearDown(container.dispose);
    container.listen(pendingOperationsProvider, (previous, next) {});
    await pumpEventQueue();

    final statuses = container.read(syncStatusByClientIdProvider);

    expect(statuses['food']!.state, SyncState.failed);
    expect(statuses['meal']!.state, SyncState.failed);
    expect(statuses['meal']!.lastError, 'Barcode already exists');
  });

  test('retrying the blocked entity retries the failure it waits behind', () async {
    await insert('food', 'create', status: 'failed', lastError: 'rejected');
    await insert('meal', 'create', payload: {'foodId': clientRef('food')});
    await insert('other', 'create', status: 'failed', lastError: 'unrelated problem');
    final writer = OutboxWriter(db, _NoopSyncEngine(db, Dio()));

    await writer.retry('meal');

    final byId = {for (final op in await ops()) op.clientId: op};
    expect(byId['food']!.status, 'pending');
    expect(byId['food']!.lastError, isNull);
    expect(byId['other']!.status, 'failed');
  });

  test('ancestors are collected transitively and never include the entity itself', () async {
    await insert('food', 'create');
    await insert('recipe', 'create', payload: {'foodId': clientRef('food')});
    await insert('recipe', 'update', dependsOn: 'recipe');
    await insert('meal', 'create', payload: {'recipeId': clientRef('recipe')});

    expect(outboxAncestors('meal', await ops()), {'recipe', 'food'});
    expect(outboxAncestors('food', await ops()), isEmpty);
  });
}
