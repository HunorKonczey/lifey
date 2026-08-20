import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/workouts/domain/weather_condition.dart';
import 'package:lifey/l10n/app_localizations_en.dart';

/// docs/cardio/60 C8.6 — the client-side icon/label mapping for a session's
/// free-text `weatherCondition` code (unconstrained on the wire, same
/// precedent as `gameFormat`).
void main() {
  final l10n = AppLocalizationsEn();

  test('every code in kWeatherConditions maps to a distinct icon', () {
    final icons = kWeatherConditions.map(weatherConditionIcon).toSet();
    expect(icons, hasLength(kWeatherConditions.length));
  });

  test('every code in kWeatherConditions has a non-empty localized label', () {
    for (final code in kWeatherConditions) {
      expect(weatherConditionLabel(l10n, code), isNotEmpty);
    }
  });

  test('an unrecognized code falls back to cloud_off, not a crash', () {
    expect(weatherConditionIcon('SOMETHING_A_NEWER_SERVER_INVENTED'), Icons.cloud_off);
  });

  test('a null code (no data at all) also falls back to cloud_off', () {
    expect(weatherConditionIcon(null), Icons.cloud_off);
  });

  test('an unrecognized code falls back to the raw code as its own label', () {
    expect(weatherConditionLabel(l10n, 'FOG'), 'FOG');
  });
}
