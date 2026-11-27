import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:path/path.dart' as p;

/// LIF-211 added the `daily_vitals` table in schema 57 (docs/integrations/89
/// D-G8). A phone on 56 has no such table: the upgrade must create it and keep
/// the data already there.
void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('lifey_daily_vitals_migration');
    file = File(p.join(dir.path, 'lifey.sqlite'));
  });

  tearDown(() async => dir.delete(recursive: true));

  test('upgrading from schema 56 creates the table and keeps existing rows', () async {
    var db = AppDatabase(NativeDatabase(file));
    await db.customStatement("INSERT INTO exercises (client_id, name) VALUES ('ex1', 'Bench press')");
    // Put the file back in its schema-56 shape.
    await db.customStatement('DROP TABLE daily_vitals');
    await db.customStatement('PRAGMA user_version = 56');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    expect((await db.select(db.exercises).getSingle()).clientId, 'ex1');
    expect(await db.select(db.dailyVitalsTable).get(), isEmpty);

    await db.into(db.dailyVitalsTable).insert(DailyVitalsTableCompanion.insert(
          clientId: 'v1',
          date: DateTime(2026, 11, 21),
          hrvMs: const Value(48.5),
          hrvMethod: const Value('RMSSD'),
        ));
    expect((await db.select(db.dailyVitalsTable).getSingle()).hrvMethod, 'RMSSD');
    await db.close();
  });
}
