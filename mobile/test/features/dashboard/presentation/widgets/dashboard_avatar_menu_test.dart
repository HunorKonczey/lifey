import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/features/auth/application/auth_controller.dart';
import 'package:lifey/features/auth/domain/auth_user.dart';
import 'package:lifey/features/dashboard/presentation/widgets/dashboard_avatar_menu.dart';
import 'package:lifey/features/settings/application/avatar_controller.dart';
import 'package:lifey/l10n/app_localizations.dart';

class _FakeAuth extends AuthController {
  _FakeAuth(this._user);
  final AuthUser? _user;

  @override
  Future<AuthUser?> build() async => _user;
}

class _FakeAvatar extends AvatarController {
  @override
  Future<Uint8List?> build() async => null;
}

AuthUser _user({String? first = 'Anna', String? last = 'Kovács', List<String> roles = const ['ROLE_USER']}) =>
    AuthUser(id: 1, email: 'anna@mail.com', firstName: first, lastName: last, roles: roles);

Future<void> _pump(WidgetTester tester, AuthUser user, {Locale locale = const Locale('en')}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: Center(child: DashboardAvatarMenu())),
      ),
      GoRoute(path: '/settings', builder: (_, __) => const Scaffold(body: Text('SETTINGS PAGE'))),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(() => _FakeAuth(user)),
        avatarControllerProvider.overrideWith(_FakeAvatar.new),
      ],
      child: MaterialApp.router(
        theme: AppTheme.dark,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the avatar shows the monogram from the name — "AK", not the e-mail letter', (tester) async {
    await _pump(tester, _user());
    expect(find.text('AK'), findsOneWidget);
    expect(find.text('A'), findsNothing);
  });

  testWidgets('without a name it falls back to the e-mail initial', (tester) async {
    await _pump(tester, _user(first: null, last: null));
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('the touch target is 48 dp', (tester) async {
    await _pump(tester, _user());
    final size = tester.getSize(find.byType(PopupMenuButton<void>));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('a client gets one item — Profile & settings — which opens Settings', (tester) async {
    await _pump(tester, _user());
    await tester.tap(find.byType(DashboardAvatarMenu));
    await tester.pumpAndSettle();
    expect(find.text('Profile & settings'), findsOneWidget);
    expect(find.text('Trainer view'), findsNothing);

    await tester.tap(find.text('Profile & settings'));
    await tester.pumpAndSettle();
    expect(find.text('SETTINGS PAGE'), findsOneWidget);
  });

  testWidgets('a trainer also gets the way into the trainer view', (tester) async {
    await _pump(tester, _user(roles: const ['ROLE_USER', 'ROLE_TRAINER']));
    await tester.tap(find.byType(DashboardAvatarMenu));
    await tester.pumpAndSettle();
    expect(find.text('Profile & settings'), findsOneWidget);
    expect(find.text('Trainer view'), findsOneWidget);
  });

  testWidgets('Hungarian menu label', (tester) async {
    await _pump(tester, _user(), locale: const Locale('hu'));
    await tester.tap(find.byType(DashboardAvatarMenu));
    await tester.pumpAndSettle();
    expect(find.text('Profil és beállítások'), findsOneWidget);
  });
}
