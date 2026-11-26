import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:path/path.dart' as p;

/// LIF-224 added `note` to `workout_session_exercises` in schema 55. A phone on
/// 54 has sessions logged already: the upgrade must add the column and keep
/// every planned exercise, with no comment.
void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('lifey_session_exercise_note_migration');
    file = File(p.join(dir.path, 'lifey.sqlite'));
  });

  tearDown(() async => dir.delete(recursive: true));

  test('upgrading from schema 54 adds the column and keeps the planned exercises', () async {
    var db = AppDatabase(NativeDatabase(file));
    await db.customStatement("INSERT INTO exercises (client_id, name) VALUES ('ex1', 'Bench press')");
    await db.customStatement("INSERT INTO workout_sessions (client_id, started_at) VALUES ('s1', 1780000000)");
    await db.customStatement(
      "INSERT INTO workout_session_exercises (client_id, session_client_id, exercise_client_id, target_sets) "
      "VALUES ('l1', 's1', 'ex1', 3)",
    );
    // Put the file back in its schema-54 shape.
    await db.customStatement('ALTER TABLE workout_session_exercises DROP COLUMN note');
    await db.customStatement('PRAGMA user_version = 54');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    final link = await db.select(db.workoutSessionExercises).getSingle();
    expect(link.clientId, 'l1');
    expect(link.targetSets, 3);
    expect(link.note, isNull);

    await db.customStatement("UPDATE workout_session_exercises SET note = 'seat on 4' WHERE client_id = 'l1'");
    expect((await db.select(db.workoutSessionExercises).getSingle()).note, 'seat on 4');
    await db.close();
  });
}
