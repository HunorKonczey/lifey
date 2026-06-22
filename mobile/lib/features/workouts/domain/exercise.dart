/// Domain model for an exercise from the master list (`/exercises`).
class Exercise {
  const Exercise({required this.clientId, required this.name, this.id});

  final String clientId;
  final int? id;
  final String name;

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
