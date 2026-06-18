/// Domain model for a body weight entry (`/weights`).
class WeightEntry {
  const WeightEntry({
    required this.id,
    required this.date,
    required this.weight,
  });

  final int id;
  final DateTime date;
  final double weight;

  factory WeightEntry.fromJson(Map<String, dynamic> json) {
    return WeightEntry(
      id: json['id'] as int,
      date: DateTime.parse(json['date'] as String),
      weight: (json['weight'] as num).toDouble(),
    );
  }
}
