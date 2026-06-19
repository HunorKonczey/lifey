/// Domain model for an exercise from the master list (`/exercises`).
class Exercise {
  const Exercise({required this.clientId, required this.name, this.id});

  final String clientId;
  final int? id;
  final String name;
}
