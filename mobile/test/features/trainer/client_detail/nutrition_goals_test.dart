import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/trainer/client_detail/data/client_detail_repository.dart';
import 'package:lifey/features/trainer/client_detail/domain/client_data.dart';
import 'package:lifey/features/trainer/client_detail/presentation/widgets/nutrition_goals_sheet.dart';
import 'package:lifey/l10n/app_localizations.dart';

class _FakeAdapter implements HttpClientAdapter {
  final List<String> methods = [];
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

class _FakeDetailRepository extends ClientDetailRepository {
  _FakeDetailRepository({this.saved = const ClientNutritionGoals()})
      : super(Dio());

  final ClientNutritionGoals saved;

  ClientNutritionGoals? written;

  @override
  Future<ClientNutritionGoals> updateNutritionGoals(
    int clientId,
    ClientNutritionGoals goals,
  ) async {
    written = goals;
    return saved;
  }
}

/// Holds what the sheet returned, since it only returns once the trainer has
/// saved — which the test does after the sheet is open.
class _OutcomeBox {
  GoalsSaveOutcome? value;
}

Future<_OutcomeBox> _openSheet(
  WidgetTester tester, {
  required _FakeDetailRepository repo,
  required ClientNutritionGoals goals,
}) async {
  final box = _OutcomeBox();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [clientDetailRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                box.value = await NutritionGoalsSheet.show(
                  context,
                  clientId: 7,
                  goals: goals,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return box;
}

void main() {
  group('the wire format', () {
    test('sends whole numbers, and null for a goal that is not set', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://test'));
      final adapter = _FakeAdapter();
      dio.httpClientAdapter = adapter;
      adapter.body = {'dailyCalorieGoal': 2200};

      await ClientDetailRepository(dio).updateNutritionGoals(
        7,
        const ClientNutritionGoals(dailyCalorieGoal: 2200, dailyProteinGoal: 150),
      );

      expect(adapter.methods.single, 'PUT');
      // A full overwrite: the two goals left unset are sent as null, which
      // clears them, and that is the endpoint's contract.
      expect(adapter.bodies.single, {
        'dailyCalorieGoal': 2200,
        'dailyProteinGoal': 150,
        'dailyCarbsGoal': null,
        'dailyFatGoal': null,
      });
    });
  });

  group('the editor', () {
    testWidgets('starts from the goals the client already has', (tester) async {
      await _openSheet(
        tester,
        repo: _FakeDetailRepository(),
        goals: const ClientNutritionGoals(
          dailyCalorieGoal: 2200,
          dailyProteinGoal: 150,
        ),
      );

      expect(find.text('2200'), findsOneWidget);
      expect(find.text('150'), findsOneWidget);
    });

    testWidgets('an empty field means no goal, not zero', (tester) async {
      final repo = _FakeDetailRepository();
      await _openSheet(
        tester,
        repo: repo,
        goals: const ClientNutritionGoals(dailyCalorieGoal: 2200),
      );

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Zero would render as 100% over on the first bite; null is "no goal".
      expect(repo.written!.dailyProteinGoal, isNull);
      expect(repo.written!.dailyCalorieGoal, 2200);
    });

    testWidgets('a real change reports that the client was notified',
        (tester) async {
      final repo = _FakeDetailRepository(
        saved: const ClientNutritionGoals(dailyCalorieGoal: 2000),
      );

      final outcome = await _openSheet(
        tester,
        repo: repo,
        goals: const ClientNutritionGoals(dailyCalorieGoal: 2200),
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // The backend pushes the client on a change (docs/32) and only then.
      expect(outcome.value, GoalsSaveOutcome.changed);
    });

    testWidgets('saving the same numbers back claims no notification',
        (tester) async {
      const goals = ClientNutritionGoals(dailyCalorieGoal: 2200);
      final repo = _FakeDetailRepository(saved: goals);

      final outcome = await _openSheet(tester, repo: repo, goals: goals);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(outcome.value, GoalsSaveOutcome.unchanged);
    });
  });
}
