/// Domain model for an exercise from the master list (`/exercises`).
class Exercise {
  const Exercise({required this.id, required this.name});

  final int id;
  final String name;

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(id: json['id'] as int, name: json['name'] as String);
  }
}
