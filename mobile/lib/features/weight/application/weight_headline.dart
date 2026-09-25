import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../onboarding/data/user_details_repository.dart';
import '../domain/weight_entry.dart';
import 'weight_controller.dart';
import 'weight_trend_data.dart';

/// The numbers under the weight screen's hero: how the latest weigh-in moved
/// since the one before it and over the last 30 days, and how far along the
/// goal is (docs/redesign/77-mobile-redesign-plan.md R4.1).
class WeightHeadline {
  const WeightHeadline({
    required this.latest,
    required this.latestIsToday,
    required this.startKg,
    this.sinceLastKg,
    this.change30dKg,
    this.goalKg,
  });

  /// The newest weigh-in (the last one recorded on the newest day).
  final WeightEntry latest;

  /// [latest] is for today — "today 07:02" rather than a date.
  final bool latestIsToday;

  /// Latest minus the weigh-in of the previous day that has one; null with a
  /// single day of history.
  final double? sinceLastKg;

  /// Latest minus the oldest weigh-in of the last 30 days, when those span at
  /// least [minChangeSpanDays] — a week of scattered entries says nothing
  /// about a month. Null otherwise.
  final double? change30dKg;

  /// The oldest weigh-in ever recorded — where the goal journey started.
  final double startKg;

  /// The goal from onboarding, null when none is set.
  final double? goalKg;

  /// Shorter than this and [change30dKg] is left out.
  static const int minChangeSpanDays = 7;

  static const int changeWindowDays = 30;

  /// Closer than this to the goal and it counts as reached (the same
  /// tolerance the projection uses).
  static const double reachedToleranceKg = 0.2;

  bool get hasGoal => goalKg != null;

  /// How far the goal still is (always ≥ 0); null without a goal.
  double? get remainingKg => goalKg == null ? null : (latest.weight - goalKg!).abs();

  /// The goal has been reached: within [reachedToleranceKg], or passed in the
  /// direction the journey was heading.
  bool get reached {
    final goal = goalKg;
    if (goal == null) return false;
    if ((latest.weight - goal).abs() <= reachedToleranceKg) return true;
    // Losing weight (start above goal) and now below it — or the reverse.
    return startKg > goal ? latest.weight < goal : latest.weight > goal;
  }

  /// 0..1 of the way from [startKg] to the goal; null without a goal. A goal
  /// equal to the start has no journey, so it reads 1.
  double? get progress {
    final goal = goalKg;
    if (goal == null) return null;
    final total = startKg - goal;
    if (total.abs() < 0.05) return 1;
    return ((startKg - latest.weight) / total).clamp(0.0, 1.0);
  }

  /// True when getting lighter is the goal's direction.
  bool? get goalIsLoss {
    final goal = goalKg;
    if (goal == null) return null;
    return startKg >= goal;
  }
}

/// [WeightHeadline] for [entries] (newest first, as `WeightRepository.watchAll`
/// emits them); null without any.
WeightHeadline? computeWeightHeadline(
  List<WeightEntry> entries, {
  required DateTime now,
  double? goalKg,
}) {
  if (entries.isEmpty) return null;
  final days = dailyPoints(entries); // one per day, oldest first
  if (days.isEmpty) return null;
  final latestDay = days.last;

  // The latest *entry* of the latest day, for its recordedAt time.
  final latest = entries.firstWhere(
    (e) => _sameDay(e.date.toLocal(), latestDay.date),
    orElse: () => entries.first,
  );

  final today = DateTime(now.year, now.month, now.day);
  final latestIsToday = _sameDay(latestDay.date, today);

  final sinceLast = days.length > 1 ? latestDay.value - days[days.length - 2].value : null;

  double? change30d;
  final windowStart = latestDay.date.subtract(const Duration(days: WeightHeadline.changeWindowDays));
  final inWindow = days.where((d) => !d.date.isBefore(windowStart)).toList();
  if (inWindow.length > 1) {
    final span = latestDay.date.difference(inWindow.first.date).inDays;
    if (span >= WeightHeadline.minChangeSpanDays) change30d = latestDay.value - inWindow.first.value;
  }

  return WeightHeadline(
    latest: latest,
    latestIsToday: latestIsToday,
    sinceLastKg: sinceLast,
    change30dKg: change30d,
    startKg: days.first.value,
    goalKg: goalKg,
  );
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// The headline of the weight screen from the live entries and the goal from
/// `/user-details` (online-only, D-W8: offline the goal is simply absent and
/// the band offers to set one).
final weightHeadlineProvider = Provider<WeightHeadline?>((ref) {
  final entries = ref.watch(weightControllerProvider).value;
  if (entries == null) return null;
  final goal = ref.watch(userDetailsProvider).value?.targetWeightKg;
  return computeWeightHeadline(entries, now: DateTime.now(), goalKg: goal);
});
