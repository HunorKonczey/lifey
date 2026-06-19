/// A reusable water-intake preset (`/water-sources`), e.g. "Creatine Shake" = 0.9L.
class WaterSource {
  const WaterSource({required this.clientId, required this.name, required this.volumeLiters, this.id});

  final String clientId;
  final int? id;
  final String name;
  final double volumeLiters;
}
