import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/weight/domain/weight_entry.dart';

/// `takenAt` (LIF-115): the time of day belongs next to the date only when the entry was taken on that day.
void main() {
  WeightEntry entry({required DateTime date, required DateTime recordedAt}) =>
      WeightEntry(clientId: 'w', date: date, weight: 70, recordedAt: recordedAt);

  test('an entry taken on its own day has a time', () {
    final taken = DateTime(2026, 6, 18, 7, 2);
    expect(entry(date: DateTime(2026, 6, 18), recordedAt: taken).takenAt, taken);
  });

  test('a back-dated entry has none: logged today, for another day', () {
    expect(entry(date: DateTime(2026, 6, 15), recordedAt: DateTime(2026, 6, 18, 9, 30)).takenAt, isNull);
  });

  test('the day is compared in local time, so a UTC instant late in the evening still matches', () {
    final local = DateTime(2026, 6, 18, 23, 40);
    expect(entry(date: DateTime(2026, 6, 18), recordedAt: local.toUtc()).takenAt?.toLocal(), local);
  });
}
