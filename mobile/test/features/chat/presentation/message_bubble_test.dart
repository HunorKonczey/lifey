import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/chat/domain/chat_message.dart';
import 'package:lifey/features/chat/presentation/widgets/message_bubble.dart';
import 'package:lifey/l10n/app_localizations.dart';

ChatMessage _message({
  ChatMessageState state = ChatMessageState.sent,
  String? body = 'Holnap 17:00 jó?',
  DateTime? deletedAt,
  int? serverId = 4310,
}) {
  return ChatMessage(
    clientId: 'uuid-1',
    serverId: serverId,
    conversationId: 12,
    senderId: 7,
    body: body,
    createdAt: DateTime(2026, 8, 6, 14, 32),
    deletedAt: deletedAt,
    state: state,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required ChatMessage message,
  bool isOwn = true,
  bool showTail = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MessageBubble(
          message: message,
          isOwn: isOwn,
          senderName: 'Kiss Anna',
          showTail: showTail,
          showAvatar: !isOwn && showTail,
          peerMonogram: 'KA',
          onRetry: () {},
          onDelete: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('status icons on own messages', () {
    testWidgets('an unsent message shows the clock', (tester) async {
      await _pump(tester, message: _message(state: ChatMessageState.pending, serverId: null));

      expect(find.byIcon(Icons.schedule), findsOneWidget);
    });

    testWidgets('a sent message shows a single check', (tester) async {
      await _pump(tester, message: _message(state: ChatMessageState.sent));

      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.byIcon(Icons.done_all), findsNothing);
    });

    testWidgets('a delivered message shows a double check', (tester) async {
      await _pump(tester, message: _message(state: ChatMessageState.delivered));

      expect(find.byIcon(Icons.done_all), findsOneWidget);
    });

    testWidgets('a failed message shows the error icon', (tester) async {
      await _pump(tester, message: _message(state: ChatMessageState.failed, serverId: null));

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('a read message uses the accent colour, not just the same icon',
        (tester) async {
      // Shape alone can't separate delivered from read, so this is the one
      // place colour carries meaning — and it must actually be applied.
      await _pump(tester, message: _message(state: ChatMessageState.read));

      final icon = tester.widget<Icon>(find.byIcon(Icons.done_all));
      final context = tester.element(find.byIcon(Icons.done_all));
      expect(icon.color, Theme.of(context).colorScheme.primary);
    });
  });

  testWidgets('a received message carries no status at all', (tester) async {
    await _pump(tester, message: _message(state: ChatMessageState.sent), isOwn: false);

    expect(find.byIcon(Icons.check), findsNothing);
    expect(find.byIcon(Icons.done_all), findsNothing);
    expect(find.byIcon(Icons.schedule), findsNothing);
  });

  testWidgets('a deleted message renders the tombstone instead of its text', (tester) async {
    await _pump(
      tester,
      message: _message(body: null, deletedAt: DateTime(2026, 8, 6, 15)),
    );

    expect(find.text('This message was deleted'), findsOneWidget);
    expect(find.text('Holnap 17:00 jó?'), findsNothing);
  });

  testWidgets('only the last bubble of a run shows the time and status', (tester) async {
    await _pump(tester, message: _message(), showTail: false);

    expect(find.text('14:32'), findsNothing);
    expect(find.byIcon(Icons.check), findsNothing);
  });

  testWidgets('the long-press menu offers resend only on a failed message', (tester) async {
    await _pump(tester, message: _message(state: ChatMessageState.failed, serverId: null));
    await tester.longPress(find.text('Holnap 17:00 jó?'));
    await tester.pumpAndSettle();

    expect(find.text('Resend'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('a successfully sent message has no resend action', (tester) async {
    await _pump(tester, message: _message(state: ChatMessageState.sent));
    await tester.longPress(find.text('Holnap 17:00 jó?'));
    await tester.pumpAndSettle();

    expect(find.text('Resend'), findsNothing);
    expect(find.text('Copy'), findsOneWidget);
  });

  testWidgets('a deleted message has no long-press menu', (tester) async {
    await _pump(tester, message: _message(body: null, deletedAt: DateTime(2026, 8, 6, 15)));
    await tester.longPress(find.text('This message was deleted'));
    await tester.pumpAndSettle();

    expect(find.text('Copy'), findsNothing);
  });

  testWidgets('the bubble announces sender, time, text and status to a screen reader',
      (tester) async {
    // The ticks are purely visual; without this a screen-reader user has no
    // way to know whether their message got through.
    final handle = tester.ensureSemantics();
    await _pump(tester, message: _message(state: ChatMessageState.sent), isOwn: false);

    expect(
      find.bySemanticsLabel('Kiss Anna, 14:32: Holnap 17:00 jó?, '),
      findsOneWidget,
    );
    handle.dispose();
  });
}
