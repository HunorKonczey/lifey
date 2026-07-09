/// Domain model for an exercise from the master list (`/exercises`).
class Exercise {
  const Exercise({
    required this.clientId,
    required this.name,
    this.id,
    this.category,
    this.equipment,
    this.description,
  });

  final String clientId;
  final int? id;
  final String name;

  /// Muscle group enum code from the backend (e.g. "CHEST"), null if not set.
  final String? category;

  /// Equipment enum code from the backend (e.g. "BARBELL"), null if not set.
  final String? equipment;

  /// Free-text notes (e.g. machine setting), null if not set.
  final String? description;

  /// Value equality by [clientId]: `DropdownButtonFormField<Exercise>`
  /// (add_set_sheet.dart) matches its `initialValue` against `items` by
  /// `==`, and the live exercises list re-emits brand-new instances on every
  /// otherwise-unrelated pending-operation write (ExerciseRepository.watchAll
  /// combines with the outbox table) — identity equality would make that
  /// dropdown intermittently fail to find a match while a sheet is open.
  @override
  bool operator ==(Object other) => other is Exercise && other.clientId == clientId;

  @override
  int get hashCode => clientId.hashCode;
}
