import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/home_screen_widget/widget_snapshot_writer.dart';
import 'package:lifey/features/dashboard/domain/daily_stats.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/workouts/application/activity_ranking.dart';

const _stats = DailyStats(
  calories: 1430.4,
  protein: 0,
  carbs: 0,
  fat: 0,
  workoutCount: 0,
  water: 0,
);

void main() {
  group('WidgetSnapshotWriter', () {
    test('no-ops when unavailable (non-iOS)', () async {
      var saveCalls = 0;
      var updateCalls = 0;
      final writer = WidgetSnapshotWriter(
        isAvailable: false,
        saveWidgetData: (key, value) async {
          saveCalls++;
          return true;
        },
        updateWidget: () async {
          updateCalls++;
          return true;
        },
      );

      await writer.write(
        stats: _stats,
        steps: 6412,
        settings: const UserSettings.defaults(),
      );

      expect(saveCalls, 0);
      expect(updateCalls, 0);
    });

    test('writes a snapshot and triggers a widget reload when available', () async {
      String? savedKey;
      String? savedValue;
      var updateCalls = 0;
      final writer = WidgetSnapshotWriter(
        isAvailable: true,
        saveWidgetData: (key, value) async {
          savedKey = key;
          savedValue = value;
          return true;
        },
        updateWidget: () async {
          updateCalls++;
          return true;
        },
      );

      await writer.write(
        stats: _stats,
        steps: 6412,
        settings: const UserSettings(
          unitSystem: UnitSystem.metric,
          theme: ThemePreference.system,
          language: LanguagePreference.hungarian,
          dailyCalorieGoal: 2200,
          dailyStepGoal: 10000,
        ),
      );

      expect(savedKey, 'today_snapshot');
      expect(updateCalls, 1);

      final snapshot = jsonDecode(savedValue!) as Map<String, dynamic>;
      final now = DateTime.now();
      final expectedDate =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      expect(snapshot['date'], expectedDate);
      expect(snapshot['calories'], 1430); // rounded from 1430.4
      expect(snapshot['calorieGoal'], 2200);
      expect(snapshot['steps'], 6412);
      expect(snapshot['stepGoal'], 10000);
      expect(snapshot['locale'], 'hu');
      expect(snapshot['labels'], {
        'calories': 'Kalória',
        'steps': 'Lépés',
        'noData': 'Nyisd meg az appot',
      });
      expect(snapshot['quickStart'], isEmpty); // no ranking passed
    });

    test('quickStart carries up to 2 resolved entries, label + deep link', () async {
      String? savedValue;
      final writer = WidgetSnapshotWriter(
        isAvailable: true,
        saveWidgetData: (key, value) async {
          savedValue = value;
          return true;
        },
        updateWidget: () async => true,
      );

      await writer.write(
        stats: _stats,
        steps: 6412,
        settings: const UserSettings.defaults(), // language: system -> en
        quickStartEntries: const [
          (entry: QuickStartEntry.cardio('RUNNING'), template: null),
          (entry: QuickStartEntry.strength(), template: null),
          // A 3rd entry — must not appear, only the top 2 are used
          // (docs/cardio/53-cardio-mobile-plan.md §3.3).
          (entry: QuickStartEntry.cardio('WALKING'), template: null),
        ],
      );

      final snapshot = jsonDecode(savedValue!) as Map<String, dynamic>;
      expect(snapshot['quickStart'], [
        {'label': 'Running', 'deepLinkUri': 'lifey://workout/start?activity=RUNNING'},
        {'label': 'Empty workout', 'deepLinkUri': 'lifey://workout/start?activity=STRENGTH'},
      ]);
    });

    test('goal fields are null when no goal is set', () async {
      String? savedValue;
      final writer = WidgetSnapshotWriter(
        isAvailable: true,
        saveWidgetData: (key, value) async {
          savedValue = value;
          return true;
        },
        updateWidget: () async => true,
      );

      await writer.write(
        stats: _stats,
        steps: 6412,
        settings: const UserSettings.defaults(),
      );

      final snapshot = jsonDecode(savedValue!) as Map<String, dynamic>;
      expect(snapshot['calorieGoal'], isNull);
      expect(snapshot['stepGoal'], isNull);
    });

    test('steps is null when Health is not connected', () async {
      String? savedValue;
      final writer = WidgetSnapshotWriter(
        isAvailable: true,
        saveWidgetData: (key, value) async {
          savedValue = value;
          return true;
        },
        updateWidget: () async => true,
      );

      await writer.write(
        stats: _stats,
        steps: null,
        settings: const UserSettings.defaults(),
      );

      final snapshot = jsonDecode(savedValue!) as Map<String, dynamic>;
      expect(snapshot['steps'], isNull);
    });

    test('English/system language resolves to en labels and locale', () async {
      String? savedValue;
      final writer = WidgetSnapshotWriter(
        isAvailable: true,
        saveWidgetData: (key, value) async {
          savedValue = value;
          return true;
        },
        updateWidget: () async => true,
      );

      await writer.write(
        stats: _stats,
        steps: 100,
        settings: const UserSettings.defaults(), // language: system
      );

      final snapshot = jsonDecode(savedValue!) as Map<String, dynamic>;
      expect(snapshot['locale'], 'en');
      expect(snapshot['labels'], {
        'calories': 'Calories',
        'steps': 'Steps',
        'noData': 'Open the app',
      });
    });
  });
}
