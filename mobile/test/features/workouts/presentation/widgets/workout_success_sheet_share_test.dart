import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/features/chat/application/chat_share.dart';
import 'package:lifey/features/chat/domain/chat_card.dart';
import 'package:lifey/features/chat/domain/chat_peer.dart';
import 'package:lifey/features/chat/presentation/widgets/chat_card_view.dart';
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/workouts/domain/personal_record.dart';
import 'package:lifey/features/workouts/presentation/widgets/workout_success_sheet.dart';
import 'package:lifey/l10n/app_localizations.dart';

/// Sharing from the end-of-workout sheet (docs/chat/83-chat-result-card-plan.md §4):
/// the whole workout, and each record on its own.
class _MetricSettings extends SettingsController {
  @override
  Stream<UserSettings> build() => Stream.value(const UserSettings.defaults());
}

const _result = WorkoutProgressResult(
  score: 3,
  improvements: [],
  records: [
    WorkoutPrRow(
      exerciseName: 'Bench Press',
      chips: ['102.5 kg'],
      entries: [
        WorkoutRecordEntry(type: PrType.maxWeight, weight: 102.5, reps: 3, value: 102.5, delta: 2.5),
        WorkoutRecordEntry(type: PrType.estimatedOneRm, weight: 102.5, reps: 3, value: 112.75, delta: 4),
      ],
    ),
  ],
);

final _summary = WorkoutSummary(
  title: 'Push day',
  duration: const Duration(minutes: 58),
  volume: 4280,
  startedAt: DateTime(2026, 10, 3, 7),
  exerciseCount: 4,
  sessionClientId: 'client-1',
);

Future<void> _pump(
  WidgetTester tester, {
  WorkoutShareConfig? share,
  List<ChatShareTarget> targets = const [],
}) async {
  tester.view.physicalSize = const Size(411 * 2.625, 923 * 2.625);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      chatShareTargetsProvider.overrideWith((ref) async => targets),
      settingsControllerProvider.overrideWith(_MetricSettings.new),
    ],
    child: MaterialApp(
      theme: AppTheme.dark,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () => showWorkoutSuccessSheet(context, _result, summary: _summary, share: share),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

ChatShareTarget get _someone => ChatShareTarget(
      peer: const ChatPeer(userId: 50, displayName: 'Edző Elek', email: 'e@example.com', role: ChatPeerRole.trainer),
      conversationId: 1,
    );

void main() {
  const share = WorkoutShareConfig(resolveSessionId: _noSession);

  testWidgets('no share config, no share buttons — the sheet is exactly what it was', (tester) async {
    await _pump(tester, targets: [_someone]);

    expect(find.byIcon(Icons.ios_share_rounded), findsNothing);
    expect(find.text('Share in chat'), findsNothing);
  });

  testWidgets('with nobody to send to the buttons are not drawn', (tester) async {
    await _pump(tester, share: share);

    expect(find.byIcon(Icons.ios_share_rounded), findsNothing);
    expect(find.text('Share in chat'), findsNothing);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('with a trainer: one button for the workout and one icon per record', (tester) async {
    await _pump(tester, share: share, targets: [_someone]);

    expect(find.text('Share in chat'), findsOneWidget);
    // The labelled button's icon plus one per record row (two records).
    expect(find.byIcon(Icons.ios_share_rounded), findsNWidgets(3));
  });

  testWidgets('the workout button previews the whole-workout card', (tester) async {
    await _pump(tester, share: share, targets: [_someone]);

    await tester.tap(find.text('Share in chat'));
    await tester.pumpAndSettle();

    final preview = tester.widget<ChatCardView>(find.byType(ChatCardView)).card as WorkoutChatCard;
    expect(preview.title, 'Push day');
    expect(preview.durationSeconds, 58 * 60);
    expect(preview.volumeKg, 4280);
    expect(preview.exerciseCount, 4);
    expect(preview.recordCount, 2);
    expect(preview.sessionId, isNull, reason: 'resolved at send time');
  });

  testWidgets('a record row previews that record on its own, with how far it moved', (tester) async {
    await _pump(tester, share: share, targets: [_someone]);

    await tester.tap(find.byTooltip('Share this record in chat').first);
    await tester.pumpAndSettle();

    final preview = tester.widget<ChatCardView>(find.byType(ChatCardView)).card as PrChatCard;
    expect(preview.exerciseName, 'Bench Press');
    expect(preview.prKind, ChatPrKind.maxWeight);
    expect(preview.value, 102.5);
    expect(preview.previousValue, 100);
  });
}

Future<int?> _noSession() async => null;
