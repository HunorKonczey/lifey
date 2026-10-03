/// A result a participant shares in the thread — a finished workout or one
/// personal record (docs/chat/83-chat-result-card-plan.md).
///
/// A **snapshot**: the numbers are frozen when the card is sent, and
/// [sessionId] (the main API's workout-session id) is only what a tap opens.
/// And a **claim**: the server checks shape and bounds, not truth, so nothing
/// in the app may count or rank these (§2.3).
///
/// The wire shape is the server's `MessageCard` — a `kind` plus the matching
/// sub-object, the other absent.
sealed class ChatCard {
  const ChatCard({required this.occurredAt, this.sessionId});

  /// When the workout started / the record was set.
  final DateTime occurredAt;

  /// Null when the session had not synced yet at share time: the card is then
  /// complete but nobody can open the session from it.
  final int? sessionId;

  /// The server's `kind`: what the preview and the push key on.
  String get kindCode;

  Map<String, dynamic> toJson();

  /// Reads a card off the wire. A kind this build does not know becomes an
  /// [UnknownChatCard] instead of throwing — one message from a newer app must
  /// not make the whole thread unreadable (§2.9). Returns null only when there
  /// is no card at all, or the object is too broken to hold a kind.
  static ChatCard? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final kind = json['kind'];
    if (kind is! String) return null;
    final occurredAt = DateTime.tryParse(json['occurredAt'] as String? ?? '')?.toLocal();
    if (occurredAt == null) return null;
    final sessionId = (json['sessionId'] as num?)?.toInt();

    switch (kind) {
      case 'WORKOUT':
        final w = json['workout'];
        if (w is! Map<String, dynamic>) return UnknownChatCard(kind: kind, occurredAt: occurredAt, raw: json);
        return WorkoutChatCard(
          occurredAt: occurredAt,
          sessionId: sessionId,
          workoutKind: w['workoutKind'] == 'CARDIO' ? ChatWorkoutKind.cardio : ChatWorkoutKind.strength,
          title: w['title'] as String?,
          durationSeconds: (w['durationSeconds'] as num?)?.toInt(),
          volumeKg: (w['volumeKg'] as num?)?.toDouble(),
          exerciseCount: (w['exerciseCount'] as num?)?.toInt(),
          distanceMeters: (w['distanceMeters'] as num?)?.toDouble(),
          recordCount: (w['recordCount'] as num?)?.toInt(),
        );
      case 'PR':
        final p = json['pr'];
        final prKind = p is Map<String, dynamic> ? ChatPrKind.fromWire(p['prType'] as String?) : null;
        if (p is! Map<String, dynamic> || prKind == null || p['exerciseName'] is! String || p['value'] is! num) {
          return UnknownChatCard(kind: kind, occurredAt: occurredAt, raw: json);
        }
        return PrChatCard(
          occurredAt: occurredAt,
          sessionId: sessionId,
          exerciseName: p['exerciseName'] as String,
          prKind: prKind,
          value: (p['value'] as num).toDouble(),
          previousValue: (p['previousValue'] as num?)?.toDouble(),
          weightKg: (p['weightKg'] as num?)?.toDouble(),
          reps: (p['reps'] as num?)?.toInt(),
        );
      default:
        return UnknownChatCard(kind: kind, occurredAt: occurredAt, raw: json);
    }
  }
}

enum ChatWorkoutKind { strength, cardio }

/// The three record types of docs/38, under the names the wire uses.
enum ChatPrKind {
  maxWeight('MAX_WEIGHT'),
  repsAtWeight('REPS_AT_WEIGHT'),
  estimatedOneRm('ESTIMATED_ONE_RM');

  const ChatPrKind(this.wire);
  final String wire;

  static ChatPrKind? fromWire(String? wire) {
    for (final kind in values) {
      if (kind.wire == wire) return kind;
    }
    return null;
  }
}

/// A finished strength or cardio session.
class WorkoutChatCard extends ChatCard {
  const WorkoutChatCard({
    required super.occurredAt,
    super.sessionId,
    required this.workoutKind,
    this.title,
    this.durationSeconds,
    this.volumeKg,
    this.exerciseCount,
    this.distanceMeters,
    this.recordCount,
  });

  final ChatWorkoutKind workoutKind;

  /// The template or activity name; null for an unnamed session.
  final String? title;
  final int? durationSeconds;

  /// Σ weight × reps of the done sets (strength).
  final double? volumeKg;
  final int? exerciseCount;

  /// Cardio distance, in metres.
  final double? distanceMeters;

  /// How many personal records the session produced; zero is "none", the card
  /// shows the chip only when it is positive.
  final int? recordCount;

  @override
  String get kindCode => 'WORKOUT';

  bool get isCardio => workoutKind == ChatWorkoutKind.cardio;

  @override
  Map<String, dynamic> toJson() => {
        'kind': kindCode,
        if (sessionId != null) 'sessionId': sessionId,
        'occurredAt': occurredAt.toUtc().toIso8601String(),
        'workout': {
          'workoutKind': isCardio ? 'CARDIO' : 'STRENGTH',
          if (title != null) 'title': title,
          if (durationSeconds != null) 'durationSeconds': durationSeconds,
          if (volumeKg != null) 'volumeKg': volumeKg,
          if (exerciseCount != null) 'exerciseCount': exerciseCount,
          if (distanceMeters != null) 'distanceMeters': distanceMeters,
          if (recordCount != null) 'recordCount': recordCount,
        },
      };
}

/// One personal record.
class PrChatCard extends ChatCard {
  const PrChatCard({
    required super.occurredAt,
    super.sessionId,
    required this.exerciseName,
    required this.prKind,
    required this.value,
    this.previousValue,
    this.weightKg,
    this.reps,
  });

  final String exerciseName;
  final ChatPrKind prKind;

  /// The new record: kg for max weight and e1RM, reps for reps-at-weight.
  final double value;

  /// The old record in the same unit; null for the exercise's first one.
  final double? previousValue;

  /// Weight and reps of the set that earned it.
  final double? weightKg;
  final int? reps;

  /// How far it moved the old record, or null when there was none to move.
  double? get delta => previousValue == null ? null : value - previousValue!;

  @override
  String get kindCode => 'PR';

  @override
  Map<String, dynamic> toJson() => {
        'kind': kindCode,
        if (sessionId != null) 'sessionId': sessionId,
        'occurredAt': occurredAt.toUtc().toIso8601String(),
        'pr': {
          'exerciseName': exerciseName,
          'prType': prKind.wire,
          'value': value,
          if (previousValue != null) 'previousValue': previousValue,
          if (weightKg != null) 'weightKg': weightKg,
          if (reps != null) 'reps': reps,
        },
      };
}

/// A kind this build does not know (or a card too malformed to read). Kept —
/// with its raw JSON, so it round-trips through the local cache untouched — and
/// drawn as "update the app to see this".
class UnknownChatCard extends ChatCard {
  const UnknownChatCard({required this.kind, required super.occurredAt, required this.raw});

  final String kind;
  final Map<String, dynamic> raw;

  @override
  String get kindCode => kind;

  @override
  Map<String, dynamic> toJson() => raw;
}
