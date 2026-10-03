import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/features/chat/application/open_chat_card.dart';
import 'package:lifey/features/chat/domain/chat_card.dart';
import 'package:lifey/features/chat/domain/chat_message.dart';
import 'package:lifey/features/chat/domain/chat_peer.dart';
import 'package:lifey/features/chat/presentation/widgets/chat_card_view.dart';
import 'package:lifey/features/chat/presentation/widgets/message_bubble.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/l10n/app_localizations.dart';

final _when = DateTime(2026, 10, 3, 9, 12);

WorkoutChatCard _strength({int? sessionId = 481, int? records = 2, String? title = 'Push day'}) =>
    WorkoutChatCard(
      occurredAt: _when,
      sessionId: sessionId,
      workoutKind: ChatWorkoutKind.strength,
      title: title,
      durationSeconds: 3600,
      volumeKg: 8450,
      exerciseCount: 6,
      recordCount: records,
    );

WorkoutChatCard _cardio() => WorkoutChatCard(
      occurredAt: _when,
      sessionId: 482,
      workoutKind: ChatWorkoutKind.cardio,
      title: 'Easy run',
      durationSeconds: 1800,
      distanceMeters: 5200,
    );

PrChatCard _pr({ChatPrKind kind = ChatPrKind.maxWeight, double? previous = 100}) => PrChatCard(
      occurredAt: _when,
      sessionId: 481,
      exerciseName: 'Bench press',
      prKind: kind,
      value: kind == ChatPrKind.repsAtWeight ? 8 : 102.5,
      previousValue: kind == ChatPrKind.repsAtWeight && previous != null ? 6 : previous,
      weightKg: 80,
      reps: 3,
    );

