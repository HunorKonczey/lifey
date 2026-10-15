import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:path/path.dart' as p;

/// LIF-170 added `recipe_client_id` to `meal_entries` in schema 53 (docs/88). A phone on 52 has entries logged already:
/// the upgrade must add the column and keep every one of them, untagged.
void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('lifey_meal_entry_recipe_migration');
    file = File(p.join(dir.path, 'lifey.sqlite'));
  });

  tearDown(() async => dir.delete(recursive: true));

  test('upgrading from schema 52 adds the column and keeps the logged entries', () async {
    var db = AppDatabase(NativeDatabase(file));
    await db.customStatement("INSERT INTO foods (client_id, name, calories_per100g, protein_per100g) VALUES ('f1', 'Oats', 380, 13)");
    await db.customStatement("INSERT INTO meals (client_id, meal_date_time, meal_type) VALUES ('m1', 1780000000, 'LUNCH')");
    await db.customStatement(
      "INSERT INTO meal_entries (client_id, meal_client_id, food_client_id, quantity_in_grams) VALUES ('e1', 'm1', 'f1', 80)",
    );
    // Put the file back in its schema-52 shape.
    await db.customStatement('ALTER TABLE meal_entries DROP COLUMN recipe_client_id');
    await db.customStatement('PRAGMA user_version = 52');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    final entry = await db.select(db.mealEntries).getSingle();
    expect(entry.clientId, 'e1');
    expect(entry.quantityInGrams, 80);
    expect(entry.recipeClientId, isNull);

    // And the new column is usable.
    await db.customStatement("UPDATE meal_entries SET recipe_client_id = 'r1' WHERE client_id = 'e1'");
    expect((await db.select(db.mealEntries).getSingle()).recipeClientId, 'r1');
    await db.close();
  });
}
