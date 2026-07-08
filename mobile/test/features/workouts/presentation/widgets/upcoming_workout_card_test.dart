import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/trainer_invite/application/trainer_invite_controller.dart';
import 'package:lifey/features/trainer_invite/domain/trainer_invite.dart';
import 'package:lifey/features/workouts/application/workout_session_controller.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';
import 'package:lifey/features/workouts/presentation/widgets/upcoming_workout_card.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

WorkoutSession _today({String? name, String? scheduledTime}) {
  final now = DateTime.now();
  return WorkoutSession(
    clientId: 'c-${scheduledTime ?? 'none'}-$name',
    exercises: const [],
    sets: const [],
    scheduledFor: DateTime(now.year, now.month, now.day),
    scheduledTime: scheduledTime,
    templateName: name,
  );
}

class _FakeWorkoutSessionController extends WorkoutSessionController {
  _FakeWorkoutSessionController(this._sessions);

  final List<WorkoutSession> _sessions;

  @override
  Stream<List<WorkoutSession>> build() => Stream.value(_sessions);
}

class _FakeTrainerInviteController extends TrainerInviteController {
  _FakeTrainerInviteController(this._invites);

  final List<TrainerInvite> _invites;

  @override
  Future<List<TrainerInvite>> build() async => _invites;
}

Future<void> _pumpCard(
  WidgetTester tester, {
  required List<WorkoutSession> sessions,
  List<TrainerInvite> invites = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workoutSessionControllerProvider
            .overrideWith(() => _FakeWorkoutSessionController(sessions)),
        trainerInviteControllerProvider.overrideWith(() => _FakeTrainerInviteController(invites)),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: UpcomingWorkoutCard()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders nothing when there is no session scheduled for today', (tester) async {
    await _pumpCard(tester, sessions: const []);

    expect(find.byType(Dismissible), findsNothing);
  });

  testWidgets('shows the title without a time when the schedule has none', (tester) async {
    await _pumpCard(tester, sessions: [_today(name: 'Leg day')]);

    expect(find.text('Today: Leg day'), findsOneWidget);
  });

  testWidgets('shows the title with the scheduled time when set', (tester) async {
    await _pumpCard(tester, sessions: [_today(name: 'Leg day', scheduledTime: '18:00')]);

    expect(find.text('Today 18:00: Leg day'), findsOneWidget);
  });

  testWidgets('shows the earliest-by-time session and a "+N more" hint for extra ones',
      (tester) async {
    await _pumpCard(tester, sessions: [
      _today(name: 'Evening run', scheduledTime: '18:00'),
      _today(name: 'Morning stretch', scheduledTime: '07:00'),
    ]);

    expect(find.text('Today 07:00: Morning stretch'), findsOneWidget);
    expect(find.text('+1 more today'), findsOneWidget);
  });

  testWidgets('tapping Later dismisses the card', (tester) async {
    await _pumpCard(tester, sessions: [_today(name: 'Leg day')]);
    expect(find.byType(Dismissible), findsOneWidget);

    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();

    expect(find.byType(Dismissible), findsNothing);
  });

  testWidgets('dismissal persists for the rest of the day across a fresh card instance',
      (tester) async {
    await _pumpCard(tester, sessions: [_today(name: 'Leg day')]);
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();

    // Simulate the app being relaunched (a brand-new ProviderScope/widget
    // tree) later the same day — SharedPreferences is the only thing that
    // survives, same as on a real device.
    await _pumpCard(tester, sessions: [_today(name: 'Leg day')]);

    expect(find.byType(Dismissible), findsNothing);
  });

  testWidgets('swipe-dismissing the card also persists the dismissal', (tester) async {
    await _pumpCard(tester, sessions: [_today(name: 'Leg day')]);

    await tester.drag(find.byType(Dismissible), const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(find.byType(Dismissible), findsNothing);

    await _pumpCard(tester, sessions: [_today(name: 'Leg day')]);
    expect(find.byType(Dismissible), findsNothing);
  });

  testWidgets('a pending trainer invite suppresses the card even with a today session',
      (tester) async {
    await _pumpCard(
      tester,
      sessions: [_today(name: 'Leg day')],
      invites: [
        TrainerInvite(
          id: 1,
          trainerEmail: 'trainer@example.com',
          invitedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(hours: 12)),
        ),
      ],
    );

    expect(find.byType(Dismissible), findsNothing);
  });
}
