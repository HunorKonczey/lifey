import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/streaks/data/recap_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('lastSeenRecapWeekStart is null before anything is marked seen', () async {
    final prefs = RecapPreferences();
    expect(await prefs.lastSeenRecapWeekStart(), isNull);
  });

  test('markRecapSeen persists the week, read back by a new instance', () async {
    final weekStart = DateTime(2026, 6, 1);
    await RecapPreferences().markRecapSeen(weekStart);

    final lastSeen = await RecapPreferences().lastSeenRecapWeekStart();
    expect(lastSeen, weekStart);
  });

  test('marking a later week overwrites the previously seen one', () async {
    final prefs = RecapPreferences();
    await prefs.markRecapSeen(DateTime(2026, 6, 1));
    await prefs.markRecapSeen(DateTime(2026, 6, 8));

    expect(await prefs.lastSeenRecapWeekStart(), DateTime(2026, 6, 8));
  });
}
