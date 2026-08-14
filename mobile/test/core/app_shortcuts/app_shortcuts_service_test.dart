import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/app_shortcuts/app_shortcuts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppShortcutsService', () {
    const channel = MethodChannel('lifey/shortcuts');
    final calls = <MethodCall>[];

    void setHandler(Future<Object?> Function(MethodCall) handler) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, handler);
    }

    setUp(() {
      calls.clear();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('no-ops when unavailable — no channel call made', () async {
      setHandler((call) async {
        calls.add(call);
        return null;
      });
      final service = AppShortcutsService(isAvailable: false);

      await service.update(const [
        AppShortcut(id: 'cardio:RUNNING', shortLabel: 'Futás', deepLinkUri: 'lifey://workout/start?activity=RUNNING'),
      ]);

      expect(calls, isEmpty);
    });

    test('update sends the shortcut list JSON-encoded', () async {
      setHandler((call) async {
        calls.add(call);
        return null;
      });
      final service = AppShortcutsService(isAvailable: true);

      await service.update(const [
        AppShortcut(
          id: 'cardio:RUNNING',
          shortLabel: 'Futás',
          deepLinkUri: 'lifey://workout/start?activity=RUNNING',
        ),
        AppShortcut(
          id: 'strength:freeform',
          shortLabel: 'Üres edzés',
          deepLinkUri: 'lifey://workout/start?activity=STRENGTH',
        ),
      ]);

      expect(calls.single.method, 'update');
      expect(calls.single.arguments, {
        'shortcuts': [
          {
            'id': 'cardio:RUNNING',
            'shortLabel': 'Futás',
            'deepLinkUri': 'lifey://workout/start?activity=RUNNING',
          },
          {
            'id': 'strength:freeform',
            'shortLabel': 'Üres edzés',
            'deepLinkUri': 'lifey://workout/start?activity=STRENGTH',
          },
        ],
      });
    });

    test('an empty list clears the native shortcuts rather than being skipped', () async {
      setHandler((call) async {
        calls.add(call);
        return null;
      });
      final service = AppShortcutsService(isAvailable: true);

      await service.update(const []);

      expect(calls.single.method, 'update');
      expect(calls.single.arguments, {'shortcuts': []});
    });

    test('a missing native handler is swallowed, not rethrown', () async {
      setHandler((call) async => throw MissingPluginException('no handler'));
      final service = AppShortcutsService(isAvailable: true);

      await expectLater(
        service.update(const [
          AppShortcut(id: 'x', shortLabel: 'x', deepLinkUri: 'lifey://workout/start?activity=RUNNING'),
        ]),
        completes,
      );
    });
  });
}
