import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:path/path.dart' as p;

/// Verifies the V44 migration step (`docs/landing_page/67-mobile-free-pro-plan.md`
/// §2, D-P2) actually creates `entitlement_cache` on an upgrade, and that the
/// table behaves as the single-row cache it's meant to be.
void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('lifey_entitlement_migration_test');
    file = File(p.join(dir.path, 'lifey.sqlite'));
  });

  tearDown(() async => dir.delete(recursive: true));

  test('upgrading from V43 creates entitlement_cache', () async {
    // Build a file at the current schema (which already includes
    // entitlement_cache from onCreate), then roll it back to a pre-V44
    // device: drop the table and rewind only the recorded version — exactly
    // the state a real device on V43 is in.
    var db = AppDatabase(NativeDatabase(file));
    await db.customStatement('DROP TABLE entitlement_cache');
    await db.customStatement('PRAGMA user_version = 43');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    // Would throw ("no such table") if the migration step hadn't run.
    final rows = await db.select(db.entitlementCacheTable).get();
    expect(rows, isEmpty);
    await db.close();
  });

  test('the primary key enforces a single row', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final row = EntitlementCacheTableCompanion.insert(
      id: 'singleton',
      tier: 'FREE',
      source: 'NONE',
      adsEnabled: true,
      checkedAt: DateTime.utc(2026, 1, 1),
      graceUntil: DateTime.utc(2026, 1, 8),
    );
    await db.into(db.entitlementCacheTable).insert(row);
    // A second insert with the same id must replace, not duplicate.
    await db.into(db.entitlementCacheTable).insertOnConflictUpdate(
          row.copyWith(tier: const Value('PRO')),
        );

    final rows = await db.select(db.entitlementCacheTable).get();
    expect(rows, hasLength(1));
    expect(rows.single.tier, 'PRO');
  });
}
