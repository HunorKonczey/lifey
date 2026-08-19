import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/format/cardio_formatter.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';

void main() {
  group('distance', () {
    test('metric renders km with 2 decimals', () {
      expect(CardioFormatter.distance(5230.5, UnitSystem.metric), '5.23 km');
    });

    test('imperial renders miles with 2 decimals', () {
      expect(CardioFormatter.distance(5230.5, UnitSystem.imperial), '3.25 mi');
    });
  });

  group('elevation', () {
    test('metric renders whole meters', () {
      expect(CardioFormatter.elevation(41.6, UnitSystem.metric), '42 m');
    });

    test('imperial renders whole feet', () {
      expect(CardioFormatter.elevation(42.0, UnitSystem.imperial), '138 ft');
    });
  });

  group('pace', () {
    test('metric renders min:sec per km', () {
      final pace = CardioFormatter.pace(5000, const Duration(minutes: 26), UnitSystem.metric);
      expect(pace, '5:12 /km');
    });

    test('imperial renders min:sec per mile', () {
      final pace = CardioFormatter.pace(5000, const Duration(minutes: 26), UnitSystem.imperial);
      expect(pace, '8:22 /mi');
    });

    test('returns null when distance is zero', () {
      expect(CardioFormatter.pace(0, const Duration(minutes: 10), UnitSystem.metric), isNull);
    });

    test('returns null when distance is negative', () {
      expect(CardioFormatter.pace(-5, const Duration(minutes: 10), UnitSystem.metric), isNull);
    });
  });

  group('speed', () {
    test('metric renders km/h with 1 decimal', () {
      final speed = CardioFormatter.speed(11400, const Duration(hours: 1), UnitSystem.metric);
      expect(speed, '11.4 km/h');
    });

    test('imperial renders mph with 1 decimal', () {
      final speed = CardioFormatter.speed(11400, const Duration(hours: 1), UnitSystem.imperial);
      expect(speed, '7.1 mph');
    });

    test('returns null when duration is zero', () {
      expect(CardioFormatter.speed(5000, Duration.zero, UnitSystem.metric), isNull);
    });
  });

  group('totalWorkKj (docs/cardio/61 §3 M39, docs/cardio/51 §3.3)', () {
    test('is average power over the time it was held', () {
      // 168 W for 30:00 = 302.4 kJ.
      expect(CardioFormatter.totalWorkKj(168, 1800), 302);
    });

    test('is null without power — the number it would print is not a zero', () {
      expect(CardioFormatter.totalWorkKj(null, 1800), isNull);
      expect(CardioFormatter.totalWorkKj(0, 1800), isNull);
    });

    test('is null without a moving time to hold that power over', () {
      expect(CardioFormatter.totalWorkKj(168, null), isNull);
      expect(CardioFormatter.totalWorkKj(168, 0), isNull);
    });

    test('follows a corrected average, since nothing stores the result', () {
      // The rider fixes the average power on the summary from 168 to 200:
      // the work has to move with it, which is only true while it is derived.
      expect(CardioFormatter.totalWorkKj(200, 1800), 360);
    });
  });

  group('duration', () {
    test('renders m:ss under an hour without a leading zero', () {
      expect(CardioFormatter.duration(const Duration(minutes: 5, seconds: 12)), '5:12');
    });

    test('renders h:mm:ss from an hour up', () {
      expect(
        CardioFormatter.duration(const Duration(hours: 1, minutes: 5, seconds: 12)),
        '1:05:12',
      );
    });

    test('pads seconds under 10 with a leading zero', () {
      expect(CardioFormatter.duration(const Duration(minutes: 3, seconds: 4)), '3:04');
    });
  });
}
