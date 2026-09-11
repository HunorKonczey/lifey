import '../../clients/domain/trainer_client.dart' show parseTrainerTimestamp;

/// How a schedule repeats (`Recurrence` on the backend).
enum ScheduleRecurrence {
  once('ONCE'),
  daily('DAILY'),
  weekly('WEEKLY');

  const ScheduleRecurrence(this.apiValue);

  final String apiValue;

  static ScheduleRecurrence fromApi(String? value) => values.firstWhere(
        (r) => r.apiValue == value,
        orElse: () => ScheduleRecurrence.once,
      );
}

/// What became of one scheduled occurrence (`OccurrenceStatus`).
///
/// Derived server-side, never computed here: "missed" depends on the server's
/// idea of today, and two clocks disagreeing about that would paint the
/// calendar differently from the client's own screen.
enum OccurrenceStatus {
  upcoming('UPCOMING'),
  done('DONE'),
  missed('MISSED'),
  cancelled('CANCELLED');

  const OccurrenceStatus(this.apiValue);

  final String apiValue;

  static OccurrenceStatus fromApi(String? value) => values.firstWhere(
        (s) => s.apiValue == value,
        orElse: () => OccurrenceStatus.upcoming,
      );
}

/// Weekday, as the API spells it (`java.time.DayOfWeek`: `MONDAY`…`SUNDAY`).
///
/// [isoNumber] matches Dart's `DateTime.weekday`, which is what makes this
/// enum usable for both the wire and date arithmetic.
enum ScheduleWeekday {
  monday('MONDAY', DateTime.monday),
  tuesday('TUESDAY', DateTime.tuesday),
  wednesday('WEDNESDAY', DateTime.wednesday),
  thursday('THURSDAY', DateTime.thursday),
  friday('FRIDAY', DateTime.friday),
  saturday('SATURDAY', DateTime.saturday),
  sunday('SUNDAY', DateTime.sunday);

  const ScheduleWeekday(this.apiValue, this.isoNumber);

  final String apiValue;
  final int isoNumber;

  static ScheduleWeekday fromApi(String value) =>
      values.firstWhere((d) => d.apiValue == value, orElse: () => ScheduleWeekday.monday);

  static ScheduleWeekday of(DateTime date) =>
      values.firstWhere((d) => d.isoNumber == date.weekday);
}

/// A time of day with no date and no zone, as `LocalTime` arrives: `HH:mm` or
/// `HH:mm:ss`.
class ScheduleTime {
  const ScheduleTime(this.hour, this.minute);

  final int hour;
  final int minute;

  String get apiValue =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  static ScheduleTime? tryParse(String? value) {
    if (value == null || value.isEmpty) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return ScheduleTime(hour, minute);
  }

  @override
  bool operator ==(Object other) =>
      other is ScheduleTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);
}

/// One of a client's schedules, with how it is going (`ScheduleSummaryResponse`).
class ScheduleSummary {
  const ScheduleSummary({
    required this.id,
    required this.clientId,
    required this.templateId,
    required this.templateName,
    required this.recurrence,
    required this.startDate,
    required this.endDate,
    this.daysOfWeek = const [],
    this.timeOfDay,
    this.doneCount = 0,
    this.missedCount = 0,
    this.remainingCount = 0,
    this.cancelledAt,
  });

  final int id;
  final int clientId;
  final int templateId;
  final String templateName;
  final ScheduleRecurrence recurrence;
  final List<ScheduleWeekday> daysOfWeek;
  final ScheduleTime? timeOfDay;
  final DateTime startDate;
  final DateTime endDate;
  final int doneCount;
  final int missedCount;
  final int remainingCount;

  /// Non-null once the series has been cancelled. Cancelled schedules still
  /// list, because their past occurrences are still part of the record.
  final DateTime? cancelledAt;

  bool get isCancelled => cancelledAt != null;

  factory ScheduleSummary.fromJson(Map<String, dynamic> json) {
    return ScheduleSummary(
      id: (json['id'] as num).toInt(),
      clientId: (json['clientId'] as num).toInt(),
      templateId: (json['templateId'] as num?)?.toInt() ?? 0,
      templateName: json['templateName'] as String? ?? '',
      recurrence: ScheduleRecurrence.fromApi(json['recurrence'] as String?),
      daysOfWeek: ((json['daysOfWeek'] as List<dynamic>?) ?? const [])
          .map((e) => ScheduleWeekday.fromApi(e as String))
          .toList(),
      timeOfDay: ScheduleTime.tryParse(json['timeOfDay'] as String?),
      startDate: parseTrainerTimestamp(json['startDate'] as String),
      endDate: parseTrainerTimestamp(json['endDate'] as String),
      doneCount: (json['doneCount'] as num?)?.toInt() ?? 0,
      missedCount: (json['missedCount'] as num?)?.toInt() ?? 0,
      remainingCount: (json['remainingCount'] as num?)?.toInt() ?? 0,
      cancelledAt: json['cancelledAt'] == null
          ? null
          : parseTrainerTimestamp(json['cancelledAt'] as String),
    );
  }
}

/// One occurrence on one day, for one client (`TrainerCalendarSessionResponse`,
/// and `ScheduledSessionResponse` with the client fields left null).
///
/// [clientId] is 0 for the per-client endpoint, which already knows whose
/// sessions it is returning.
class CalendarSession {
  const CalendarSession({
    required this.sessionId,
    required this.scheduledFor,
    required this.status,
    this.clientId = 0,
    this.clientEmail,
    this.scheduledTime,
    this.templateName,
    this.scheduleId,
    this.programAssignmentId,
    this.programName,
  });

  final int sessionId;
  final int clientId;
  final String? clientEmail;
  final DateTime scheduledFor;
  final ScheduleTime? scheduledTime;
  final String? templateName;
  final OccurrenceStatus status;

  /// Exactly one of these is set: the occurrence came either from a schedule
  /// or from a multi-week program assignment (T6's subject).
  final int? scheduleId;
  final int? programAssignmentId;
  final String? programName;

  bool get isFromProgram => programAssignmentId != null;

  /// Only an occurrence that has not happened yet can be called off; the
  /// backend answers 409 for the rest, and the peek sheet hides the action
  /// rather than offering something that will be refused.
  bool get isCancellable => status == OccurrenceStatus.upcoming;

  factory CalendarSession.fromJson(Map<String, dynamic> json) {
    return CalendarSession(
      sessionId: (json['sessionId'] as num).toInt(),
      clientId: (json['clientId'] as num?)?.toInt() ?? 0,
      clientEmail: json['clientEmail'] as String?,
      scheduledFor: parseTrainerTimestamp(json['scheduledFor'] as String),
      scheduledTime: ScheduleTime.tryParse(json['scheduledTime'] as String?),
      templateName: json['templateName'] as String?,
      status: OccurrenceStatus.fromApi(json['status'] as String?),
      scheduleId: (json['scheduleId'] as num?)?.toInt(),
      programAssignmentId: (json['programAssignmentId'] as num?)?.toInt(),
      programName: json['programName'] as String?,
    );
  }
}
