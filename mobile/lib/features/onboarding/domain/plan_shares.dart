/// How the suggested plan's macros split the energy — the "22 % / 53 % / 25 %"
/// under the ratio bar.
///
/// Shares are of the calories the three macros themselves add up to (protein
/// and carbs 4 kcal/g, fat 9 kcal/g), so they always total 100 — the plan's
/// own calorie figure is rounded and would leave 99 or 101. Rounded by the
/// largest remainder, so the parts never drift from the whole.
List<int> macroPercents({required int proteinGrams, required int carbsGrams, required int fatGrams}) {
  final kcal = [proteinGrams * 4.0, carbsGrams * 4.0, fatGrams * 9.0];
  final total = kcal.fold<double>(0, (a, b) => a + b);
  if (total <= 0) return const [0, 0, 0];
  final exact = [for (final k in kcal) k / total * 100];
  final floors = [for (final e in exact) e.floor()];
  var left = 100 - floors.fold<int>(0, (a, b) => a + b);
  final order = List.generate(3, (i) => i)..sort((a, b) => (exact[b] - floors[b]).compareTo(exact[a] - floors[a]));
  for (final i in order) {
    if (left <= 0) break;
    floors[i]++;
    left--;
  }
  return floors;
}

/// The suggested calories against the TDEE, as a signed whole percent
/// (+10 = a 10 % surplus); 0 when it rounds to nothing.
int calorieAdjustmentPercent({required int calories, required int tdee}) {
  if (tdee <= 0) return 0;
  return ((calories / tdee - 1) * 100).round();
}
