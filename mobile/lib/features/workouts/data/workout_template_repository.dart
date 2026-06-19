import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/local_db/app_database.dart';
import '../../../core/local_db/database_provider.dart';
import '../../../core/sync/client_id.dart';
import '../../../core/sync/client_ref.dart';
import '../../../core/sync/outbox_writer.dart';
import '../domain/workout_template.dart';

/// Local-first access to workout templates and their exercise links.
class WorkoutTemplateRepository {
  WorkoutTemplateRepository(this._db, this._outbox);

  final AppDatabase _db;
  final OutboxWriter _outbox;

  /// Joins templates with their exercise links — Drift tracks both tables
  /// for this query, so it re-emits on a change to either side.
  Stream<List<WorkoutTemplate>> watchAll() {
    final query = _db.select(_db.workoutTemplates).join([
      leftOuterJoin(
        _db.workoutTemplateExercises,
        _db.workoutTemplateExercises.templateClientId.equalsExp(_db.workoutTemplates.clientId),
      ),
    ])
      ..orderBy([OrderingTerm.asc(_db.workoutTemplates.name)]);

    return query.watch().map((rows) {
      final templates = <String, WorkoutTemplateRow>{};
      final exerciseClientIds = <String, List<String>>{};
      for (final row in rows) {
        final template = row.readTable(_db.workoutTemplates);
        templates[template.clientId] = template;
        final link = row.readTableOrNull(_db.workoutTemplateExercises);
        if (link != null) {
          exerciseClientIds.putIfAbsent(template.clientId, () => []).add(link.exerciseClientId);
        }
      }
      return templates.values.map((t) => _toDomain(t, exerciseClientIds[t.clientId] ?? const [])).toList();
    });
  }

  Future<void> create({required String name, required List<String> exerciseClientIds}) async {
    final clientId = newClientId();
    await _db.transaction(() async {
      await _db.into(_db.workoutTemplates).insert(
            WorkoutTemplatesCompanion.insert(clientId: clientId, name: name),
          );
      await _insertLinks(clientId, exerciseClientIds);
    });
    await _outbox.enqueueCreate(
      clientId: clientId,
      entityType: 'workout_template',
      payload: _payload(name: name, exerciseClientIds: exerciseClientIds),
    );
  }

  Future<void> update(
    String clientId, {
    required String name,
    required List<String> exerciseClientIds,
  }) async {
    await _db.transaction(() async {
      await (_db.update(_db.workoutTemplates)..where((t) => t.clientId.equals(clientId)))
          .write(WorkoutTemplatesCompanion(name: Value(name)));
      await (_db.delete(_db.workoutTemplateExercises)
            ..where((t) => t.templateClientId.equals(clientId)))
          .go();
      await _insertLinks(clientId, exerciseClientIds);
    });
    await _outbox.enqueueUpdate(
      clientId: clientId,
      entityType: 'workout_template',
      payload: _payload(name: name, exerciseClientIds: exerciseClientIds),
    );
  }

  Future<void> delete(String clientId) async {
    await _db.transaction(() async {
      await (_db.delete(_db.workoutTemplateExercises)
            ..where((t) => t.templateClientId.equals(clientId)))
          .go();
      await (_db.delete(_db.workoutTemplates)..where((t) => t.clientId.equals(clientId))).go();
    });
    await _outbox.enqueueDelete(clientId: clientId, entityType: 'workout_template');
  }

  Future<void> _insertLinks(String templateClientId, List<String> exerciseClientIds) async {
    for (final exerciseClientId in exerciseClientIds) {
      await _db.into(_db.workoutTemplateExercises).insert(
            WorkoutTemplateExercisesCompanion.insert(
              clientId: newClientId(),
              templateClientId: templateClientId,
              exerciseClientId: exerciseClientId,
            ),
          );
    }
  }

  Map<String, dynamic> _payload({required String name, required List<String> exerciseClientIds}) {
    return {
      'name': name,
      'exerciseIds': exerciseClientIds.map(clientRef).toList(),
    };
  }

  WorkoutTemplate _toDomain(WorkoutTemplateRow row, List<String> exerciseClientIds) {
    return WorkoutTemplate(
      clientId: row.clientId,
      id: row.serverId,
      name: row.name,
      exerciseClientIds: exerciseClientIds,
    );
  }
}

final workoutTemplateRepositoryProvider = Provider<WorkoutTemplateRepository>((ref) {
  return WorkoutTemplateRepository(ref.watch(appDatabaseProvider), ref.watch(outboxWriterProvider));
});
