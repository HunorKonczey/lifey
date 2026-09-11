import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/chat/application/peer_avatar_controller.dart';
import 'package:lifey/features/trainer/clients/domain/trainer_client.dart';
import 'package:lifey/features/trainer/shared/client_avatar.dart';

final _client = TrainerClient(
  userId: 42,
  email: 'anna@example.com',
  firstName: 'Anna',
  lastName: 'Client',
  activeSince: DateTime.utc(2026, 3, 1),
);

/// A one-pixel PNG: enough for Image.memory to decode without reaching for a
/// real file.
final _onePixelPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

/// Returns the user ids the avatar provider was actually asked for, which is
/// the point of the last two tests.
Future<List<int>> _pump(
  WidgetTester tester, {
  required bool showPhoto,
  Uint8List? photo,
}) async {
  final requested = <int>[];

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        peerAvatarProvider.overrideWith((ref, userId) async {
          requested.add(userId);
          return photo;
        }),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ClientAvatar(client: _client, showPhoto: showPhoto),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return requested;
}

void main() {
  testWidgets('draws the monogram when the client has no picture',
      (tester) async {
    await _pump(tester, showPhoto: true);

    expect(find.text('AC'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('draws the picture once it arrives', (tester) async {
    await _pump(tester, showPhoto: true, photo: _onePixelPng);

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('AC'), findsNothing);
  });

  testWidgets('asks for nothing at all when photos are off', (tester) async {
    final requested = await _pump(
      tester,
      showPhoto: false,
      photo: _onePixelPng,
    );

    // The client list is specified as monograms, and twenty rows must not
    // become twenty downloads to render it.
    expect(requested, isEmpty);
    expect(find.text('AC'), findsOneWidget);
  });

  testWidgets('asks once when photos are on', (tester) async {
    final requested = await _pump(
      tester,
      showPhoto: true,
      photo: _onePixelPng,
    );

    expect(requested, [42]);
  });
}
