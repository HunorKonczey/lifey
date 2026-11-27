import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/sleep/domain/sleep_session.dart';

/// docs/integrations/89 D-G7: a night counts for the date it ended on, and
/// the main sleep is the longest session of that date.
void main() {
  SleepSession session(String id, DateTime start, DateTime end, {int? deep}) =>
      SleepSession(clientId: id, startedAt: start, endedAt: end, deepMinutes: deep);

  test('a sleep across midnight belongs to the morning it ended', () {
    final s = session('n', DateTime(2026, 11, 20, 23, 30), DateTime(2026, 11, 21, 7));

    expect(s.wakeDate, DateTime(2026, 11, 21));
    expect(s.duration, const Duration(hours: 7, minutes: 30));
  });

  test('hasStages is true only when a stage was recorded', () {
    expect(session('a', DateTime(2026, 11, 20, 23), DateTime(2026, 11, 21, 7)).hasStages, isFalse);
    expect(session('b', DateTime(2026, 11, 20, 23), DateTime(2026, 11, 21, 7), deep: 0).hasStages, isTrue);
  });

  test('mainSleepFor picks the longest session of the date and ignores the nap', () {
    final night = session('night', DateTime(2026, 11, 20, 23), DateTime(2026, 11, 21, 6, 30));
    final nap = session('nap', DateTime(2026, 11, 21, 14), DateTime(2026, 11, 21, 14, 40));
    final previous = session('prev', DateTime(2026, 11, 19, 22), DateTime(2026, 11, 20, 8));

    expect(mainSleepFor([nap, night, previous], DateTime(2026, 11, 21))!.clientId, 'night');
    expect(mainSleepFor([nap, night, previous], DateTime(2026, 11, 20, 18))!.clientId, 'prev');
    expect(mainSleepFor([nap, night, previous], DateTime(2026, 11, 22)), isNull);
  });

  group('history helpers (G2.6)', () {
    final night = session('night', DateTime(2026, 11, 20, 23), DateTime(2026, 11, 21, 6, 30));
    final nap = session('nap', DateTime(2026, 11, 21, 14), DateTime(2026, 11, 21, 14, 40));
    final earlier = session('earlier', DateTime(2026, 11, 16, 23), DateTime(2026, 11, 17, 7));
    final old = session('old', DateTime(2026, 11, 9, 23), DateTime(2026, 11, 10, 6));

    test('isNap is true for every session but the main sleep of its day', () {
      final all = [nap, night, earlier];
      expect(isNap(nap, all), isTrue);
      expect(isNap(night, all), isFalse);
      expect(isNap(earlier, all), isFalse);
    });

    test('sleepAverage averages the main sleeps of the last 7 dates, naps and older nights left out', () {
      // 21 Nov: 7:30, 17 Nov: 8:00 -> 7:45 over 2 nights; 10 Nov is 11 days back.
      final average = sleepAverage([nap, night, earlier, old], DateTime(2026, 11, 21, 20))!;

      expect(average.nights, 2);
      expect(average.average, const Duration(hours: 7, minutes: 45));
      expect(sleepAverage([old], DateTime(2026, 11, 21)), isNull);
    });

    test('sessionsByWeek groups by the Monday of the wake-up day, newest week first', () {
      final weeks = sessionsByWeek([nap, night, earlier, old]);

      expect(weeks.map((w) => w.start), [DateTime(2026, 11, 16), DateTime(2026, 11, 9)]);
      expect(weeks.first.sessions.map((s) => s.clientId), ['nap', 'night', 'earlier']);
      expect(weekStartOf(DateTime(2026, 11, 22, 23)), DateTime(2026, 11, 16));
    });
  });
}
