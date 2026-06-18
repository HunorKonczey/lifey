/// Domain model for a body weight entry.
class WeightEntry {
  const WeightEntry({
    required this.id,
    required this.date,
    required this.weight,
  });

  final int id;
  final DateTime date;
  final double weight;
}
