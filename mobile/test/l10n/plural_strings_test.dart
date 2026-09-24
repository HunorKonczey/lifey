import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/l10n/app_localizations.dart';

/// Count strings that used to print "1 exercises" (docs/redesign/
/// 77-mobile-redesign-plan.md R0.4 — design system rule "Többes szám
/// ICU-formátumból").
void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final hu = lookupAppLocalizations(const Locale('hu'));

  test('English picks singular for one', () {
    expect(en.exercisesCountLabel(1), '1 exercise');
    expect(en.exercisesCountLabel(2), '2 exercises');
    expect(en.workoutExerciseCount(1), '1 exercise');
    expect(en.setsCountLabel(1), '1 set');
    expect(en.recapWorkoutsCount(1), '1 workout');
    expect(en.intervalSectionsCountChip(1), '1 section');
    expect(en.waypointsCountChip(1), '1 waypoint');
    expect(en.workoutSuccessSubtitle(1), 'You improved in 1 area since last time');
    expect(en.workoutSuccessSubtitle(3), 'You improved in 3 areas since last time');
  });

  test('plurals embedded in a longer message keep the other placeholders', () {
    expect(en.intervalPlanSummaryLabel('20 min', 1), '20 min · 1 section');
    expect(en.intervalPlanSummaryLabel('20 min', 4), '20 min · 4 sections');
    expect(en.trainerOccurrenceCountSummary(1, 'Mon', 'Fri'), 'This creates 1 session, Mon – Fri');
  });

  test('Hungarian keeps the singular noun after any numeral', () {
    expect(hu.exercisesCountLabel(1), '1 gyakorlat');
    expect(hu.exercisesCountLabel(5), '5 gyakorlat');
    expect(hu.intervalPlanSummaryLabel('20 perc', 3), '20 perc · 3 szakasz');
    expect(hu.trainerOccurrenceCountSummary(2, 'H', 'P'), 'Ez 2 alkalmat hoz létre, H – P');
  });
}
