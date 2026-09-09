/// One of the trainer's active clients, exactly as `GET /trainer/clients`
/// returns it (`TrainerClientResponse` on the backend).
///
/// Read-only and never persisted: the trainer surface is online-first, so no
/// drift table backs this model (docs/chat/41-trainer-mobile-v2-plan.md §2.2).
/// A stale copy of *someone else's* data is a wrong-decision risk, not a
/// convenience — and keeping it off disk keeps a lost phone from carrying
/// other people's numbers around.
class TrainerClient {
  const TrainerClient({
    required this.userId,
    required this.email,
    required this.activeSince,
    this.firstName,
    this.lastName,
    this.weightTrend = const [],
    this.assignedPlanCount = 0,
    this.workoutsPerWeek = 0,
    this.lastActivityAt,
    this.lastWeightAt,
    this.missedWorkoutCount = 0,
  });

  final int userId;
  final String email;

  /// Nullable: a client who never filled in their profile has neither.
  final String? firstName;
  final String? lastName;

  final DateTime activeSince;
  final List<WeightTrendPoint> weightTrend;
  final int assignedPlanCount;
  final int workoutsPerWeek;

  /// Raw compliance facts (docs/29-compliance-overview-plan.md). Thresholds
  /// and flag composition live in `compliance.dart`, never here — same split
  /// as the web's `features/trainer/compliance.ts`.
  final DateTime? lastActivityAt;
  final DateTime? lastWeightAt;
  final int missedWorkoutCount;

  String get displayName {
    final name = [firstName, lastName]
        .where((part) => part != null && part.isNotEmpty)
        .join(' ');
    return name.isNotEmpty ? name : email;
  }

  String get monogram {
    final words =
        displayName.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return email.isEmpty ? '?' : email[0].toUpperCase();
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }

  factory TrainerClient.fromJson(Map<String, dynamic> json) {
    return TrainerClient(
      userId: json['clientId'] as int,
      email: json['clientEmail'] as String,
      firstName: json['clientFirstName'] as String?,
      lastName: json['clientLastName'] as String?,
      activeSince: parseTrainerTimestamp(json['activeSince'] as String),
      weightTrend: ((json['weightTrend'] as List<dynamic>?) ?? const [])
          .map((point) => WeightTrendPoint.fromJson(point as Map<String, dynamic>))
          .toList(),
      assignedPlanCount: (json['assignedPlanCount'] as num?)?.toInt() ?? 0,
      workoutsPerWeek: (json['workoutsPerWeek'] as num?)?.toInt() ?? 0,
      lastActivityAt: _parseNullableTimestamp(json['lastActivityAt'] as String?),
      lastWeightAt: _parseNullableTimestamp(json['lastWeightAt'] as String?),
      missedWorkoutCount: (json['missedWorkoutCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// One point of a client's recent weight history, for the card sparkline.
class WeightTrendPoint {
  const WeightTrendPoint({required this.date, required this.weightKg});

  final DateTime date;
  final double weightKg;

  factory WeightTrendPoint.fromJson(Map<String, dynamic> json) {
    return WeightTrendPoint(
      date: parseTrainerTimestamp(json['date'] as String),
      weightKg: (json['weightKg'] as num).toDouble(),
    );
  }
}

/// Parses either an `Instant` (`2026-07-11T12:00:00Z`) or a bare `LocalDate`
/// (`2026-07-11`) into a UTC `DateTime`.
///
/// The date-only case matters: `DateTime.parse('2026-07-11')` yields *local*
/// midnight, which would shift `daysSince` by a day either side of UTC for
/// `lastWeightAt`. The web reads the same field through `new Date(...)`,
/// which treats a bare date as UTC — this keeps the two clients agreeing.
DateTime parseTrainerTimestamp(String value) {
  if (value.length == 10) return DateTime.parse('${value}T00:00:00Z');
  return DateTime.parse(value).toUtc();
}

DateTime? _parseNullableTimestamp(String? value) =>
    value == null ? null : parseTrainerTimestamp(value);
