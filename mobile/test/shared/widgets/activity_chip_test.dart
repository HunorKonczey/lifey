import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/shared/widgets/activity_chip.dart';

Future<void> _pump(WidgetTester tester, Widget chip, {Brightness brightness = Brightness.dark}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness, useMaterial3: true),
      home: Scaffold(body: Center(child: chip)),
    ),
  );
}

void main() {
  testWidgets('renders a circular badge in the activity colour at the requested size',
      (tester) async {
    await _pump(tester, const ActivityChip(activityType: 'RUNNING', size: 32));

    final container = tester.widget<Container>(find.byType(Container));
    expect(container.constraints, const BoxConstraints.tightFor(width: 32, height: 32));
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.shape, BoxShape.circle);

    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.icon, Icons.directions_run);
    expect(icon.size, 17); // 32 * 0.54, rounded
  });

  testWidgets('scales the icon with the chip size', (tester) async {
    await _pump(tester, const ActivityChip(activityType: 'HIKING', size: 56));

    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.size, 30); // 56 * 0.54, rounded
  });

  testWidgets('renders the STRENGTH sentinel with its own icon and colour', (tester) async {
    await _pump(tester, const ActivityChip(activityType: 'STRENGTH', size: 44));

    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.icon, Icons.fitness_center);
  });

  testWidgets('fills at 14% alpha in dark theme', (tester) async {
    await _pump(tester, const ActivityChip(activityType: 'RUNNING', size: 32));

    final container = tester.widget<Container>(find.byType(Container));
    final color = (container.decoration as BoxDecoration).color!;
    expect(color.a, closeTo(0.14, 0.001));
  });

  testWidgets('fills at 16% alpha in light theme — a touch stronger so the chip '
      'doesn\'t wash out on a light card', (tester) async {
    await _pump(
      tester,
      const ActivityChip(activityType: 'RUNNING', size: 32),
      brightness: Brightness.light,
    );

    final container = tester.widget<Container>(find.byType(Container));
    final color = (container.decoration as BoxDecoration).color!;
    expect(color.a, closeTo(0.16, 0.001));
  });
}
