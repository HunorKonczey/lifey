import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:path/path.dart' as p;

/// LIF-205 added the `sleep_sessions` table in schema 56 (docs/integrations/89
/// D-G7). A phone on 55 has no such table: the upgrade must create it and keep
/// the data already there.
void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('lifey_sleep_sessions_migration');
    file = File(p.join(dir.path, 'lifey.sqlite'));
  });

  tearDown(() async => dir.delete(recursive: true));

  test('upgrading from schema 55 creates the table and keeps existing rows', () async {
    var db = AppDatabase(NativeDatabase(file));
    await db.customStatement("INSERT INTO exercises (client_id, name) VALUES ('ex1', 'Bench press')");
    // Put the file back in its schema-55 shape.
    await db.customStatement('DROP TABLE sleep_sessions');
    await db.customStatement('PRAGMA user_version = 55');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    expect((await db.select(db.exercises).getSingle()).clientId, 'ex1');
    expect(await db.select(db.sleepSessions).get(), isEmpty);

    await db.into(db.sleepSessions).insert(SleepSessionsCompanion.insert(
          clientId: 's1',
          startedAt: DateTime.utc(2026, 11, 20, 22, 40),
          endedAt: DateTime.utc(2026, 11, 21, 6, 10),
          remMinutes: const Value(110),
        ));
    expect((await db.select(db.sleepSessions).getSingle()).remMinutes, 110);
    await db.close();
  });
}
