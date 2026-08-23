import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/workouts/domain/activity_type.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/l10n/app_localizations_en.dart';
import 'package:lifey/l10n/app_localizations_hu.dart';

void main() {
  final locales = <AppLocalizations>[AppLocalizationsEn(), AppLocalizationsHu()];

  group('activityFamilyOf', () {
    test('maps every kActivityTypes code to a family, no exceptions', () {
      for (final code in kActivityTypes) {
        expect(() => activityFamilyOf(code), returnsNormally, reason: code);
      }
    });

    test('DISTANCE family', () {
      expect(activityFamilyOf('RUNNING'), ActivityFamily.distance);
      expect(activityFamilyOf('WALKING'), ActivityFamily.distance);
      expect(activityFamilyOf('HIKING'), ActivityFamily.distance);
      expect(activityFamilyOf('CYCLING'), ActivityFamily.distance);
    });

    test('MACHINE family', () {
      expect(activityFamilyOf('INDOOR_BIKE'), ActivityFamily.machine);
    });

    test('GAME family, including the OTHER_CARDIO escape hatch', () {
      expect(activityFamilyOf('BASKETBALL'), ActivityFamily.game);
      expect(activityFamilyOf('FOOTBALL'), ActivityFamily.game);
      expect(activityFamilyOf('OTHER_CARDIO'), ActivityFamily.game);
    });

    test('throws on an unrecognized code', () {
      expect(() => activityFamilyOf('SWIMMING'), throwsArgumentError);
    });
  });

  group('activityTypeLabel', () {
    test('every kActivityTypes code resolves to a non-empty, distinct label in every locale', () {
      for (final l10n in locales) {
        final labels = kActivityTypes.map((c) => activityTypeLabel(l10n, c)).toList();
        for (final label in labels) {
          expect(label, isNotEmpty);
        }
        expect(labels.toSet().length, labels.length, reason: 'duplicate label in ${l10n.localeName}');
      }
    });

    test('the STRENGTH sentinel resolves to its own label, distinct from every cardio type', () {
      for (final l10n in locales) {
        final strengthLabel = activityTypeLabel(l10n, 'STRENGTH');
        expect(strengthLabel, isNotEmpty);
        for (final code in kActivityTypes) {
          expect(activityTypeLabel(l10n, code), isNot(strengthLabel), reason: '$code vs STRENGTH in ${l10n.localeName}');
        }
      }
    });

    test('an unrecognized code falls back to the "other" label, not a crash', () {
      for (final l10n in locales) {
        expect(activityTypeLabel(l10n, 'SWIMMING'), l10n.activityTypeOtherCardio);
      }
    });
  });

  group('activityTypeIcon', () {
    test('every kActivityTypes code and STRENGTH has a distinct icon', () {
      final codes = [...kActivityTypes, 'STRENGTH'];
      final icons = codes.map(activityTypeIcon).toSet();
      expect(icons.length, codes.length);
    });

    test('an unrecognized code falls back to the "other" icon, not a crash', () {
      expect(activityTypeIcon('SWIMMING'), activityTypeIcon('OTHER_CARDIO'));
    });
  });
}
