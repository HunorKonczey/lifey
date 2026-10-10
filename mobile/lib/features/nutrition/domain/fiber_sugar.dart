/// A meal's or a day's fibre and sugars (LIF-148). A food can have no figure ("not known" is not zero), so a total is the sum of
/// what is known: a null part when no entry has one (nothing to show), and [partial] when only some do - the line then says so
/// rather than passing a lower number off as the whole. Same rule as the web's `fiberSugar.ts`.
class FiberSugarTotals {
  const FiberSugarTotals({this.fiber, this.sugar, this.partial = false});

  /// Sums [entries]; each is the entry's own fibre and sugar (already scaled to its grams), null when the food has no figure.
  factory FiberSugarTotals.of(Iterable<({double? fiber, double? sugar})> entries) {
    double? fiber;
    double? sugar;
    var anyMissing = false;
    for (final e in entries) {
      if (e.fiber != null) fiber = (fiber ?? 0) + e.fiber!;
      if (e.sugar != null) sugar = (sugar ?? 0) + e.sugar!;
      if (e.fiber == null || e.sugar == null) anyMissing = true;
    }
    return FiberSugarTotals(fiber: fiber, sugar: sugar, partial: anyMissing && (fiber != null || sugar != null));
  }

  final double? fiber;
  final double? sugar;

  /// Some entry's food has no figure, so the numbers are a lower bound.
  final bool partial;

  /// Nothing to show: no food has either figure.
  bool get isEmpty => fiber == null && sugar == null;
}
