import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/local_db/app_database.dart';
import '../../../core/local_db/database_provider.dart';
import '../../../core/sync/client_id.dart';
import '../../../core/sync/client_ref.dart';
import '../../../core/sync/outbox_writer.dart';
import '../../../core/sync/pending_delete_filter.dart';
import '../../../core/utils/combine_latest.dart';
import '../domain/workout_template.dart' show WorkoutTemplate, TemplateExercise;

/// Local-first access to workout templates and their exercise links.
class WorkoutTemplateRepository {
  WorkoutTemplateRepository(this._db, this._outbox);

  final AppDatabase _db;
  final OutboxWriter _outbox;

  /// Joins templates with their exercise links — Drift tracks both tables
  /// for this query, so it re-emits on a change to either side. Combined
  /// with `pending_operations` so a template with a delete in flight (see
  /// [delete]) is filtered out without waiting on a second, separately
  /// timed provider rebuild.
  Stream<List<WorkoutTemplate>> watchAll() {
    final query = _db.select(_db.workoutTemplates).join([
      leftOuterJoin(
        _db.workoutTemplateExercises,
        _db.workoutTemplateExercises.templateClientId.equalsExp(_db.workoutTemplates.clientId),
      ),
    ])
      ..orderBy([
        OrderingTerm.asc(_db.workoutTemplates.name),
        OrderingTerm.asc(_db.workoutTemplateExercises.sortOrder),
      ]);

    final pendingOps$ = _db.select(_db.pendingOperations).watch();
    return combineLatest2(query.watch(), pendingOps$, (rows, ops) {
      final blocked = blockedByActiveDelete(ops);
      final templates = <String, WorkoutTemplateRow>{};
      final exerciseLinks = <String, List<WorkoutTemplateExerciseRow>>{};
      for (final row in rows) {
        final template = row.readTable(_db.workoutTemplates);
        if (blocked.contains(template.clientId)) continue;
        templates[template.clientId] = template;
        final link = row.readTableOrNull(_db.workoutTemplateExercises);
        if (link != null) {
          exerciseLinks.putIfAbsent(template.clientId, () => []).add(link);
        }
      }
      return templates.values
          .map((t) => _toDomain(t, exerciseLinks[t.clientId] ?? const []))
          .toList();
    });
  }

  Future<void> create({required String name, required List<TemplateExercise> exercises}) async {
    final clientId = newClientId();
    await _db.transaction(() async {
      await _db.into(_db.workoutTemplates).insert(
            WorkoutTemplatesCompanion.insert(clientId: clientId, name: name),
          );
      await _insertLinks(clientId, exercises);
    });
    await _outbox.enqueueCreate(
      clientId: clientId,
      entityType: 'workout_template',
      payload: _payload(name: name, exercises: exercises),
    );
  }

  Future<void> update(
    String clientId, {
    required String name,
    required List<TemplateExercise> exercises,
  }) async {
    await _db.transaction(() async {
      await (_db.update(_db.workoutTemplates)..where((t) => t.clientId.equals(clientId)))
          .write(WorkoutTemplatesCompanion(name: Value(name)));
      await (_db.delete(_db.workoutTemplateExercises)
            ..where((t) => t.templateClientId.equals(clientId)))
          .go();
      await _insertLinks(clientId, exercises);
    });
    await _outbox.enqueueUpdate(
      clientId: clientId,
      entityType: 'workout_template',
      payload: _payload(name: name, exercises: exercises),
    );
  }

  Future<void> delete(String clientId) async {
    // Must enqueue before the local row is gone — enqueueDelete needs to
    // read its serverId while the row still exists. If it queued a server
    // delete, the template and its exercise links stay (hidden by the
    // controller's filter) until that delete is confirmed — see
    // EntitySyncConfig.cleanupChildren's doc.
    final queued =
        await _outbox.enqueueDelete(clientId: clientId, entityType: 'workout_template');
    if (!queued) {
      await _db.transaction(() async {
        await (_db.delete(_db.workoutTemplateExercises)
              ..where((t) => t.templateClientId.equals(clientId)))
            .go();
        await (_db.delete(_db.workoutTemplates)..where((t) => t.clientId.equals(clientId))).go();
      });
    }
  }

  Future<void> _insertLinks(String templateClientId, List<TemplateExercise> exercises) async {
    for (var i = 0; i < exercises.length; i++) {
      await _db.into(_db.workoutTemplateExercises).insert(
            WorkoutTemplateExercisesCompanion.insert(
              clientId: newClientId(),
              templateClientId: templateClientId,
              exerciseClientId: exercises[i].exerciseClientId,
              targetSets: Value(exercises[i].targetSets),
              sortOrder: Value(i),
            ),
          );
    }
  }

  Map<String, dynamic> _payload({required String name, required List<TemplateExercise> exercises}) {
    return {
      'name': name,
      'exercises': exercises
          .map((e) => {'exerciseId': clientRef(e.exerciseClientId), 'targetSets': e.targetSets})
          .toList(),
    };
  }

  WorkoutTemplate _toDomain(WorkoutTemplateRow row, List<WorkoutTemplateExerciseRow> links) {
    return WorkoutTemplate(
      clientId: row.clientId,
      id: row.serverId,
      name: row.name,
      exercises: links
          .map((l) => TemplateExercise(
                exerciseClientId: l.exerciseClientId,
                targetSets: l.targetSets,
              ))
          .toList(),
    );
  }
}

final workoutTemplateRepositoryProvider = Provider<WorkoutTemplateRepository>((ref) {
  return WorkoutTemplateRepository(ref.watch(appDatabaseProvider), ref.watch(outboxWriterProvider));
});
