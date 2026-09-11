import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/features/chat/data/chat_repository.dart';
import 'package:lifey/features/trainer/client_detail/data/client_detail_repository.dart';
import 'package:lifey/features/trainer/client_detail/domain/client_workout_session.dart';
import 'package:lifey/features/trainer/client_detail/presentation/tabs/workouts_tab.dart';
import 'package:lifey/l10n/app_localizations.dart';

ClientWorkoutSession _session({
  int id = 1,
  String? templateName = 'Push day',
  String? comment,
  int? rpe,
  String? note,
  List<ClientSessionSet> sets = const [],
}) {
  return ClientWorkoutSession(
    id: id,
    startedAt: DateTime(2026, 7, 8, 17),
    finishedAt: DateTime(2026, 7, 8, 18),
    templateName: templateName,
    exercises: const [
      ClientSessionExercise(exerciseId: 1, exerciseName: 'Bench press'),
    ],
    sets: sets,
    rpe: rpe,
    feedbackNote: note,
    trainerComment: comment,
    trainerCommentAt: comment == null ? null : DateTime(2026, 7, 9, 10),
  );
}

class _FakeDetailRepository extends ClientDetailRepository {
  _FakeDetailRepository({this.sessions = const [], this.fail = false})
      : super(Dio());

  final List<ClientWorkoutSession> sessions;
  final bool fail;

  Object? commentFailure;
  final List<String> writes = [];

  @override
  Future<ClientSessionPage> fetchWorkoutSessions(
    int clientId, {
    int page = 0,
    int size = 20,
  }) async {
    if (fail) throw Exception('boom');
    return ClientSessionPage(sessions: page == 0 ? sessions : const [], isLast: true);
  }

  @override
  Future<ClientWorkoutSession> putSessionComment(
    int clientId,
    int sessionId,
    String comment,
  ) async {
    if (commentFailure != null) throw commentFailure!;
    writes.add(comment);
    final existing = sessions.firstWhere((s) => s.id == sessionId);
    return ClientWorkoutSession(
      id: existing.id,
      startedAt: existing.startedAt,
      finishedAt: existing.finishedAt,
      templateName: existing.templateName,
      exercises: existing.exercises,
      sets: existing.sets,
      rpe: existing.rpe,
      feedbackNote: existing.feedbackNote,
      trainerComment: comment,
      trainerCommentAt: DateTime(2026, 7, 9, 10),
    );
  }
}

class _FakeChatRepository extends ChatRepository {
  _FakeChatRepository(AppDatabase db) : super(db, Dio(), () => 7);

  int? openedWith;

  @override
  Future<int> openConversationWith(int peerUserId) async {
    openedWith = peerUserId;
    return 99;
  }
}

late AppDatabase _db;
late _FakeChatRepository _chat;
String? _lastChatDraft;

