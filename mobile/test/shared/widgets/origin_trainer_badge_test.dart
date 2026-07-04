import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/my_trainers/application/my_trainers_controller.dart';
import 'package:lifey/features/my_trainers/domain/my_trainer.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/shared/widgets/origin_trainer_badge.dart';

class _FakeMyTrainersController extends MyTrainersController {
  _FakeMyTrainersController(this._trainers);
  final List<MyTrainer> _trainers;

  @override
  Future<List<MyTrainer>> build() async => _trainers;
}

Future<void> _pumpBadge(
  WidgetTester tester, {
  required int originTrainerId,
  List<MyTrainer> trainers = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        myTrainersControllerProvider.overrideWith(() => _FakeMyTrainersController(trainers)),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: OriginTrainerBadge(originTrainerId: originTrainerId)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the "From trainer" label', (tester) async {
    await _pumpBadge(tester, originTrainerId: 1);

    expect(find.text('From trainer'), findsOneWidget);
  });

  testWidgets('tapping opens a sheet naming the trainer when still connected', (tester) async {
    await _pumpBadge(
      tester,
      originTrainerId: 1,
      trainers: [
        MyTrainer(trainerId: 1, trainerEmail: 'anna@example.com', activeSince: DateTime(2026, 1, 1)),
      ],
    );

    await tester.tap(find.text('From trainer'));
    await tester.pumpAndSettle();

    expect(find.text('Who gave you this?'), findsOneWidget);
    expect(find.text('anna@example.com assigned this to you.'), findsOneWidget);
  });

  testWidgets('tapping opens a fallback sheet when the trainer relationship has ended',
      (tester) async {
    await _pumpBadge(tester, originTrainerId: 99, trainers: const []);

    await tester.tap(find.text('From trainer'));
    await tester.pumpAndSettle();

    expect(
      find.text("This was assigned by a trainer you're no longer connected with."),
      findsOneWidget,
    );
  });
}
