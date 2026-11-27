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
}
