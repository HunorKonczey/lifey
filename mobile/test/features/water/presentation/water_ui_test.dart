import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/sync/sync_status_provider.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/water/application/water_source_controller.dart';
import 'package:lifey/features/water/data/water_entry_repository.dart';
import 'package:lifey/features/water/domain/water_source.dart';
import 'package:lifey/features/water/presentation/water_sources_screen.dart';
import 'package:lifey/features/water/presentation/widgets/add_water_sheet.dart';
import 'package:lifey/l10n/app_localizations.dart';

class _LoggedWater {
  _LoggedWater(this.liters, this.sourceClientId);
  final double liters;
  final String? sourceClientId;
}

class _FakeEntries extends Fake implements WaterEntryRepository {
  final logged = <_LoggedWater>[];

  @override
  Future<void> create({required DateTime consumedAt, String? sourceClientId, required double volumeLiters}) async {
    logged.add(_LoggedWater(volumeLiters, sourceClientId));
  }
}

class _FakeSources extends WaterSourceController {
  _FakeSources(this.sources);
  final List<WaterSource> sources;
  final deleted = <String>[];

  @override
  Stream<List<WaterSource>> build() => Stream.value(sources);

  @override
  Future<void> deleteSource(String clientId) async => deleted.add(clientId);
}

class _FakeSettings extends SettingsController {
  _FakeSettings(this.goal);
  final double? goal;

  @override
  Stream<UserSettings> build() =>
      Stream.value(const UserSettings.defaults().copyWith(dailyWaterGoalLiters: goal));
}

const _bottle = WaterSource(clientId: 'bottle', name: 'Water Bottle', volumeLiters: 0.75);
const _shake = WaterSource(clientId: 'shake', name: 'Creatine Shake', volumeLiters: 0.9);

Future<({_FakeEntries entries, _FakeSources sources})> _pump(
  WidgetTester tester,
  Widget home, {
  List<WaterSource> sources = const [],
  double? goal = 2.6,
  double total = 0.99,
  Locale locale = const Locale('en'),
  double textScale = 1,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = const Size(411 * 2.625, 923 * 2.625);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  final entries = _FakeEntries();
  final fakeSources = _FakeSources(sources);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      waterEntryRepositoryProvider.overrideWithValue(entries),
      waterSourceControllerProvider.overrideWith(() => fakeSources),
      settingsControllerProvider.overrideWith(() => _FakeSettings(goal)),
      todayWaterTotalProvider.overrideWith((ref) => Stream.value(total)),
      syncStatusByClientIdProvider.overrideWithValue(const {}),
    ],
    child: MaterialApp(
      theme: theme ?? AppTheme.dark,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: home,
    ),
  ));
  await tester.pumpAndSettle();
  return (entries: entries, sources: fakeSources);
}