Future<void> _pump(
  WidgetTester tester, {
  List<ClientWorkoutSession> sessions = const [],
  bool fail = false,
  bool offline = false,
  _FakeDetailRepository? repository,
}) async {
  _lastChatDraft = null;
  final repo = repository ?? _FakeDetailRepository(sessions: sessions, fail: fail);

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: ClientWorkoutsTab(clientId: 5, offline: offline),
        ),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (context, state) {
          _lastChatDraft = state.extra as String?;
          return const Scaffold(body: Text('chat thread'));
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clientDetailRepositoryProvider.overrideWithValue(repo),
        chatRepositoryProvider.overrideWithValue(_chat),
      ],
      child: MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    _db = AppDatabase(NativeDatabase.memory());
    _chat = _FakeChatRepository(_db);
  });
  tearDown(() => _db.close());

  group('the list', () {
    testWidgets('shows a card per session with its signals', (tester) async {
      await _pump(tester, sessions: [
        _session(id: 1, rpe: 8, note: 'Tough one'),
        _session(id: 2, templateName: 'Pull day', comment: 'Nice pace'),
      ]);

      expect(find.text('Push day'), findsOneWidget);
      expect(find.text('Pull day'), findsOneWidget);
      expect(find.text('RPE 8'), findsOneWidget);
      expect(find.text('Note'), findsOneWidget);
      // The "already answered" marker — what stops the trainer re-reading the
      // same session every day.
      expect(find.text('Your comment'), findsOneWidget);
    });

    testWidgets('a session with no template is named as a free workout',
        (tester) async {
      await _pump(tester, sessions: [_session(templateName: null)]);

      expect(find.text('Free workout'), findsOneWidget);
    });

    testWidgets('says so when the client has never finished a workout',
        (tester) async {
      await _pump(tester);

      expect(find.text('No workouts yet'), findsOneWidget);
    });

    testWidgets('a failed load offers a retry', (tester) async {
      await _pump(tester, fail: true);

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('offline says so instead of showing a network error',
        (tester) async {
      await _pump(tester, fail: true, offline: true);

      expect(find.text('No connection'), findsOneWidget);
      expect(find.text('Something went wrong'), findsNothing);
    });
  });

  group('the detail sheet', () {
    testWidgets('opens with the sets and what the client said', (tester) async {
      await _pump(tester, sessions: [
        _session(
          rpe: 8,
          note: 'Tough one',
          sets: const [
            ClientSessionSet(
                exerciseId: 1, exerciseName: 'Bench press', reps: 10, weight: 60),
            ClientSessionSet(
                exerciseId: 1, exerciseName: 'Bench press', reps: 8, weight: 65),
          ],
        ),
      ]);

      await tester.tap(find.text('Push day'));
      await tester.pumpAndSettle();

      expect(find.text('What your client said'), findsOneWidget);
      expect(find.text('Difficulty: 8/10'), findsOneWidget);
      expect(find.text('Tough one'), findsOneWidget);
      expect(find.text('Bench press'), findsOneWidget);
      expect(find.text('10 × 60.0 kg'), findsOneWidget);
      expect(find.text('8 × 65.0 kg'), findsOneWidget);
    });

    testWidgets('an exercise with no logged sets says so', (tester) async {
      await _pump(tester, sessions: [_session()]);

      await tester.tap(find.text('Push day'));
      await tester.pumpAndSettle();

      expect(find.text('No sets logged'), findsOneWidget);
    });
  });

  group('the comment', () {
    testWidgets('a first comment is saved and reports the client was notified',
        (tester) async {
      final repo = _FakeDetailRepository(sessions: [_session()]);
      await _pump(tester, repository: repo);

      await tester.tap(find.text('Push day'));
      await tester.pumpAndSettle();
      expect(find.text("You haven't commented on this workout."), findsOneWidget);

      await tester.tap(find.text('Add comment'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Nice pace');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repo.writes, ['Nice pace']);
      expect(
        find.text('Comment saved — your client was notified.'),
        findsOneWidget,
      );
    });

    testWidgets('editing an existing comment does not claim a notification',
        (tester) async {
      final repo = _FakeDetailRepository(
        sessions: [_session(comment: 'Typo here')],
      );
      await _pump(tester, repository: repo);

      await tester.tap(find.text('Push day'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit comment'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Typo fixed');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Comment saved.'), findsOneWidget);
      expect(find.text('Comment saved — your client was notified.'), findsNothing);
    });

    testWidgets('a failed save keeps the sheet open with the text intact',
        (tester) async {
      final repo = _FakeDetailRepository(sessions: [_session()]);
      repo.commentFailure = Exception('500');
      await _pump(tester, repository: repo);

      await tester.tap(find.text('Push day'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add comment'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Nice pace');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // No optimistic UI: nothing may look saved, and the words are not lost.
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Nice pace'), findsOneWidget);
      expect(find.text('Comment saved — your client was notified.'), findsNothing);
    });
  });

  group('the jump to chat', () {
    testWidgets('opens the thread with a draft naming the session',
        (tester) async {
      await _pump(tester, sessions: [_session()]);

      await tester.tap(find.text('Push day'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Message them too'));
      await tester.pumpAndSettle();

      expect(_chat.openedWith, 5);
      expect(find.text('chat thread'), findsOneWidget);
      // The draft names *which* workout — "about your workout" with no date
      // would land in the client's thread meaning nothing.
      expect(_lastChatDraft, contains('Jul 8, 2026'));
    });
  });
}
