/// The value of the log-weight sheet, held as **whole grams**.
///
/// Stepping ±0.1 kg on a `double` drifts (64.5 + 0.1 + 0.1 + … ends at
/// 64.699999…), and the drift shows up in the saved entry and in "−0.1" chips
/// that read "−0.09999". Integer grams add and subtract exactly; the kilogram
/// `double` only exists at the edges — display and save — as `grams / 1000`,
/// which is the correctly rounded double nearest the value typed
/// (docs/redesign/77-mobile-redesign-plan.md R4.4).
class WeightAmount {
  const WeightAmount._(this.grams);

  /// The step of the ± buttons: 0.1 kg.
  static const int stepGrams = 100;

  /// The smallest and largest weight the sheet accepts.
  static const int minGrams = 1000;
  static const int maxGrams = 500000;

  final int grams;

  /// From a weight in kilograms (what the entries store), to the gram.
  factory WeightAmount.fromKg(double kg) => WeightAmount._((kg * 1000).round().clamp(minGrams, maxGrams));

  /// From what the user typed — "64.5", "64,5", "64" — or null when it is not
  /// a weight this sheet accepts (not a number, ≤ 0, over 500 kg).
  static WeightAmount? tryParse(String text) {
    final kg = double.tryParse(text.trim().replaceAll(',', '.'));
    if (kg == null || !kg.isFinite) return null;
    final grams = (kg * 1000).round();
    if (grams < minGrams || grams > maxGrams) return null;
    return WeightAmount._(grams);
  }

  double get kg => grams / 1000;

  /// One ± step up ([direction] 1) or down (-1), stopping at the limits.
  WeightAmount step(int direction) =>
      WeightAmount._((grams + direction * stepGrams).clamp(minGrams, maxGrams));

  bool get canStepDown => grams - stepGrams >= minGrams;
  bool get canStepUp => grams + stepGrams <= maxGrams;

  @override
  bool operator ==(Object other) => other is WeightAmount && other.grams == grams;

  @override
  int get hashCode => grams.hashCode;
}
