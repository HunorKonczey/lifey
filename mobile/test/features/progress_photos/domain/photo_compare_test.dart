import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/progress_photos/domain/photo_compare.dart';
import 'package:lifey/features/progress_photos/domain/progress_photo.dart';

ProgressPhoto _p(int id, DateTime takenOn) => ProgressPhoto(
      id: id,
      takenOn: takenOn,
      pose: PhotoPose.front,
      createdAt: DateTime(2026, 6, 1),
      updatedAt: DateTime(2026, 6, 1),
    );

void main() {
  group('defaultCompareSelection', () {
    test('is the oldest and the newest by the day taken, whatever the list order', () {
      final sel = defaultCompareSelection([
        _p(2, DateTime(2026, 6, 10)),
        _p(3, DateTime(2026, 7, 1)),
        _p(1, DateTime(2026, 5, 1)),
      ])!;

      expect(sel.before.id, 1);
      expect(sel.after.id, 3);
    });

    test('same-day photos are ordered by id', () {
      final sel = defaultCompareSelection([_p(5, DateTime(2026, 6, 1)), _p(4, DateTime(2026, 6, 1))])!;

      expect(sel.before.id, 4);
      expect(sel.after.id, 5);
    });

    test('is null with fewer than two photos', () {
      expect(defaultCompareSelection(const []), isNull);
      expect(defaultCompareSelection([_p(1, DateTime(2026, 6, 1))]), isNull);
    });
  });

  group('daysBetween', () {
    test('counts calendar days in either order', () {
      expect(daysBetween(DateTime(2026, 6, 1), DateTime(2026, 6, 15)), 14);
      expect(daysBetween(DateTime(2026, 6, 15), DateTime(2026, 6, 1)), 14);
      expect(daysBetween(DateTime(2026, 6, 1), DateTime(2026, 6, 1)), 0);
    });

    test('ignores the time of day and is not thrown by a DST change', () {
      expect(daysBetween(DateTime(2026, 3, 28, 23, 30), DateTime(2026, 3, 30, 0, 15)), 2);
      // Across the EU spring-forward weekend.
      expect(daysBetween(DateTime(2026, 3, 1), DateTime(2026, 4, 1)), 31);
    });
  });
}
