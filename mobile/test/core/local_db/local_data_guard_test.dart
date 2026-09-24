import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/local_db/local_data_guard.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The session-expiry leak: a failed token refresh ends the session without
/// `logout()`, so nothing wiped the Drift cache. The next account to sign in
/// on the device saw the previous one's exercises and templates — and its
/// unsynced outbox rows were pushed under the new account's token.
void main() {
  late AppDatabase db;
  late LocalDataOwner owner;
  late LocalDataGuard guard;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    owner = LocalDataOwner();
    guard = LocalDataGuard(owner, db.clearAllData);
  });

  tearDown(() => db.close());

  /// What an offline weight entry leaves behind: the row and its create op.
  Future<void> seedUnsyncedWeight(String clientId) async {
    await db.into(db.weightEntries).insert(WeightEntriesCompanion.insert(
          clientId: clientId,
          date: DateTime(2026, 9, 1),
          weight: 70.5,
          recordedAt: DateTime(2026, 9, 1, 8),
        ));
    await db.into(db.pendingOperations).insert(PendingOperationsCompanion.insert(
          clientId: clientId,
          entityType: 'weight',
          operation: 'create',
          payloadJson: '{"date":"2026-09-01","weight":70.5}',
          createdAt: DateTime(2026, 9, 1, 8),
        ));
  }

  Future<int> weightRows() async => (await db.select(db.weightEntries).get()).length;
  Future<int> outboxRows() async => (await db.select(db.pendingOperations).get()).length;

  test('a different account signing in after an expired session wipes the cache and outbox', () async {
    await guard.claim(1);
    await seedUnsyncedWeight('a-weight');
    // Session expires here: tokens go, nothing else is touched.

    final wiped = await guard.claim(2);

    expect(wiped, isTrue);
    expect(await weightRows(), 0);
    expect(await outboxRows(), 0, reason: "user 1's create must never be pushed as user 2");
    expect(await owner.read(), 2);
  });

  test('the same account signing back in keeps its unsynced edits', () async {
    await guard.claim(1);
    await seedUnsyncedWeight('a-weight');

    final wiped = await guard.claim(1);

    expect(wiped, isFalse);
    expect(await weightRows(), 1);
    expect(await outboxRows(), 1);
  });

  test('unowned data is wiped on a fresh sign-in', () async {
    // Left by an install that predates the guard, after an expired session —
    // whose it is cannot be known, so it is not handed to anyone.
    await seedUnsyncedWeight('orphan');

    expect(await guard.claim(2), isTrue);
    expect(await weightRows(), 0);
    expect(await outboxRows(), 0);
  });

  test('unowned data is adopted on a signed-in cold start', () async {
    // A pre-guard install that is still signed in: the data can only be this
    // user's, and it may hold edits that have not synced yet.
    await seedUnsyncedWeight('mine');

    expect(await guard.claim(1, adoptUnowned: true), isFalse);
    expect(await outboxRows(), 1);
    expect(await owner.read(), 1);
  });

  test('a signed-in cold start under a different owner still wipes', () async {
    await guard.claim(1);
    await seedUnsyncedWeight('a-weight');

    expect(await guard.claim(2, adoptUnowned: true), isTrue);
    expect(await outboxRows(), 0);
  });

  test('release leaves no owner, so the next sign-in starts clean', () async {
    await guard.claim(1);
    await guard.release();
    await seedUnsyncedWeight('stray');

    expect(await owner.read(), isNull);
    expect(await guard.claim(1), isTrue);
    expect(await weightRows(), 0);
  });
}
