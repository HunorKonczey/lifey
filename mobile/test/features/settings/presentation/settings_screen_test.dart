import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/entitlements/entitlement.dart';
import 'package:lifey/core/entitlements/entitlement_providers.dart';
import 'package:lifey/core/health/health_controller.dart';
import 'package:lifey/core/sync/logout_preflight.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/core/watch/watch_workout_service.dart';
import 'package:lifey/features/auth/application/auth_controller.dart';
import 'package:lifey/features/auth/domain/auth_user.dart';
import 'package:lifey/features/my_trainers/application/my_trainers_controller.dart';
import 'package:lifey/features/my_trainers/domain/my_trainer.dart';
import 'package:lifey/features/settings/application/avatar_controller.dart';
import 'package:lifey/features/settings/application/notification_settings_controller.dart';
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/settings/presentation/notification_settings_screen.dart';
import 'package:lifey/features/settings/presentation/settings_screen.dart';
import 'package:lifey/features/settings/presentation/widgets/settings_integrations.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/shared/widgets/ds/tinted_chip.dart';

class _FakeSettings extends SettingsController {
  @override
  Stream<UserSettings> build() => Stream.value(const UserSettings(
        unitSystem: UnitSystem.metric,
        theme: ThemePreference.system,
        language: LanguagePreference.system,
        dailyCalorieGoal: 2360,
        dailyProteinGoal: 129,
        dailyCarbsGoal: 313,
        dailyFatGoal: 66,
        dailyWaterGoalLiters: 2.6,
      ));
}

class _FakeAuth extends AuthController {
  @override
  Future<AuthUser?> build() async =>
      const AuthUser(id: 1, email: 'anna.kovacs@mail.com', roles: ['CLIENT'], firstName: 'Anna', lastName: 'Kovacs');
}

class _FakeAvatar extends AvatarController {
  @override
  Future<Uint8List?> build() async => null;
}

class _FakeEntitlement extends EntitlementController {
  _FakeEntitlement(this._tier);
  final EntitlementTier _tier;

  @override
  Stream<Entitlement> build() {
    final now = DateTime.now();
    return Stream.value(Entitlement(
      tier: _tier,
      source: _tier == EntitlementTier.pro ? EntitlementSource.playStore : EntitlementSource.none,
      adsEnabled: false,
      historyDays: null,
      aiCreditsRemaining: null,
      trainer: null,
      expiresAt: now.add(const Duration(days: 30)),
      checkedAt: now,
      graceUntil: now.add(const Duration(days: 7)),
      degraded: false,
      resolved: true,
    ));
  }
}

class _FakeHealth extends HealthController {
  _FakeHealth(this._on);
  final bool _on;

  @override
  Future<bool> build() async => _on;
}

class _FakeTrainers extends MyTrainersController {
  @override
  Future<List<MyTrainer>> build() async => const [];
}

class _FakeNotifications extends NotificationSettingsController {
  @override
  Future<NotificationSettingsState> build() async => const NotificationSettingsState(
        workoutReminderEnabled: true,
        weighInReminderEnabled: false,
        weighInReminderHour: 8,
        weighInReminderMinute: 0,
        stepGoalNotificationEnabled: true,
        trainerCommentPushEnabled: false,
        trainerGoalsPushEnabled: false,
        programAssignedPushEnabled: false,
        chatPushEnabled: true,
      );
}

class _FakeWatch implements WatchWorkoutService {
  @override
  Future<bool> isWatchAppAvailable() async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<Override> _overrides({EntitlementTier tier = EntitlementTier.free, bool health = false}) => [
      settingsControllerProvider.overrideWith(_FakeSettings.new),
      authControllerProvider.overrideWith(_FakeAuth.new),
      avatarControllerProvider.overrideWith(_FakeAvatar.new),
      entitlementProvider.overrideWith(() => _FakeEntitlement(tier)),
      healthControllerProvider.overrideWith(() => _FakeHealth(health)),
      myTrainersControllerProvider.overrideWith(_FakeTrainers.new),
      notificationSettingsControllerProvider.overrideWith(_FakeNotifications.new),
      watchWorkoutServiceProvider.overrideWithValue(_FakeWatch()),
      logoutPreflightProvider.overrideWithValue(
        LogoutPreflight(pendingCount: () async => 0, isOnline: () async => true, sync: () async {}),
      ),
    ];

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  List<Override>? overrides,
  Locale locale = const Locale('en'),
  Size size = const Size(390, 3200),
  double textScale = 1,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides ?? _overrides(),
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
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a large title with a back button, the profile card and the four groups (canvas 8)', (tester) async {
    await _pump(tester, const SettingsScreen());

