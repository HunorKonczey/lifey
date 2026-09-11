import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifey/core/router/app_router.dart';
import 'package:lifey/features/auth/application/auth_controller.dart';
import 'package:lifey/features/auth/domain/auth_user.dart';
import 'package:lifey/features/trainer/application/trainer_view_preference.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/shared/widgets/trainer_view_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthController extends AuthController {
  _FakeAuthController(this._roles);

  final List<String> _roles;

  @override
  Future<AuthUser?> build() async => AuthUser(
        id: 7,
        email: 'coach@example.com',
        firstName: 'Coach',
        lastName: 'One',
        roles: _roles,
      );
}

/// A two-stop router standing in for the two shells: enough to prove where
/// the menu sends you, without booting the real dashboard (ads, sync, drift).
GoRouter _router({required String initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const Scaffold(
          body: Column(
            children: [
              Text('client home'),
              TrainerViewMenu(inTrainerView: false),
            ],
          ),
        ),
      ),
      GoRoute(
        path: trainerShellLocation,
        builder: (context, state) => const Scaffold(
          body: Column(
            children: [
              Text('trainer home'),
              TrainerViewMenu(inTrainerView: true),
            ],
          ),
        ),
      ),
    ],
  );
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required List<String> roles,
  String initialLocation = '/dashboard',
}) async {
  final container = ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith(() => _FakeAuthController(roles)),
    ],
  );
  addTearDown(container.dispose);
  await container.read(authControllerProvider.future);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: _router(initialLocation: initialLocation),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('homeLocationFor', () {
    test('a plain client always starts on their dashboard', () {
      expect(
        homeLocationFor(isTrainer: false, lastViewWasTrainer: false),
        '/dashboard',
      );
    });

    test('a trainer who last worked on the client side starts there', () {
      expect(
        homeLocationFor(isTrainer: true, lastViewWasTrainer: false),
        '/dashboard',
      );
    });

    test('a trainer who last worked in the trainer view starts there', () {
      expect(
        homeLocationFor(isTrainer: true, lastViewWasTrainer: true),
        trainerShellLocation,
      );
    });

    test('losing the trainer role beats a remembered trainer view', () {
      expect(
        homeLocationFor(isTrainer: false, lastViewWasTrainer: true),
        '/dashboard',
      );
    });
  });

  group('the switch menu', () {
    testWidgets('is invisible to a user who is not a trainer', (tester) async {
      await _pump(tester, roles: ['ROLE_USER']);

      expect(find.byType(PopupMenuButton<void>), findsNothing);
    });

    testWidgets('takes a dual-role user from their own log to the trainer view',
        (tester) async {
      final container = await _pump(tester, roles: ['ROLE_USER', 'ROLE_TRAINER']);

      await tester.tap(find.byType(PopupMenuButton<void>));
      await tester.pumpAndSettle();
      expect(find.text('Trainer view'), findsOneWidget);

      await tester.tap(find.text('Trainer view'));
      await tester.pumpAndSettle();

      expect(find.text('trainer home'), findsOneWidget);
      expect(container.read(lastViewIsTrainerProvider).value, isTrue);
    });

    testWidgets('takes the same user back to their own log', (tester) async {
      final container = await _pump(
        tester,
        roles: ['ROLE_USER', 'ROLE_TRAINER'],
        initialLocation: trainerShellLocation,
      );

      await tester.tap(find.byType(PopupMenuButton<void>));
      await tester.pumpAndSettle();
      expect(find.text('My own log'), findsOneWidget);

      await tester.tap(find.text('My own log'));
      await tester.pumpAndSettle();

      expect(find.text('client home'), findsOneWidget);
      expect(container.read(lastViewIsTrainerProvider).value, isFalse);
    });
  });

  group('TrainerViewPreference', () {
    test('defaults to the client view and round-trips a switch', () async {
      final preference = TrainerViewPreference();

      expect(await preference.lastViewWasTrainer(), isFalse);

      await preference.setLastViewWasTrainer(true);
      expect(await preference.lastViewWasTrainer(), isTrue);

      // Logout wipes it, so the next account on this device starts fresh.
      await preference.clear();
      expect(await preference.lastViewWasTrainer(), isFalse);
    });
  });
}
