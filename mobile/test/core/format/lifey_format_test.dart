import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lifey/core/format/lifey_format.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('hu');
  });

  final en = LifeyFormat('en');
  final hu = LifeyFormat('hu');

  // Hungarian groups with a no-break space (intl's `hu` symbols).
  String nb(String s) => s.replaceAll(' ', ' ');

  group('integers', () {
    test('group thousands per locale', () {
      expect(en.integer(1739), '1,739');
      expect(hu.integer(1739), nb('1 739'));
      expect(en.integer(255960), '255,960');
      expect(hu.integer(255960), nb('255 960'));
    });

    test('kcal is always whole — the canvas example 17518.6', () {
      expect(en.kcal(17518.6), '17,519');
      expect(hu.kcal(17518.6), nb('17 519'));
      expect(en.kcal(999.5), '1,000');
      expect(en.grams(28.4), '28');
    });

    test('small and negative numbers', () {
      expect(en.integer(0), '0');
      expect(en.integer(-212), '-212');
      expect(hu.integer(621), '621');
    });
  });

  group('decimals', () {
    test('weight has one decimal, with the locale separator', () {
      expect(en.weight(64.5), '64.5');
      expect(hu.weight(64.5), '64,5');
      expect(en.weight(64), '64.0');
      expect(en.weight(999.95), '1,000.0');
    });

    test('distance has two decimals', () {
      expect(en.distance(5.2104), '5.21');
      expect(hu.distance(5.2), '5,20');
    });

    test('litres show one or two decimals', () {
      expect(en.litres(2.6), '2.6');
      expect(en.litres(0.25), '0.25');
      expect(en.litres(1), '1.0');
      expect(en.litres(0.994), '0.99');
      expect(hu.litres(2.6), '2,6');
    });

    test('percent', () {
      expect(en.percent(0.26), '26%');
      expect(hu.percent(0.26), '26%');
    });
  });

  group('signedDelta', () {
    test('real minus sign for losses, plus for gains', () {
      expect(en.signedDelta(-0.1), '−0.1');
      expect(en.signedDelta(2.5), '+2.5');
      expect(hu.signedDelta(-1.4), '−1,4');
    });

    test('no sign on a change that rounds to zero', () {
      expect(en.signedDelta(0), '0.0');
      expect(en.signedDelta(-0.04), '0.0');
      expect(en.signedDelta(0.04), '0.0');
    });

    test('whole-number deltas', () {
      expect(en.signedDelta(4, digits: 0), '+4');
      expect(en.signedDelta(-1234, digits: 0), '−1,234');
      expect(en.signedDelta(0.4, digits: 0), '0');
    });
  });

  group('compactAxis', () {
    test('matches the canvas axes', () {
      expect(en.compactAxis(0), '0');
      expect(en.compactAxis(650), '650');
      expect(en.compactAxis(1200), '1.2k');
      expect(en.compactAxis(2400), '2.4k');
      expect(en.compactAxis(6500), '6.5k');
      expect(en.compactAxis(13000), '13k');
      expect(hu.compactAxis(2400), '2,4k');
    });
  });

  group('dates', () {
    // Thursday, 24 September 2026 — the canvases' "today".
    final thu = DateTime(2026, 9, 24, 7, 15);

    test('day label', () {
      expect(en.dayLabel(thu), 'Thursday, 24 Sep');
      expect(hu.dayLabel(thu), 'Csütörtök, szeptember 24.');
    });

    test('short day label', () {
      expect(en.shortDayLabel(thu), 'Thu, 24 Sep');
      expect(hu.shortDayLabel(thu), startsWith('Cs'));
      expect(hu.shortDayLabel(thu), endsWith('szept. 24.'));
    });

    test('time is 24-hour in both languages', () {
      expect(en.time(thu), '07:15');
      expect(hu.time(thu), '07:15');
    });

    test('narrow weekday — Hungarian stays unambiguous across a week', () {
      expect(en.weekdayNarrow(thu), 'T');
      final monday = DateTime(2026, 9, 21);
      final week = [for (var d = 0; d < 7; d++) hu.weekdayNarrow(monday.add(Duration(days: d)))];
      expect(week, ['H', 'K', 'Sze', 'Cs', 'P', 'Szo', 'V']);
    });

    test('short day label, Hungarian', () {
      expect(hu.shortDayLabel(thu), 'Cs, szept. 24.');
    });

    test('Hungarian never leaks English day names', () {
      for (var d = 0; d < 7; d++) {
        final day = thu.add(Duration(days: d));
        expect(hu.dayLabel(day), isNot(matches(RegExp('Mon|Tue|Wed|Thu|Fri|Sat|Sun'))));
      }
    });
  });

  test('locale tags with a region still count as Hungarian', () {
    expect(LifeyFormat('hu-HU').dayLabel(DateTime(2026, 9, 24)), 'Csütörtök, szeptember 24.');
  });
}
