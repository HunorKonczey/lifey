import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/local_db/app_database.dart';
import '../../../core/local_db/database_provider.dart';
import '../../../core/sync/outbox_writer.dart';
import '../domain/user_settings.dart';

/// Local-first access to the per-user settings singleton. There's only ever
/// one local row (fixed [_clientId] — one user per device cache); the
/// backend itself has no separate create, just a lazy-create GET and a PUT,
/// so every save is queued as an `update` regardless of whether a row has
/// synced before.
class SettingsRepository {
  SettingsRepository(this._db, this._outbox);

  final AppDatabase _db;
  final OutboxWriter _outbox;

  static const _clientId = 'singleton';

  Stream<UserSettings> watch() {
    return (_db.select(_db.userSettingsTable)..where((t) => t.clientId.equals(_clientId)))
        .watchSingleOrNull()
        .map((row) => row == null ? const UserSettings.defaults() : _toDomain(row));
  }

  Future<void> save(UserSettings settings) async {
    final existing = await (_db.select(_db.userSettingsTable)
          ..where((t) => t.clientId.equals(_clientId)))
        .getSingleOrNull();

    final values = UserSettingsTableCompanion(
      unitSystem: Value(settings.unitSystem.name.toUpperCase()),
      theme: Value(settings.theme.name.toUpperCase()),
      language: Value(settings.language.name.toUpperCase()),
      dailyCalorieGoal: Value(settings.dailyCalorieGoal),
      dailyProteinGoal: Value(settings.dailyProteinGoal),
      dailyCarbsGoal: Value(settings.dailyCarbsGoal),
      dailyFatGoal: Value(settings.dailyFatGoal),
      dailyWaterGoalLiters: Value(settings.dailyWaterGoalLiters),
      dailyStepGoal: Value(settings.dailyStepGoal),
      workoutReminderEnabled: Value(settings.workoutReminderEnabled),
      trainerCommentPushEnabled: Value(settings.trainerCommentPushEnabled),
      trainerGoalsPushEnabled: Value(settings.trainerGoalsPushEnabled),
      programAssignedPushEnabled: Value(settings.programAssignedPushEnabled),
      restTimerEnabled: Value(settings.restTimerEnabled),
      defaultRestSeconds: Value(settings.defaultRestSeconds),
    );

    if (existing == null) {
      await _db.into(_db.userSettingsTable).insert(values.copyWith(clientId: const Value(_clientId)));
    } else {
      await (_db.update(_db.userSettingsTable)..where((t) => t.clientId.equals(_clientId)))
          .write(values);
    }
    await _outbox.enqueueUpdate(clientId: _clientId, entityType: 'user_settings', payload: settings.toJson());
  }

  UserSettings _toDomain(UserSettingsRow row) {
    return UserSettings(
      unitSystem: UnitSystem.values.byName(row.unitSystem.toLowerCase()),
      theme: ThemePreference.values.byName(row.theme.toLowerCase()),
      language: LanguagePreference.values.byName(row.language.toLowerCase()),
      dailyCalorieGoal: row.dailyCalorieGoal,
      dailyProteinGoal: row.dailyProteinGoal,
      dailyCarbsGoal: row.dailyCarbsGoal,
      dailyFatGoal: row.dailyFatGoal,
      dailyWaterGoalLiters: row.dailyWaterGoalLiters,
      dailyStepGoal: row.dailyStepGoal,
      workoutReminderEnabled: row.workoutReminderEnabled,
      trainerCommentPushEnabled: row.trainerCommentPushEnabled,
      trainerGoalsPushEnabled: row.trainerGoalsPushEnabled,
      programAssignedPushEnabled: row.programAssignedPushEnabled,
      restTimerEnabled: row.restTimerEnabled,
      defaultRestSeconds: row.defaultRestSeconds,
    );
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(appDatabaseProvider), ref.watch(outboxWriterProvider));
});
