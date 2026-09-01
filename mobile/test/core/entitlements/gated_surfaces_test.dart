import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-P7 (`docs/landing_page/67-mobile-free-pro-plan.md` §3): "Every gate
/// lives in `core/entitlements` and is enumerated in a test... Adding a gate
/// means editing that list; adding a screen that *should* be gated and is
/// not shows up as a review question rather than as free Pro forever."
///
/// Each test below scans every `.dart` file under `lib/` for a reference to
/// one of the three gate providers and asserts the result against a
/// hand-maintained set. The set growing or shrinking without this file
/// changing to match is exactly the signal D-P7 wants: it forces whoever
/// touched a gated screen to look at *why* the set changed and update the
/// list deliberately, rather than the change passing silently.
///
/// A file appearing here only means it *references* the provider — each
/// gate's own actual behavior (what happens at zero/expired/locked) is
/// covered by that gate's dedicated tests elsewhere (`banner_ad_slot_test`,
/// `statistics_screen_history_window_test`, `ai_credit_chip_test`, etc.).

const _libDir = 'lib';

Future<Set<String>> _filesReferencing(String needle) async {
  final matches = <String>{};
  await for (final entity in Directory(_libDir).list(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final content = await entity.readAsString();
    if (content.contains(needle)) {
      final relPath = entity.path.substring(_libDir.length + 1).replaceAll('\\', '/');
      matches.add(relPath);
    }
  }
  return matches;
}

void main() {
  test('ads gate (adsEnabledProvider, `67` §3.1) — exactly these files reference it', () async {
    final actual = await _filesReferencing('adsEnabledProvider')
      ..remove('core/entitlements/entitlement_providers.dart'); // the provider's own definition

    expect(actual, {
      'core/ads/banner_ad_slot.dart',
      'core/ads/interstitial_manager.dart',
    });
  });

  test('history window gate (historyCutoffProvider, `67` §3.2) — exactly these files reference it',
      () async {
    final actual = await _filesReferencing('historyCutoffProvider')
      ..remove('core/entitlements/entitlement_providers.dart');

    expect(actual, {
      'features/workouts/presentation/sessions_tab.dart',
      'features/nutrition/presentation/meals_tab.dart',
      'features/nutrition/presentation/macros_tab.dart',
      'features/statistics/presentation/statistics_screen.dart',
      'features/statistics/application/stat_chart_data.dart',
      'features/weight/presentation/weight_screen.dart',
      'features/weight/application/weight_chart_data.dart',
    });
  });

  test('AI credits gate (aiCreditsProvider, `67` §3.4) — exactly these files reference it',
      () async {
    final actual = await _filesReferencing('aiCreditsProvider')
      ..remove('core/entitlements/entitlement_providers.dart');

    // `requireAiCredits` and `AiCreditChip` exist (Prompt 4) but as of this
    // writing are not yet embedded in any AI-action screen — mobile has no
    // AI meal-photo-estimation UI built yet (docs/23-ai-calorie-estimation-plan.md
    // is still a backend-only/future surface here). This set records that
    // honestly rather than pretending a gate is wired somewhere it isn't;
    // the day an AI action screen is built, its own file lands in this set
    // and this test forces a deliberate edit here to acknowledge it.
    expect(actual, {
      'core/entitlements/ai_credit_gate.dart',
      'features/nutrition/presentation/widgets/ai_credit_chip.dart',
    });
  });
}
