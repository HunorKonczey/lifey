import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/features/chat/application/chat_share.dart';
import 'package:lifey/features/chat/domain/chat_card.dart';
import 'package:lifey/features/chat/domain/chat_peer.dart';
import 'package:lifey/features/chat/presentation/share_to_chat_sheet.dart';
import 'package:lifey/features/chat/presentation/widgets/chat_card_view.dart';
import 'package:lifey/features/chat/presentation/widgets/share_to_chat_buttons.dart';
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/l10n/app_localizations.dart';

class _MetricSettings extends SettingsController {
  @override
  Stream<UserSettings> build() => Stream.value(const UserSettings.defaults());
}

class _RecordingShare implements ChatShareService {
  final calls = <({ChatShareTarget target, ChatCard card, String caption})>[];
  Completer<int>? gate;
  Object? failure;

  @override
  Future<int> share({
    required ChatShareTarget target,
    required ChatCard card,
    String caption = '',
    Future<int?> Function()? resolveSessionId,
  }) async {
    calls.add((target: target, card: card, caption: caption));
    if (failure != null) throw failure!;
    if (gate != null) return gate!.future;
    return target.conversationId ?? 999;
  }
}

ChatShareTarget _target(int userId, String name, {int? conversationId}) => ChatShareTarget(
      peer: ChatPeer(userId: userId, displayName: name, email: '$userId@example.com', role: ChatPeerRole.trainer),
      conversationId: conversationId,
    );

final _card = WorkoutChatCard(
  occurredAt: DateTime.utc(2026, 10, 3, 7),
  workoutKind: ChatWorkoutKind.strength,
  title: 'Push day',
  durationSeconds: 3600,
);

/// A page with one button that opens the sheet, the way an entry point does.
Future<_RecordingShare> _pump(
  WidgetTester tester, {
  required List<ChatShareTarget> targets,
  _RecordingShare? share,
}) async {
  final fake = share ?? _RecordingShare();
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (context, _) => Scaffold(
        body: Center(
          child: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => showShareToChatSheet(context, card: _card),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
    GoRoute(path: '/chat/:id', builder: (_, state) => Scaffold(body: Text('thread ${state.pathParameters['id']}'))),
  ]);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        chatShareTargetsProvider.overrideWith((ref) async => targets),
        chatShareServiceProvider.overrideWithValue(fake),
        settingsControllerProvider.overrideWith(_MetricSettings.new),
      ],
      child: MaterialApp.router(
        theme: AppTheme.dark,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets('shows the card as it will arrive, a note field and Send', (tester) async {
    await _pump(tester, targets: [_target(50, 'Edző Elek', conversationId: 1)]);

    expect(find.text('Share in chat'), findsOneWidget);
    expect(find.byType(ChatCardView), findsOneWidget);
    expect(find.text('Push day'), findsOneWidget);
    expect(find.text('Add a note (optional)'), findsOneWidget);
    expect(find.text('Send'), findsOneWidget);
  });

  testWidgets('one person: nobody to choose, the card goes straight to them', (tester) async {
    final share = await _pump(tester, targets: [_target(50, 'Edző Elek', conversationId: 1)]);

    expect(find.text('Send to'), findsNothing);
    await tester.enterText(find.byType(TextField), 'Nézd!');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(share.calls.single.target.peer.userId, 50);
    expect(share.calls.single.caption, 'Nézd!');
    expect((share.calls.single.card as WorkoutChatCard).title, 'Push day');
    // The sheet closed and the caller confirmed on its own snackbar.
    expect(find.text('Share in chat'), findsNothing);
    expect(find.text('Shared with Edző Elek'), findsOneWidget);
  });

  testWidgets('several people: the newest thread is preselected and the choice is honoured', (tester) async {
    final share = await _pump(tester, targets: [
      _target(50, 'Edző Elek', conversationId: 1),
      _target(60, 'Másik Edző'),
    ]);

    expect(find.text('Send to'), findsOneWidget);
    expect(find.text('Edző Elek'), findsOneWidget);
    expect(find.text('Másik Edző'), findsOneWidget);

    await tester.tap(find.text('Másik Edző'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(share.calls.single.target.peer.userId, 60);
  });

  testWidgets('the default is the first person, without touching the list', (tester) async {
    final share = await _pump(tester, targets: [
      _target(50, 'Edző Elek', conversationId: 1),
      _target(60, 'Másik Edző'),
    ]);

    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(share.calls.single.target.peer.userId, 50);
  });

  testWidgets('Open chat on the confirmation goes to the thread it was sent to', (tester) async {
    await _pump(tester, targets: [_target(50, 'Edző Elek', conversationId: 12)]);

    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open chat'));
    await tester.pumpAndSettle();

    expect(find.text('thread 12'), findsOneWidget);
  });

  testWidgets('Send is disabled while sending, so a double tap cannot send twice', (tester) async {
    final share = _RecordingShare()..gate = Completer<int>();
    await _pump(tester, targets: [_target(50, 'Edző Elek', conversationId: 1)], share: share);

    await tester.tap(find.text('Send'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pump();

    expect(share.calls, hasLength(1));
    share.gate!.complete(1);
    await tester.pumpAndSettle();
  });

  testWidgets('a failure keeps the sheet open and says so, so the person can try again', (tester) async {
    final share = _RecordingShare()..failure = Exception('offline');
    await _pump(tester, targets: [_target(60, 'Új Edző')], share: share);

    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(find.text('Share in chat'), findsOneWidget);
    expect(find.text('Send'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  group('the entry-point buttons', () {
    Future<void> pumpButtons(WidgetTester tester, List<ChatShareTarget> targets) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [chatShareTargetsProvider.overrideWith((ref) async => targets)],
          child: MaterialApp(
            theme: AppTheme.dark,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Column(children: [
                ShareToChatIconButton(buildCard: () => _card),
                ShareToChatButton(buildCard: () => _card),
              ]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('are hidden — not disabled — when there is nobody to send to', (tester) async {
      await pumpButtons(tester, const []);

      expect(find.byIcon(Icons.ios_share_rounded), findsNothing);
      expect(find.text('Share in chat'), findsNothing);
    });

    testWidgets('appear once there is somebody', (tester) async {
      await pumpButtons(tester, [_target(50, 'Edző Elek', conversationId: 1)]);

      expect(find.byIcon(Icons.ios_share_rounded), findsNWidgets(2));
      expect(find.text('Share in chat'), findsOneWidget);
    });
  });
}
