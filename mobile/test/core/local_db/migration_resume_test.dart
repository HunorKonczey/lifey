import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:path/path.dart' as p;

/// Drift stamps the new `user_version` only after every step of the upgrade
/// has succeeded, so an upgrade interrupted half-way (app killed, a later step
/// throwing) leaves a file whose schema is ahead of its recorded version. The
/// next launch replays the already-applied steps, and a plain
/// `ALTER TABLE ... ADD COLUMN` there fails with "duplicate column name" —
/// forever, since the version can never advance past the failing step.
void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('lifey_migration_test');
    file = File(p.join(dir.path, 'lifey.sqlite'));
  });

  tearDown(() async => dir.delete(recursive: true));

  test('an upgrade replayed over an already-applied step still completes',
      () async {
    // Fresh file: onCreate builds the current schema and records the version.
    var db = AppDatabase(NativeDatabase(file));
    expect(await _userVersion(db), db.schemaVersion);

    // Rewind only the recorded version, leaving the schema in place — exactly
    // the state an interrupted upgrade leaves behind.
    await db.customStatement('PRAGMA user_version = 28');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    expect(await _userVersion(db), db.schemaVersion);
    await db.close();
  });
}

Future<int> _userVersion(AppDatabase db) async {
  final row = await db.customSelect('PRAGMA user_version').getSingle();
  return row.read<int>('user_version');
}
