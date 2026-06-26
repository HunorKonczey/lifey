import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';

/// All MuscleGroup codes in display order.
const List<String> kMuscleGroups = [
  'CHEST',
  'BACK',
  'SHOULDERS',
  'BICEPS',
  'TRICEPS',
  'FOREARMS',
  'QUADS',
  'HAMSTRINGS',
  'GLUTES',
  'CALVES',
  'ABS',
  'CARDIO',
  'FULL_BODY',
  'OTHER',
];

/// All Equipment codes in display order.
const List<String> kEquipments = [
  'BARBELL',
  'DUMBBELL',
  'MACHINE',
  'CABLE',
  'BODYWEIGHT',
  'SMITH_MACHINE',
  'OTHER',
];

String muscleGroupLabel(AppLocalizations l10n, String code) {
  return switch (code) {
    'CHEST' => l10n.muscleGroupChest,
    'BACK' => l10n.muscleGroupBack,
    'SHOULDERS' => l10n.muscleGroupShoulders,
    'BICEPS' => l10n.muscleGroupBiceps,
    'TRICEPS' => l10n.muscleGroupTriceps,
    'FOREARMS' => l10n.muscleGroupForearms,
    'QUADS' => l10n.muscleGroupQuads,
    'HAMSTRINGS' => l10n.muscleGroupHamstrings,
    'GLUTES' => l10n.muscleGroupGlutes,
    'CALVES' => l10n.muscleGroupCalves,
    'ABS' => l10n.muscleGroupAbs,
    'CARDIO' => l10n.muscleGroupCardio,
    'FULL_BODY' => l10n.muscleGroupFullBody,
    _ => l10n.muscleGroupOther,
  };
}

/// Returns the `AppMetricColors` accent for a muscle-group code.
///
/// Mapping follows the design-handoff palette (section 9):
/// Chest/Quads → calories · Shoulders/Glutes → carbs · Triceps/Forearms/Abs → fat
/// Back → water · Biceps → protein · Hamstrings/Calves → steps
/// Cardio/Full body/Other → weight
Color muscleGroupColor(String code, BuildContext context) {
  final mc = context.metricColors;
  return switch (code) {
    'CHEST' || 'QUADS' => mc.calories,
    'SHOULDERS' || 'GLUTES' => mc.carbs,
    'TRICEPS' || 'FOREARMS' || 'ABS' => mc.fat,
    'BACK' => mc.water,
    'BICEPS' => mc.protein,
    'HAMSTRINGS' || 'CALVES' => mc.steps,
    _ => mc.weight, // CARDIO, FULL_BODY, OTHER
  };
}

/// Returns the muscle-group code that occurs most often among [categories],
/// ignoring nulls. Ties break by [kMuscleGroups] display order. Returns null
/// when no category is present — callers fall back to a neutral colour.
String? dominantMuscleGroup(Iterable<String?> categories) {
  final counts = <String, int>{};
  for (final code in categories) {
    if (code == null) continue;
    counts[code] = (counts[code] ?? 0) + 1;
  }
  if (counts.isEmpty) return null;
  String? best;
  var bestCount = 0;
  for (final code in kMuscleGroups) {
    final n = counts[code] ?? 0;
    if (n > bestCount) {
      bestCount = n;
      best = code;
    }
  }
  return best;
}

String equipmentLabel(AppLocalizations l10n, String code) {
  return switch (code) {
    'BARBELL' => l10n.equipmentBarbell,
    'DUMBBELL' => l10n.equipmentDumbbell,
    'MACHINE' => l10n.equipmentMachine,
    'CABLE' => l10n.equipmentCable,
    'BODYWEIGHT' => l10n.equipmentBodyweight,
    'SMITH_MACHINE' => l10n.equipmentSmithMachine,
    _ => l10n.equipmentOther,
  };
}
