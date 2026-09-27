import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';

void main() {
  const none = UserSettings.defaults();

  test('an account without a step goal gets the 10 000 default', () {
    expect(none.dailyStepGoal, isNull);
    expect(none.effectiveDailyStepGoal, 10000);
    expect(UserSettings.defaultDailyStepGoal, 10000);
  });

  test('its own goal wins over the default', () {
    expect(none.copyWith(dailyStepGoal: 8000).effectiveDailyStepGoal, 8000);
  });

  test('a stored zero is not a goal — the default applies instead of dividing by zero', () {
    expect(none.copyWith(dailyStepGoal: 0).effectiveDailyStepGoal, 10000);
  });
}
