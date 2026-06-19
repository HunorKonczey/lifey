/// A reusable water-intake preset (`/water-sources`), e.g. "Creatine Shake" = 0.9L.
class WaterSource {
  const WaterSource({required this.id, required this.name, required this.volumeLiters});

  final int id;
  final String name;
  final double volumeLiters;

  factory WaterSource.fromJson(Map<String, dynamic> json) {
    return WaterSource(
      id: json['id'] as int,
      name: json['name'] as String,
      volumeLiters: (json['volumeLiters'] as num).toDouble(),
    );
  }
}
