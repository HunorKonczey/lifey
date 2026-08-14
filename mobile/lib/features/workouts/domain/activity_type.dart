import 'package:flutter/material.dart';

import '../../../core/location/location_service.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';

/// The three metric/UI shapes a cardio [ActivityType] falls into — see
/// docs/cardio/51-cardio-overview-plan.md §1.1. Drives the active-session
/// layout and which metrics are shown; never persisted directly, always
/// derived via [activityFamilyOf].
enum ActivityFamily {
  /// Running, walking, hiking — distance, pace, elevation, GPS route.
  distance,

  /// Indoor bike — cadence, power, resistance, no GPS.
  machine,

  /// Basketball, football — playing time vs. gross time, heart-rate zones.
  game,
}

/// All cardio ActivityType codes, display order — matches the picker order
/// in `design/Lifey Cardio Design.dc.html` M01. Mirrors the backend
/// `com.lifey.workout.session.cardio.ActivityType` enum by code string, not
/// by index — see [activityTypeLabel] for why this is a `String`, not a
/// Dart enum.
const List<String> kActivityTypes = [
  'RUNNING',
  'WALKING',
  'HIKING',
  'INDOOR_BIKE',
  'BASKETBALL',
  'FOOTBALL',
  'OTHER_CARDIO',
];

/// Returns the [ActivityFamily] for a cardio activity type code. Throws on
/// an unrecognized code — callers must only pass values from
/// [kActivityTypes] (never a raw, unvalidated server string; see
/// `WorkoutSession.activityType`, which stays nullable/unchecked upstream of
/// this call).
ActivityFamily activityFamilyOf(String activityType) {
  return switch (activityType) {
    'RUNNING' || 'WALKING' || 'HIKING' => ActivityFamily.distance,
    'INDOOR_BIKE' => ActivityFamily.machine,
    'BASKETBALL' || 'FOOTBALL' || 'OTHER_CARDIO' => ActivityFamily.game,
    _ => throw ArgumentError.value(activityType, 'activityType', 'Unknown ActivityType code'),
  };
}

/// The GPS accuracy/power tradeoff to record a DISTANCE-family activity type
/// at (docs/cardio/54-cardio-gps-route-plan.md §4.1) — running/hiking want
/// the tightest fix; walking tolerates a coarser, more battery-friendly one.
/// Only meaningful for `activityFamilyOf(activityType) == ActivityFamily.distance`
/// — callers outside that family never call `positionStream` at all.
LocationTrackingProfile locationTrackingProfileFor(String activityType) {
  return activityType == 'WALKING'
      ? LocationTrackingProfile.relaxed
      : LocationTrackingProfile.precise;
}

/// Localized label for a cardio activity type code, or for the sentinel
/// `'STRENGTH'` when a mixed list (e.g. the quick-start picker,
/// docs/cardio/53-cardio-mobile-plan.md §3.4) needs a label for the existing
/// set-based workout alongside cardio types.
String activityTypeLabel(AppLocalizations l10n, String code) {
  return switch (code) {
    'RUNNING' => l10n.activityTypeRunning,
    'WALKING' => l10n.activityTypeWalking,
    'HIKING' => l10n.activityTypeHiking,
    'INDOOR_BIKE' => l10n.activityTypeIndoorBike,
    'BASKETBALL' => l10n.activityTypeBasketball,
    'FOOTBALL' => l10n.activityTypeFootball,
    'STRENGTH' => l10n.activityTypeStrength,
    _ => l10n.activityTypeOtherCardio,
  };
}

/// Material icon for a cardio activity type code, or for `'STRENGTH'`.
/// Matches `design/Lifey Cardio Design.dc.html` M01 exactly.
IconData activityTypeIcon(String code) {
  return switch (code) {
    'RUNNING' => Icons.directions_run,
    'WALKING' => Icons.directions_walk,
    'HIKING' => Icons.hiking,
    'INDOOR_BIKE' => Icons.pedal_bike,
    'BASKETBALL' => Icons.sports_basketball,
    'FOOTBALL' => Icons.sports_soccer,
    'STRENGTH' => Icons.fitness_center,
    _ => Icons.bolt,
  };
}

/// Accent color for a cardio activity type code, or for `'STRENGTH'` —
/// matches `design/Lifey Cardio Design.dc.html` M01 §1 exactly, including
/// the two deliberate departures from the raw metric-color mapping:
/// - Hiking uses `colorScheme.tertiary` (forest green), not
///   `metricColors.protein` — the suggested protein-green *is* the app's
///   primary accent, so a hiking chip would look like every primary action
///   button instead of standing out.
/// - `OTHER_CARDIO` uses `colorScheme.onSurfaceVariant` (neutral grey) —
///   deliberately colorless, so the escape-hatch type never competes
///   visually with the six real types in a mixed list.
Color activityTypeColor(String code, BuildContext context) {
  final mc = context.metricColors;
  final scheme = Theme.of(context).colorScheme;
  return switch (code) {
    'RUNNING' => mc.calories,
    'WALKING' => mc.steps,
    'HIKING' => scheme.tertiary,
    'INDOOR_BIKE' => mc.carbs,
    'BASKETBALL' => mc.fat,
    'FOOTBALL' => mc.water,
    'STRENGTH' => mc.weight,
    _ => scheme.onSurfaceVariant,
  };
}
