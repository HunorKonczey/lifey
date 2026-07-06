import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/trainer_invite/application/trainer_invite_controller.dart';
import 'package:lifey/features/trainer_invite/domain/trainer_invite.dart';
import 'package:lifey/features/trainer_invite/presentation/trainer_invite_card.dart';
import 'package:lifey/l10n/app_localizations.dart';

TrainerInvite _invite(int id, {String email = 'trainer@example.com', int hoursLeft = 18}) {
  return TrainerInvite(
    id: id,
    trainerEmail: email,
    invitedAt: DateTime.now().subtract(const Duration(hours: 6)),
    // +1 minute margin: the card computes `hoursLeft` from the elapsed wall
    // clock at build time via `Duration.inHours` (floors), so an exact
    // `hoursLeft` boundary would flake down by one hour.
    expiresAt: DateTime.now().add(Duration(hours: hoursLeft, minutes: 1)),
  );
}

class _FakeTrainerInviteController extends TrainerInviteController {
  _FakeTrainerInviteController(this._invites, {this.onRespond});

  final List<TrainerInvite> _invites;
  final void Function(int id, bool accept)? onRespond;

  @override
  Future<List<TrainerInvite>> build() async => _invites;

  @override
  Future<void> respond(int inviteId, {required bool accept}) async {
    onRespond?.call(inviteId, accept);
    state = AsyncData(state.value!.where((i) => i.id != inviteId).toList());
  }
}

Future<void> _pumpCard(
  WidgetTester tester, {
  required List<TrainerInvite> invites,
  void Function(int id, bool accept)? onRespond,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        trainerInviteControllerProvider.overrideWith(
          () => _FakeTrainerInviteController(invites, onRespond: onRespond),
        ),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: TrainerInviteCard()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders nothing when there are no pending invites', (tester) async {
    await _pumpCard(tester, invites: const []);

    expect(find.byType(Dismissible), findsNothing);
  });

  testWidgets('shows the trainer email, expiry and action buttons for a pending invite',
      (tester) async {
    await _pumpCard(tester, invites: [_invite(1, email: 'anna@example.com', hoursLeft: 5)]);

    expect(find.textContaining('anna@example.com'), findsOneWidget);
    expect(find.text('Expires in 5 hours'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
  });

  testWidgets('shows a "+N more" hint when more than one invite is pending', (tester) async {
    await _pumpCard(tester, invites: [_invite(1), _invite(2)]);

    expect(find.textContaining('1 more invite'), findsOneWidget);
  });

  testWidgets('tapping Accept calls respond(accept: true) and removes the card', (tester) async {
    int? respondedId;
    bool? respondedAccept;
    await _pumpCard(
      tester,
      invites: [_invite(1)],
      onRespond: (id, accept) {
        respondedId = id;
        respondedAccept = accept;
      },
    );

    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(respondedId, 1);
    expect(respondedAccept, true);
    expect(find.text('Accept'), findsNothing);
  });

  testWidgets('tapping Decline calls respond(accept: false)', (tester) async {
    bool? respondedAccept;
    await _pumpCard(
      tester,
      invites: [_invite(1)],
      onRespond: (id, accept) => respondedAccept = accept,
    );

    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();

    expect(respondedAccept, false);
  });

  testWidgets('tapping the close button dismisses the card without calling respond',
      (tester) async {
    bool responded = false;
    await _pumpCard(
      tester,
      invites: [_invite(1)],
      onRespond: (_, __) => responded = true,
    );

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(responded, isFalse);
    expect(find.text('Accept'), findsNothing);
  });
}
