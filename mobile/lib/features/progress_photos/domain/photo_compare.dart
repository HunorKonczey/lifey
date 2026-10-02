import 'progress_photo.dart';

/// The two photos the compare screen starts with: the oldest and the newest
/// by the day they were taken (ties by id), docs/80 §2.7. Null when there are
/// fewer than two photos — nothing to compare.
({ProgressPhoto before, ProgressPhoto after})? defaultCompareSelection(List<ProgressPhoto> photos) {
  if (photos.length < 2) return null;
  final sorted = [...photos]..sort((a, b) {
      final byDate = a.takenOn.compareTo(b.takenOn);
      return byDate != 0 ? byDate : a.id.compareTo(b.id);
    });
  return (before: sorted.first, after: sorted.last);
}

/// Whole calendar days between two dates, ignoring any time of day and the
/// order — a DST change inside the span never makes it off by one.
int daysBetween(DateTime a, DateTime b) {
  final from = DateTime.utc(a.year, a.month, a.day);
  final to = DateTime.utc(b.year, b.month, b.day);
  return to.difference(from).inDays.abs();
}
