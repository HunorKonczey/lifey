import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/core/theme/app_tokens.dart';
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/workouts/presentation/widgets/box_score_stepper.dart';
import 'package:lifey/features/workouts/presentation/widgets/cardio_session_settings_sheet.dart';
import 'package:lifey/features/workouts/presentation/widgets/game_setup_sheet.dart';
import 'package:lifey/features/workouts/presentation/widgets/gps_explainer_sheet.dart';
import 'package:lifey/features/workouts/presentation/widgets/post_workout_feedback_sheet.dart';
import 'package:lifey/features/workouts/presentation/widgets/rpe_selector.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubSettings extends SettingsController {
  @override
  Stream<UserSettings> build() => Stream.value(const UserSettings.defaults());
}

/// docs/redesign/77-mobile-redesign-plan.md R3.11: the workout sheets share the
/// design system's handle and surface, and hold up at 360 dp × 130 % in Hungarian
/// in both themes.
Future<void> _open(
  WidgetTester tester,
  Future<void> Function(BuildContext) show, {
  Locale locale = const Locale('en'),
  double width = 411,
  double textScale = 1,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = Size(width * 2.625, 923 * 2.625);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(ProviderScope(
    overrides: [settingsControllerProvider.overrideWith(_StubSettings.new)],
    child: MaterialApp(
      theme: theme ?? AppTheme.dark,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(child: ElevatedButton(onPressed: () => show(context), child: const Text('open'))),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  final sheets = <String, Future<void> Function(BuildContext)>{
    'gps explainer': (c) => showGpsExplainerSheet(c),
    'post-workout feedback': (c) => showPostWorkoutFeedbackSheet(c, initialRpe: 7, initialNote: 'Felt strong'),
    'cardio session settings': (c) => showCardioSessionSettingsSheet(c),
    'game setup': (c) => showGameSetupSheet(c),
  };

  group('the handle of a sheet that asks for Material\'s is the design system\'s', () {
    testWidgets('36 x 4, tertiary text at 60 %', (tester) async {
      await _open(tester, (c) => showGpsExplainerSheet(c));

      final handle = tester.widget<Container>(
        find.descendant(of: find.byType(BottomSheet), matching: find.byWidgetPredicate((w) {
          return w is Container && w.constraints?.maxWidth == 36 && w.constraints?.maxHeight == 4;
        })).first,
      );
      final decoration = handle.decoration as BoxDecoration;
      expect(decoration.color, AppPalette.dark.text3.withValues(alpha: 0.6));
    });
  });

  for (final entry in sheets.entries) {
    for (final width in [411.0, 360.0]) {
      testWidgets('${entry.key}: no overflow at ${width.toInt()} dp, text x1.3, HU, dark', (tester) async {
        await _open(tester, entry.value, locale: const Locale('hu'), width: width, textScale: 1.3);

        final error = tester.takeException();
        expect(error is FlutterError ? error.toStringDeep() : error, isNull);
      });
    }

    testWidgets('${entry.key}: no overflow at 360 dp, text x1.3, EN, light', (tester) async {
      await _open(tester, entry.value, width: 360, textScale: 1.3, theme: AppTheme.light);

      final error = tester.takeException();
      expect(error is FlutterError ? error.toStringDeep() : error, isNull);
    });
  }

  testWidgets('box score stepper: no overflow at 360 dp, text x1.3, HU', (tester) async {
    tester.view.physicalSize = const Size(360 * 2.625, 923 * 2.625);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      locale: const Locale('hu'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
        child: child!,
      ),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: BoxScoreStepper(
            enabled: true,
            onInteraction: () {},
            columns: [
              BoxScoreColumn(label: 'PONT', value: 18, onStep: (_) {}),
              BoxScoreColumn(label: 'LEPattan', value: 7, onStep: (_) {}),
              BoxScoreColumn(label: 'ASSZISZT', value: 4, onStep: (_) {}),
            ],
          ),
        ),
      ),
    ));
    await tester.pump();

    final error = tester.takeException();
    expect(error is FlutterError ? error.toStringDeep() : error, isNull);
  });
  testWidgets('RPE anchors sit at the two ends of the scale', (tester) async {
    tester.view.physicalSize = const Size(411 * 2.625, 923 * 2.625);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: RpeSelector(value: null, onChanged: (_) {}, lowAnchorLabel: 'Very easy', highAnchorLabel: 'Maximal effort'),
        ),
      ),
    ));

    expect(tester.getTopLeft(find.text('Very easy')).dx, 16);
    expect(tester.getTopRight(find.text('Maximal effort')).dx, closeTo(411 - 16, 0.5));
  });
}