Future<void> _pumpCard(
  WidgetTester tester,
  ChatCard card, {
  String locale = 'en',
  ThemeData? theme,
  VoidCallback? onTap,
  bool isOwn = false,
  String? caption,
  UnitSystem unitSystem = UnitSystem.metric,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.dark,
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: ChatCardView(
            card: card,
            isOwn: isOwn,
            caption: caption,
            unitSystem: unitSystem,
            onTap: onTap,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('workout card', () {
    testWidgets('shows the name, the numbers and the record chip', (tester) async {
      await _pumpCard(tester, _strength());

      expect(find.text('WORKOUT'), findsOneWidget);
      expect(find.text('Push day'), findsOneWidget);
      expect(find.text('60 min · 8,450 kg volume · 6 exercises'), findsOneWidget);
      expect(find.text('2 records'), findsOneWidget);
      expect(find.text('Oct 3'), findsOneWidget);
    });

    testWidgets('reads in Hungarian for a Hungarian reader', (tester) async {
      await _pumpCard(tester, _strength(), locale: 'hu');

      expect(find.text('EDZÉS'), findsOneWidget);
      expect(find.textContaining('6 gyakorlat'), findsOneWidget);
      expect(find.text('2 rekord'), findsOneWidget);
    });

    testWidgets('an unnamed session falls back to the kind, and drops a zero chip', (tester) async {
      await _pumpCard(tester, _strength(title: null, records: 0));

      expect(find.text('Workout'), findsOneWidget); // the title; the overline is upper-case
      expect(find.textContaining('record'), findsNothing);
    });

    testWidgets('a cardio card shows duration and distance in the reader\'s units', (tester) async {
      await _pumpCard(tester, _cardio());
      expect(find.text('CARDIO'), findsOneWidget);
      expect(find.textContaining('5.20 km'), findsOneWidget);

      await _pumpCard(tester, _cardio(), unitSystem: UnitSystem.imperial);
      expect(find.textContaining('mi'), findsOneWidget);
      expect(find.textContaining('km'), findsNothing);
    });

    testWidgets('a caption is shown inside the card', (tester) async {
      await _pumpCard(tester, _strength(), caption: 'Végre!');

      expect(find.text('Végre!'), findsOneWidget);
    });
  });

  group('record card', () {
    testWidgets('shows the new value and how far it moved the old one', (tester) async {
      await _pumpCard(tester, _pr());

      expect(find.text('PERSONAL RECORD'), findsOneWidget);
      expect(find.text('Bench press'), findsOneWidget);
      expect(find.text('102.5 kg'), findsOneWidget);
      expect(find.text('+2.5 kg'), findsOneWidget);
      expect(find.text('Heaviest set'), findsOneWidget);
    });

    testWidgets('the first record of an exercise claims no improvement', (tester) async {
      await _pumpCard(tester, _pr(previous: null));

      expect(find.text('102.5 kg'), findsOneWidget);
      expect(find.textContaining('+'), findsNothing);
    });

    testWidgets('a reps record counts in reps and names the weight', (tester) async {
      await _pumpCard(tester, _pr(kind: ChatPrKind.repsAtWeight));

      expect(find.text('8 reps'), findsOneWidget);
      expect(find.text('+2 reps'), findsOneWidget);
      expect(find.text('Most reps at 80 kg'), findsOneWidget);
    });

    testWidgets('an estimated 1RM names itself', (tester) async {
      await _pumpCard(tester, _pr(kind: ChatPrKind.estimatedOneRm));

      expect(find.text('Estimated 1RM'), findsOneWidget);
    });
  });

  group('unknown card', () {
    testWidgets('says to update the app instead of drawing numbers', (tester) async {
      await _pumpCard(
        tester,
        UnknownChatCard(kind: 'MEAL', occurredAt: _when, raw: const {'kind': 'MEAL'}),
      );

      expect(find.text('Update the app to see this card'), findsOneWidget);
      expect(find.text('Oct 3'), findsNothing);
    });
  });

  group('tap', () {
    testWidgets('a tappable card shows a chevron and calls back', (tester) async {
      var taps = 0;
      await _pumpCard(tester, _strength(), onTap: () => taps++);

      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      await tester.tap(find.text('Push day'));
      expect(taps, 1);
    });

    testWidgets('a static card has no chevron', (tester) async {
      await _pumpCard(tester, _strength());

      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });
  });

  group('both themes', () {
    for (final entry in {'dark': AppTheme.dark, 'light': AppTheme.light}.entries) {
      testWidgets('${entry.key}: every kind builds without overflow', (tester) async {
        for (final card in <ChatCard>[_strength(), _cardio(), _pr()]) {
          await _pumpCard(tester, card, theme: entry.value, isOwn: true, onTap: () {});
          expect(tester.takeException(), isNull);
        }
      });
    }
  });

  group('inside the thread', () {
    ChatMessage message({ChatCard? card, String? body, DateTime? deletedAt}) => ChatMessage(
          clientId: 'c1',
          serverId: 4400,
          conversationId: 12,
          senderId: 88,
          body: body,
          createdAt: DateTime(2026, 10, 3, 9, 15),
          deletedAt: deletedAt,
          state: ChatMessageState.sent,
          card: card,
        );

    Future<void> pumpBubble(WidgetTester tester, ChatMessage m, {VoidCallback? onCardTap}) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MessageBubble(
              message: m,
              isOwn: false,
              senderName: 'Kiss Anna',
              showTail: true,
              onCardTap: onCardTap,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a card message draws the card, not an empty bubble', (tester) async {
      await pumpBubble(tester, message(card: _pr()));

      expect(find.byType(ChatCardView), findsOneWidget);
      expect(find.text('Bench press'), findsOneWidget);
    });

    testWidgets('a deleted card message is just the tombstone — the numbers are gone', (tester) async {
      await pumpBubble(tester, message(card: null, deletedAt: DateTime(2026, 10, 3, 10)));

      expect(find.byType(ChatCardView), findsNothing);
      expect(find.text('This message was deleted'), findsOneWidget);
    });

    testWidgets('even a stale card with a deleted stamp does not draw', (tester) async {
      await pumpBubble(tester, message(card: _pr(), deletedAt: DateTime(2026, 10, 3, 10)));

      expect(find.byType(ChatCardView), findsNothing);
    });

    testWidgets('the bubble\'s tap goes to the card', (tester) async {
      var taps = 0;
      await pumpBubble(tester, message(card: _strength()), onCardTap: () => taps++);

      await tester.tap(find.text('Push day'));
      expect(taps, 1);
    });

    testWidgets('the card is announced as something, with its numbers', (tester) async {
      await pumpBubble(tester, message(card: _pr()));

      final semantics = tester.getSemantics(find.byType(MessageBubble));
      expect(semantics.label, contains('Personal record'));
      expect(semantics.label, contains('Bench press'));
    });
  });

  group('who may open a card (docs/chat/83 §2.7)', () {
    test('the sender opens their own, a trainer opens a client\'s', () {
      expect(canOpenChatCard(card: _strength(), isOwn: true, peerRole: ChatPeerRole.trainer), isTrue);
      expect(canOpenChatCard(card: _strength(), isOwn: true, peerRole: ChatPeerRole.client), isTrue);
      expect(canOpenChatCard(card: _strength(), isOwn: false, peerRole: ChatPeerRole.client), isTrue);
    });

    test('a client cannot open a card from their trainer', () {
      expect(canOpenChatCard(card: _strength(), isOwn: false, peerRole: ChatPeerRole.trainer), isFalse);
    });

    test('a card that never got a session id has nowhere to go', () {
      expect(canOpenChatCard(card: _strength(sessionId: null), isOwn: true, peerRole: ChatPeerRole.trainer), isFalse);
    });

    test('an unknown kind is never a door', () {
      final unknown = UnknownChatCard(kind: 'MEAL', occurredAt: _when, raw: const {});
      expect(canOpenChatCard(card: unknown, isOwn: true, peerRole: ChatPeerRole.trainer), isFalse);
    });
  });
}
