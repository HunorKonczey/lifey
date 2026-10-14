import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `WorkoutSessionController` is the sessions' mutation entry point and holds no list (LIF-156): its stream is empty, so a screen
/// that *reads* its state would wait for ever. Production code may only reach for `.notifier`.
void main() {
  test('no production code reads the state of workoutSessionControllerProvider', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (!line.contains('workoutSessionControllerProvider')) continue;
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;
        // The declaration itself, and `.notifier` (also when the call is wrapped onto the next line).
        if (trimmed.startsWith('final workoutSessionControllerProvider')) continue;
        final rest = line.substring(line.indexOf('workoutSessionControllerProvider') + 'workoutSessionControllerProvider'.length);
        final next = i + 1 < lines.length ? lines[i + 1].trimLeft() : '';
        if (rest.startsWith('.notifier') || (rest.trim().isEmpty && next.startsWith('.notifier'))) continue;
        offenders.add('${entity.path}:${i + 1}: ${line.trim()}');
      }
    }

    expect(offenders, isEmpty, reason: 'read the state of a dedicated provider instead:\n${offenders.join('\n')}');
  });
}