Widget _opener() => Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(onPressed: () => showAddWaterSheet(context), child: const Text('open')),
        ),
      ),
    );

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('Add water sheet', () {
    testWidgets('canvas: title, "0.99 / 2.60 L" in the water colour, three 64 px tiles', (tester) async {
      await _pump(tester, _opener());
      await _open(tester);
      expect(find.text('Add water'), findsOneWidget);
      expect(find.text('0.99 / 2.60 L'), findsOneWidget);
      final header = tester.widget<Text>(find.text('0.99 / 2.60 L'));
      expect(header.style!.color, AppMetricColorsDark.water);
      for (final v in ['0.25', '0.5', '1.0']) {
        expect(find.text(v), findsOneWidget, reason: v);
        expect(tester.getSize(find.ancestor(of: find.text(v), matching: find.byType(SizedBox)).first).height, 64);
      }
      expect(find.text('L'), findsWidgets);
    });

    testWidgets('without a goal the header is just the total', (tester) async {
      await _pump(tester, _opener(), goal: null);
      await _open(tester);
      expect(find.text('0.99 L'), findsOneWidget);
    });

    testWidgets('one tap on a tile logs that amount and closes the sheet', (tester) async {
      final fakes = await _pump(tester, _opener());
      await _open(tester);
      await tester.tap(find.text('0.5'));
      await tester.pumpAndSettle();
      expect(fakes.entries.logged.single.liters, 0.5);
      expect(fakes.entries.logged.single.sourceClientId, isNull);
      expect(find.text('Add water'), findsNothing);
    });

    testWidgets('saved sources are offered and log with their id', (tester) async {
      final fakes = await _pump(tester, _opener(), sources: [_bottle, _shake]);
      await _open(tester);
      expect(find.text('SAVED SOURCES'), findsOneWidget);
      await tester.tap(find.text('Water Bottle · 0.75L'));
      await tester.pumpAndSettle();
      expect(fakes.entries.logged.single.liters, 0.75);
      expect(fakes.entries.logged.single.sourceClientId, 'bottle');
    });

    testWidgets('no saved sources: no section', (tester) async {
      await _pump(tester, _opener());
      await _open(tester);
      expect(find.text('SAVED SOURCES'), findsNothing);
    });

    testWidgets('a custom amount accepts a decimal comma; nonsense shows an error and logs nothing',
        (tester) async {
      final fakes = await _pump(tester, _opener());
      await _open(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
      expect(fakes.entries.logged, isEmpty);
      expect(find.byType(AddWaterSheet), findsOneWidget, reason: 'stays open');
      expect(find.textContaining('valid'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '1,5');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
      expect(fakes.entries.logged.single.liters, 1.5);
    });

    testWidgets('Hungarian: title, decimal comma, and it fits at ×1.3', (tester) async {
      await _pump(tester, _opener(), locale: const Locale('hu'), textScale: 1.3, sources: [_bottle, _shake]);
      await _open(tester);
      expect(find.text('Víz hozzáadása'), findsOneWidget);
      expect(find.text('0,99 / 2,60 L'), findsOneWidget);
      expect(find.text('0,25'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Water sources screen', () {
    testWidgets('sources are one grouped list with the volume under the name', (tester) async {
      await _pump(tester, const WaterSourcesScreen(), sources: [_bottle, _shake]);
      expect(find.text('Water sources'), findsOneWidget);
      expect(find.text('Water Bottle'), findsOneWidget);
      expect(find.text('0.75 L'), findsOneWidget);
      expect(find.text('Creatine Shake'), findsOneWidget);
      expect(find.text('0.9 L'), findsOneWidget);
      // No bare trash buttons any more.
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      expect(find.byIcon(Icons.more_vert_rounded), findsNWidgets(2));
    });

    testWidgets('Delete is in the ⋮ menu and asks first', (tester) async {
      final fakes = await _pump(tester, const WaterSourcesScreen(), sources: [_bottle]);
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(fakes.sources.deleted, isEmpty, reason: 'not before the confirmation');
      expect(find.textContaining('Water Bottle'), findsWidgets);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(fakes.sources.deleted, ['bottle']);
    });

    testWidgets('tapping a row opens the edit sheet pre-filled', (tester) async {
      await _pump(tester, const WaterSourcesScreen(), sources: [_bottle]);
      await tester.tap(find.text('Water Bottle'));
      await tester.pumpAndSettle();
      expect(find.text('Edit water source'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Water Bottle'), findsOneWidget);
    });

    testWidgets('the + button opens "New water source"', (tester) async {
      await _pump(tester, const WaterSourcesScreen(), sources: [_bottle]);
      await tester.tap(find.byTooltip('New water source'));
      await tester.pumpAndSettle();
      expect(find.text('New water source'), findsWidgets);
    });

    testWidgets('empty state', (tester) async {
      await _pump(tester, const WaterSourcesScreen());
      expect(find.text('No water sources yet'), findsOneWidget);
    });

    for (final scale in [1.0, 1.3]) {
      for (final theme in {'dark': AppTheme.dark, 'light': AppTheme.light}.entries) {
        testWidgets('Hungarian fits — ${theme.key}, ×$scale', (tester) async {
          await _pump(tester, const WaterSourcesScreen(),
              sources: [_bottle, _shake], locale: const Locale('hu'), textScale: scale, theme: theme.value);
          expect(tester.takeException(), isNull);
          expect(find.text('0,75 L'), findsOneWidget);
        });
      }
    }
  });
}

/// The dark water colour the sheet header must use (the design's `#74B6D6`).
class AppMetricColorsDark {
  static const water = Color(0xFF74B6D6);
}
