import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/entitlements/history_cutoff.dart';

void main() {
  final earlier = DateTime(2026, 1, 1);
  final later = DateTime(2026, 6, 1);

  test('both null stays null (no restriction at all)', () {
    expect(combineHistoryCutoffs(null, null), isNull);
  });

  test('one null falls back to the other', () {
    expect(combineHistoryCutoffs(null, later), later);
    expect(combineHistoryCutoffs(earlier, null), earlier);
  });

  test('both non-null picks the later (more restrictive) one', () {
    expect(combineHistoryCutoffs(earlier, later), later);
    expect(combineHistoryCutoffs(later, earlier), later);
  });

  test('equal cutoffs return that same value', () {
    expect(combineHistoryCutoffs(earlier, earlier), earlier);
  });
}
