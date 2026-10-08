import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:path/path.dart' as p;

/// LIF-144 added `trainer_comment` and `trainer_comment_at` to `meals` in schema 47. A phone that is on 46 has meals
/// logged already: the upgrade must add the columns and keep every one of them.
void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('lifey_meal_comment_migration');
    file = File(p.join(dir.path, 'lifey.sqlite'));
  });

  tearDown(() async => dir.delete(recursive: true));

  test('upgrading from schema 46 adds the comment columns and keeps the logged meals', () async {
    var db = AppDatabase(NativeDatabase(file));
    await db.customStatement(
      "INSERT INTO meals (client_id, meal_date_time, meal_type) VALUES ('m1', 1780000000, 'LUNCH')",
    );
    // Put the file back in its schema-46 shape.
    await db.customStatement('ALTER TABLE meals DROP COLUMN trainer_comment');
    await db.customStatement('ALTER TABLE meals DROP COLUMN trainer_comment_at');
    await db.customStatement('PRAGMA user_version = 46');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    final meal = await db.select(db.meals).getSingle();
    expect(meal.clientId, 'm1');
    expect(meal.trainerComment, isNull);
    expect(meal.trainerCommentAt, isNull);

    // And the new columns are usable.
    await db.customUpdate(
      "UPDATE meals SET trainer_comment = 'More greens' WHERE client_id = 'm1'",
      variables: const <Variable>[],
    );
    expect((await db.select(db.meals).getSingle()).trainerComment, 'More greens');
    await db.close();
  });
}
