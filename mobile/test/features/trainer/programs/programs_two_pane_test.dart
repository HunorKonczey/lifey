import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifey/core/sync/connectivity_status_provider.dart';
import 'package:lifey/features/chat/application/conversation_list_controller.dart';
import 'package:lifey/features/trainer/programs/application/programs_controller.dart';
import 'package:lifey/features/trainer/programs/application/selected_program_controller.dart';
import 'package:lifey/features/trainer/programs/domain/program.dart';
import 'package:lifey/features/trainer/programs/presentation/programs_screen.dart';
import 'package:lifey/features/trainer/shared/trainer_layout.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/shared/widgets/trainer_view_menu.dart';

/// docs/chat/41-trainer-mobile-v2-plan.md §8.2 — the program library behaves
/// like the client list: a phone pushes, a tablet fills the pane beside it.

const _programs = [
  ProgramSummary(id: 3, name: 'Base building', weeksCount: 8, activeAssignmentCount: 2),
  ProgramSummary(id: 5, name: 'Peak block', weeksCount: 4),
];

/// `programsProvider` is a FutureProvider, so the test drives it from a
/// notifier it can write to instead of poking the provider itself.
class _ProgramsSource extends Notifier<List<ProgramSummary>> {
  @override
  List<ProgramSummary> build() => _programs;

  void set(List<ProgramSummary> programs) => state = programs;
}

final _programsSourceProvider =
    NotifierProvider<_ProgramsSource, List<ProgramSummary>>(_ProgramsSource.new);

final _pushed = <String>[];

Future<void> _pump(WidgetTester tester, {required Size size}) async {
  _pushed.clear();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = GoRouter(routes: [
    GoRoute(
      path: trainerProgramsLocation,
      builder: (_, __) => const ProgramsScreen(),
      routes: [
        GoRoute(
          path: ':programId',
          builder: (_, state) {
            _pushed.add(state.pathParameters['programId']!);
            return const Scaffold(body: Text('pushed detail'));
          },
        ),
      ],
    ),
  ], initialLocation: trainerProgramsLocation);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      programsProvider.overrideWith((ref) async => ref.watch(_programsSourceProvider)),
      isOfflineProvider.overrideWith((ref) => Stream.value(false)),
      unreadBadgeProvider.overrideWith((ref) => Stream.value(0)),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  ));
  await tester.pumpAndSettle();
}

const _phone = Size(390, 844);
const _tablet = Size(1194, 834);

void main() {
  /// The embedded detail fetches the program, which never settles under test.
  Future<void> tapProgram(WidgetTester tester, String name) async {
    await tester.tap(find.text(name));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(ProgramsScreen)));

  testWidgets('on a phone, a program still opens as its own screen', (tester) async {
    await _pump(tester, size: _phone);

    await tapProgram(tester, 'Base building');

    expect(_pushed, ['3']);
    expect(find.byType(TrainerTwoPane), findsNothing);
  });

  testWidgets('on a tablet, the library stays beside the program', (tester) async {
    await _pump(tester, size: _tablet);

    expect(find.byType(TrainerTwoPane), findsOneWidget);
    expect(find.textContaining('Pick a program'), findsOneWidget);

    await tapProgram(tester, 'Base building');

    expect(_pushed, isEmpty);
    expect(containerOf(tester).read(selectedProgramControllerProvider), 3);
    expect(find.text('Peak block'), findsOneWidget);
  });

  testWidgets('a program that disappeared from the library empties the pane',
      (tester) async {
    await _pump(tester, size: _tablet);
    await tapProgram(tester, 'Peak block');

    final container = containerOf(tester);
    container.read(_programsSourceProvider.notifier).set([_programs.first]);
    await tester.pump();
    await tester.pump();

    expect(container.read(selectedProgramControllerProvider), isNull);
    expect(find.textContaining('Pick a program'), findsOneWidget);
  });
}
