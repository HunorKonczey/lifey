import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifey/features/trainer/settings/trainer_preferences.dart';
import 'package:lifey/features/trainer/settings/trainer_settings_screen.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/shared/widgets/trainer_view_menu.dart';

class _FakeAdapter implements HttpClientAdapter {
  final List<String> methods = [];
  final List<String> paths = [];
  final List<Object?> bodies = [];
  Object body = <String, dynamic>{};

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    methods.add(options.method);
    paths.add(options.path);
    bodies.add(options.data);
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

class _FakePreferencesRepository extends TrainerPreferencesRepository {
  _FakePreferencesRepository({this.failWrite = false}) : super(Dio());

  bool enabled = true;
  final bool failWrite;

  final List<bool> writes = [];

  @override
  Future<TrainerPreferences> fetch() async =>
      TrainerPreferences(weeklyReportEmailEnabled: enabled);

  @override
  Future<TrainerPreferences> setWeeklyReportEmailEnabled(bool value) async {
    if (failWrite) throw Exception('boom');
    writes.add(value);
    enabled = value;
    return TrainerPreferences(weeklyReportEmailEnabled: value);
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required _FakePreferencesRepository repo,
  Locale locale = const Locale('en'),
  double textScale = 1,
  ThemeData? theme,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const TrainerSettingsScreen()),
      GoRoute(
        path: trainerInvitesLocation,
        builder: (context, state) => const Scaffold(body: Text('invites screen')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [trainerPreferencesRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(
        theme: theme ?? AppTheme.dark,
        locale: locale,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('repository', () {
    late Dio dio;
    late _FakeAdapter adapter;
    late TrainerPreferencesRepository repo;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'http://test'));
      adapter = _FakeAdapter();
      dio.httpClientAdapter = adapter;
      repo = TrainerPreferencesRepository(dio);
    });

    test('reads the one preference there is', () async {
      adapter.body = {'weeklyReportEmailEnabled': false};

      final preferences = await repo.fetch();

      expect(adapter.paths.single, '/trainer/preferences');
      expect(preferences.weeklyReportEmailEnabled, isFalse);
    });

    test('a missing field defaults to enabled, matching the backend', () async {
      adapter.body = <String, dynamic>{};

      expect((await repo.fetch()).weeklyReportEmailEnabled, isTrue);
    });

    test('writes it with PUT', () async {
      adapter.body = {'weeklyReportEmailEnabled': false};

      await repo.setWeeklyReportEmailEnabled(false);

      expect(adapter.methods.single, 'PUT');
      expect(adapter.bodies.single, {'weeklyReportEmailEnabled': false});
    });
  });

  group('the screen', () {
    testWidgets('shows the toggle and says the report stays an email',
        (tester) async {
      await _pump(tester, repo: _FakePreferencesRepository());

      expect(find.text('Weekly report email'), findsOneWidget);
      // The subtitle is where the "no in-app report" decision is stated to
      // the trainer, rather than leaving the absence unexplained.
      expect(
        find.textContaining('There is no in-app version'),
        findsOneWidget,
      );
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('turning it off writes it through', (tester) async {
      final repo = _FakePreferencesRepository();
      await _pump(tester, repo: repo);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(repo.writes, [false]);
      final toggle = tester.widget<Switch>(find.byType(Switch));
      expect(toggle.value, isFalse);
    });

    testWidgets('a failed write says so and leaves the switch where it was',
        (tester) async {
      await _pump(
        tester,
        repo: _FakePreferencesRepository(failWrite: true),
      );

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // No optimistic flip: a switch that springs back is worse than one
      // that waits, so the error is shown instead.
      expect(find.text('Something went wrong.'), findsOneWidget);
    });

    testWidgets('points at the invites screen', (tester) async {
      await _pump(tester, repo: _FakePreferencesRepository());

      await tester.tap(find.text('Invites'));
      await tester.pumpAndSettle();

      expect(find.text('invites screen'), findsOneWidget);
    });

    testWidgets('says where the account settings are, so the short list reads right',
        (tester) async {
      await _pump(tester, repo: _FakePreferencesRepository());

      expect(
        find.textContaining('are under your own log'),
        findsOneWidget,
      );
    });
  });

  group('layout (canvas Lifey 6 family)', () {
    for (final (name, locale) in [('English', const Locale('en')), ('Hungarian', const Locale('hu'))]) {
      for (final (mode, theme) in [('dark', AppTheme.dark), ('light', AppTheme.light)]) {
        testWidgets('the settings list fits 360 dp at x 1.3 in $name, $mode', (tester) async {
          tester.view.physicalSize = const Size(360, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await _pump(tester, repo: _FakePreferencesRepository(), locale: locale, textScale: 1.3, theme: theme);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