    expect(find.text('Settings'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    // The monogram is the initials of the NAME, not the first letter of the e-mail.
    expect(find.text('AK'), findsOneWidget);
    expect(find.text('Anna Kovacs'), findsOneWidget);
    expect(find.text('anna.kovacs@mail.com'), findsWidgets);
    expect(find.widgetWithText(TintedChip, 'Pro'), findsNothing); // a free account has no chip
    for (final label in ['PREFERENCES', 'DAILY GOALS', 'INTEGRATIONS']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Units'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
  });

  testWidgets('a Pro account wears the Pro chip on the profile card', (tester) async {
    await _pump(tester, const SettingsScreen(), overrides: _overrides(tier: EntitlementTier.pro));

    expect(find.widgetWithText(TintedChip, 'Pro'), findsOneWidget);
  });

  testWidgets('the six goal tiles, with the default step goal instead of a dash', (tester) async {
    await _pump(tester, const SettingsScreen());

    expect(find.text('Edit'), findsOneWidget);
    for (final v in ['2,360', '129', '313', '66', '2.6', '10,000']) {
      expect(find.textContaining(v, findRichText: true), findsWidgets, reason: v);
    }
    for (final label in ['Calories', 'Protein', 'Carbs', 'Fat', 'Water', 'Steps']) {
      expect(find.text(label), findsWidgets, reason: label);
    }
  });

  testWidgets('every existing setting is still reachable', (tester) async {
    await _pump(tester, const SettingsScreen());

    for (final label in [
      'Rest timer',
      'Default rest duration',
      'Manage water sources',
      'Notifications',
      'Change password',
      'Body & goals',
      'Log out',
    ]) {
      expect(find.text(label), findsWidgets, reason: label);
    }
  });

  testWidgets('Log out sits at the bottom of Account and opens the confirmation', (tester) async {
    await _pump(tester, const SettingsScreen());
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(find.text('Log out of Lifey?'), findsOneWidget);
  });

  group('integration rows', () {
    testWidgets('Health off: the subline says what off means, and the switch agrees', (tester) async {
      await _pump(tester, const Scaffold(body: HealthIntegrationRow()), overrides: _overrides(health: false));

      expect(find.text('Off · weight and steps are logged by hand'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    });

    testWidgets('Health on: the subline follows the real connection', (tester) async {
      await _pump(tester, const Scaffold(body: HealthIntegrationRow()), overrides: _overrides(health: true));

      expect(find.text('On · weight and steps are imported automatically'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    });

    testWidgets('Notifications reads how many types are on', (tester) async {
      await _pump(tester, Scaffold(body: NotificationsRow(onTap: () {})));

      expect(find.text('3 on'), findsOneWidget);
    });
  });

  for (final (name, locale, scale) in [
    ('English', const Locale('en'), 1.3),
    ('Hungarian', const Locale('hu'), 1.3),
    ('Hungarian', const Locale('hu'), 1.0),
  ]) {
    for (final (mode, theme) in [('dark', AppTheme.dark), ('light', AppTheme.light)]) {
      testWidgets('scrolls end to end without overflow: $name ×$scale, $mode, 360 dp', (tester) async {
        await _pump(tester, const SettingsScreen(), locale: locale, textScale: scale, theme: theme, size: const Size(360, 740));
        expect(tester.takeException(), isNull);
        final list = find.byType(Scrollable).first;
        await tester.drag(list, const Offset(0, -3000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  group('notification settings', () {
    testWidgets('sits under the subpage header, one grouped switch row per type', (tester) async {
      await _pump(tester, const NotificationSettingsScreen());

      expect(find.byType(AppBar), findsNothing);
      expect(find.text('Notifications'), findsWidgets);
      // The master switch and the seven types.
      expect(find.byType(Switch), findsAtLeastNWidgets(8));
      // "Any on" -> the master switch is on; the seeded state has three on.
      expect(tester.widgetList<Switch>(find.byType(Switch)).where((s) => s.value).length, greaterThanOrEqualTo(3));
    });

    for (final locale in [const Locale('en'), const Locale('hu')]) {
      testWidgets('fits 360 dp at × 1.3 in ${locale.languageCode}', (tester) async {
        await _pump(tester, const NotificationSettingsScreen(),
            locale: locale, textScale: 1.3, size: const Size(360, 740));
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
