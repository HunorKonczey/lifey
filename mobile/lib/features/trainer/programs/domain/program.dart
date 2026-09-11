import '../../clients/domain/trainer_client.dart' show parseTrainerTimestamp;
import '../../schedule/domain/schedule.dart' show ScheduleTime, ScheduleWeekday;

/// A program is at most this many weeks long (`@Max(12)` on the backend).
const int programMaxWeeks = 12;

/// One program in the trainer's library (`ProgramSummaryResponse`).
class ProgramSummary {
  const ProgramSummary({
    required this.id,
    required this.name,
    required this.weeksCount,
    this.slotsPerWeek = 0,
    this.activeAssignmentCount = 0,
  });

  final int id;
  final String name;
  final int weeksCount;

  /// Distinct weekdays used anywhere in the grid — "how many times a week"
  /// at a glance.
  final int slotsPerWeek;

  /// How many clients are currently running this program.
  final int activeAssignmentCount;

  factory ProgramSummary.fromJson(Map<String, dynamic> json) {
    return ProgramSummary(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      weeksCount: (json['weeksCount'] as num?)?.toInt() ?? 1,
      slotsPerWeek: (json['slotsPerWeek'] as num?)?.toInt() ?? 0,
      activeAssignmentCount: (json['activeAssignmentCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// A program's full grid (`ProgramResponse`).
class Program {
  const Program({
    required this.id,
    required this.name,
    required this.weeksCount,
    this.workouts = const [],
  });

  final int id;
  final String name;
  final int weeksCount;
  final List<ProgramSlot> workouts;

  /// The slots of one week, in weekday order. A week with nothing in it comes
  /// back empty rather than missing — a rest week is a real answer.
  List<ProgramSlot> slotsOfWeek(int weekNumber) {
    final ofWeek = workouts.where((w) => w.weekNumber == weekNumber).toList();
    ofWeek.sort((a, b) => a.dayOfWeek.isoNumber.compareTo(b.dayOfWeek.isoNumber));
    return ofWeek;
  }

  factory Program.fromJson(Map<String, dynamic> json) {
    return Program(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      weeksCount: (json['weeksCount'] as num?)?.toInt() ?? 1,
      workouts: ((json['workouts'] as List<dynamic>?) ?? const [])
          .map((e) => ProgramSlot.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// One week/day cell of the grid (`ProgramWorkoutResponse`).
///
/// A slot is identified by *where* it sits — week 3, Monday — not by its
/// position in a list. That is worth saying out loud, because it is the reason
/// a drag-to-reorder gesture does not fit this data (see the programs screen).
class ProgramSlot {
  const ProgramSlot({
    required this.weekNumber,
    required this.dayOfWeek,
    required this.templateId,
    required this.templateName,
    this.id,
    this.timeOfDay,
    this.note,
  });

  final int? id;
  final int weekNumber;
  final ScheduleWeekday dayOfWeek;
  final int templateId;

  /// Resolved live by the backend, so renaming the template shows up here.
  final String templateName;

  final ScheduleTime? timeOfDay;

  /// The trainer's own progression note. Never shown to the client.
  final String? note;

  factory ProgramSlot.fromJson(Map<String, dynamic> json) {
    return ProgramSlot(
      id: (json['id'] as num?)?.toInt(),
      weekNumber: (json['weekNumber'] as num?)?.toInt() ?? 1,
      dayOfWeek: ScheduleWeekday.fromApi(json['dayOfWeek'] as String),
      templateId: (json['templateId'] as num?)?.toInt() ?? 0,
      templateName: json['templateName'] as String? ?? '',
      timeOfDay: ScheduleTime.tryParse(json['timeOfDay'] as String?),
      note: json['note'] as String?,
    );
  }
}

/// What starting a client on a program produced (`ProgramAssignmentResponse`).
class ProgramAssignmentResult {
  const ProgramAssignmentResult({
    required this.programName,
    required this.startDate,
    required this.endDate,
    required this.occurrenceCount,
  });

  final String programName;
  final DateTime startDate;
  final DateTime endDate;
  final int occurrenceCount;

  factory ProgramAssignmentResult.fromJson(Map<String, dynamic> json) {
    return ProgramAssignmentResult(
      programName: json['programName'] as String? ?? '',
      startDate: parseTrainerTimestamp(json['startDate'] as String),
      endDate: parseTrainerTimestamp(json['endDate'] as String),
      occurrenceCount: (json['occurrenceCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// One client's run of a program (`ProgramAssignmentSummaryResponse`).
class ProgramAssignmentSummary {
  const ProgramAssignmentSummary({
    required this.id,
    required this.clientId,
    required this.programId,
    required this.programName,
    required this.startDate,
    required this.endDate,
    this.doneCount = 0,
    this.missedCount = 0,
    this.remainingCount = 0,
    this.cancelledAt,
  });

  final int id;
  final int clientId;
  final int programId;

  /// Snapshotted when the client was started on it, so it survives the
  /// program being renamed or deleted since.
  final String programName;

  final DateTime startDate;
  final DateTime endDate;
  final int doneCount;
  final int missedCount;
  final int remainingCount;
  final DateTime? cancelledAt;

  bool get isCancelled => cancelledAt != null;

  factory ProgramAssignmentSummary.fromJson(Map<String, dynamic> json) {
    return ProgramAssignmentSummary(
      id: (json['id'] as num).toInt(),
      clientId: (json['clientId'] as num?)?.toInt() ?? 0,
      programId: (json['programId'] as num?)?.toInt() ?? 0,
      programName: json['programName'] as String? ?? '',
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
