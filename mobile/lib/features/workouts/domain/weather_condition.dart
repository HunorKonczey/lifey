import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// The fixed set of weather condition codes the app's own manual-entry
/// picker offers (docs/cardio/60 C8.6, Q-C8.1) — `CardioMetrics.weatherCondition`
/// itself is a free, unconstrained string on the wire (same precedent as
/// `gameFormat`), so an older/newer client sending a code outside this list
/// is never a parse error, just an icon this client doesn't recognize
/// ([weatherConditionIcon] falls back to [Icons.cloud_off] for it).
const List<String> kWeatherConditions = [
  'CLEAR',
  'PARTLY_CLOUDY',
  'CLOUDY',
  'RAIN',
  'SNOW',
  'WINDY',
];

/// Material icon for a weather condition code — matches
/// `design/Lifey Cardio Sport-specifikumok.dc.html` M42 (`partly_cloudy_day`
/// there maps to [Icons.wb_cloudy] here, the closest bundled equivalent).
/// An unrecognized/null code — including "no weather data at all" — gets
/// the same [Icons.cloud_off] the M42 empty state itself uses.
IconData weatherConditionIcon(String? code) {
  return switch (code) {
    'CLEAR' => Icons.wb_sunny,
    'PARTLY_CLOUDY' => Icons.wb_cloudy,
    'CLOUDY' => Icons.cloud,
    'RAIN' => Icons.water_drop,
    'SNOW' => Icons.ac_unit,
    'WINDY' => Icons.air,
    _ => Icons.cloud_off,
  };
}

/// Localized label for a weather condition code.
String weatherConditionLabel(AppLocalizations l10n, String code) {
  return switch (code) {
    'CLEAR' => l10n.weatherConditionClear,
    'PARTLY_CLOUDY' => l10n.weatherConditionPartlyCloudy,
    'CLOUDY' => l10n.weatherConditionCloudy,
    'RAIN' => l10n.weatherConditionRain,
    'SNOW' => l10n.weatherConditionSnow,
    'WINDY' => l10n.weatherConditionWindy,
    _ => code,
  };
}
