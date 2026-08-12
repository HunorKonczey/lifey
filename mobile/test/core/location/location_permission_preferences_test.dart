import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/location/location_permission_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('hasSeenGpsExplainer() defaults to false', () async {
    expect(await LocationPermissionPreferences().hasSeenGpsExplainer(), isFalse);
  });

  test('setSeenGpsExplainer() persists true', () async {
    final prefs = LocationPermissionPreferences();
    await prefs.setSeenGpsExplainer();
    expect(await prefs.hasSeenGpsExplainer(), isTrue);
  });

  test('a fresh instance reads back what a prior instance wrote (device-local, not in-memory only)',
      () async {
    await LocationPermissionPreferences().setSeenGpsExplainer();
    expect(await LocationPermissionPreferences().hasSeenGpsExplainer(), isTrue);
  });

  test('clear() resets to unseen — fresh start for whoever logs in next', () async {
    final prefs = LocationPermissionPreferences();
    await prefs.setSeenGpsExplainer();
    await prefs.clear();
    expect(await prefs.hasSeenGpsExplainer(), isFalse);
  });
}
