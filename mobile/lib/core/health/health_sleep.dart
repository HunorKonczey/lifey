import 'package:health/health.dart';

import 'health_cardio_workout.dart' show isLifeyHealthSource;

/// What a sleep data point from the health store says about that stretch of
/// time (docs/integrations/89 G2.3).
enum SleepStageKind { inBed, asleep, light, deep, rem, awake, unknown }

/// The kind of a sleep stage type, or null for a type that is not a stage
/// (including [HealthDataType.SLEEP_SESSION], which is the session itself).
///
/// - Health Connect's "out of bed" and "awake in bed" count as awake: both
///   are time inside the session without sleep.
/// - HealthKit's "asleep (unspecified)" and Health Connect's "sleeping" are
///   sleep without a stage.
SleepStageKind? sleepStageKindFor(HealthDataType type) => switch (type) {
      HealthDataType.SLEEP_IN_BED => SleepStageKind.inBed,
      HealthDataType.SLEEP_ASLEEP => SleepStageKind.asleep,
      HealthDataType.SLEEP_LIGHT => SleepStageKind.light,
      HealthDataType.SLEEP_DEEP => SleepStageKind.deep,
      HealthDataType.SLEEP_REM => SleepStageKind.rem,
      HealthDataType.SLEEP_AWAKE ||
      HealthDataType.SLEEP_AWAKE_IN_BED ||
      HealthDataType.SLEEP_OUT_OF_BED =>
        SleepStageKind.awake,
      HealthDataType.SLEEP_UNKNOWN => SleepStageKind.unknown,
      _ => null,
    };

/// One stretch of a night as the store reports it: a stage sample.
///
/// On Health Connect a stage carries its session's record id as [recordId];
/// on HealthKit every sample has its own.
class SleepStageSample {
  const SleepStageSample({
    required this.recordId,
    required this.start,
    required this.end,
    required this.kind,
    required this.sourceId,
    required this.sourceName,
    this.partOfSessionRecord = false,
  });

  final String recordId;

  /// True for a Health Connect stage: it belongs to the session record whose
  /// id it carries and never stands alone.
  final bool partOfSessionRecord;
  final DateTime start;
  final DateTime end;
  final SleepStageKind kind;
  final String sourceId;
  final String sourceName;
}

/// A whole sleep session record. Only Health Connect has these.
class SleepSessionRecord {
  const SleepSessionRecord({
    required this.recordId,
    required this.start,
    required this.end,
    required this.sourceId,
    required this.sourceName,
  });

  final String recordId;
  final DateTime start;
  final DateTime end;
  final String sourceId;
  final String sourceName;
}

/// One importable sleep session: what becomes a `sleep_sessions` row
/// (docs/integrations/89 D-G7). Stage minutes are null when the source
/// recorded no such information.
class HealthSleepSession {
  const HealthSleepSession({
    required this.healthRecordId,
    required this.start,
    required this.end,
    required this.sourceName,
    this.asleepMinutes,
    this.deepMinutes,
    this.lightMinutes,
    this.remMinutes,
    this.awakeMinutes,
  });

  /// The dedupe key (D-G3): the session record's id on Health Connect, the
  /// earliest sample's id on HealthKit.
  final String healthRecordId;
  final DateTime start;
  final DateTime end;
  final String sourceName;
  final int? asleepMinutes;
  final int? deepMinutes;
  final int? lightMinutes;
  final int? remMinutes;
  final int? awakeMinutes;
}

/// Converts a store data point to a session record or a stage sample, or
/// null when it is neither, or Lifey wrote it (D-G4).
Object? sleepRecordFromPoint(HealthDataPoint point) {
  if (isLifeyHealthSource(point.sourceId) || isLifeyHealthSource(point.sourceName)) return null;
  if (!point.dateTo.isAfter(point.dateFrom)) return null;
  if (point.type == HealthDataType.SLEEP_SESSION) {
    return SleepSessionRecord(
      recordId: point.uuid,
      start: point.dateFrom,
      end: point.dateTo,
      sourceId: point.sourceId,
      sourceName: point.sourceName,
    );
  }
  final kind = sleepStageKindFor(point.type);
  if (kind == null) return null;
  return SleepStageSample(
    recordId: point.uuid,
    start: point.dateFrom,
    end: point.dateTo,
    kind: kind,
    sourceId: point.sourceId,
    sourceName: point.sourceName,
    partOfSessionRecord: point.sourcePlatform == HealthPlatformType.googleHealthConnect,
  );
}

/// The longest pause between two samples of one HealthKit night. A longer
/// gap starts a new session, for example an afternoon nap.
const kSleepSampleMaxGap = Duration(minutes: 30);

/// Merges the store's sleep data into one [HealthSleepSession] per session,
/// sorted by end (docs/integrations/89 G2.3):
///
/// - **Health Connect:** each [SleepSessionRecord] is a session; its stages
///   are the samples carrying its record id. A session without stages
///   imports with its duration only. A stage whose session is not in
///   [sessions] is dropped: the session started before the read window,
///   and a stand-alone piece of it would be a partial duplicate.
/// - **HealthKit** (no session records): each source's samples that are not
///   part of a session record are clustered: a sample starting more than
///   [maxGap] after the cluster's end starts a new session. A cluster with no
///   sleep in it (only "in bed", for example the iPhone's bedtime schedule)
///   is not a session.
///
/// Pure.
List<HealthSleepSession> mergeSleep({
  required List<SleepSessionRecord> sessions,
  required List<SleepStageSample> stages,
  Duration maxGap = kSleepSampleMaxGap,
}) {
  final result = <HealthSleepSession>[];
  final sessionIds = {for (final s in sessions) s.recordId};

  final stagesBySession = <String, List<SleepStageSample>>{};
  final loose = <SleepStageSample>[];
  for (final stage in stages) {
    if (sessionIds.contains(stage.recordId)) {
      (stagesBySession[stage.recordId] ??= []).add(stage);
    } else if (!stage.partOfSessionRecord) {
      loose.add(stage);
    }
  }

  for (final session in sessions) {
    result.add(_summarize(
      recordId: session.recordId,
      start: session.start,
      end: session.end,
      sourceName: session.sourceName,
      stages: stagesBySession[session.recordId] ?? const [],
    ));
  }

  final bySource = <String, List<SleepStageSample>>{};
  for (final stage in loose) {
    (bySource['${stage.sourceId}\u0000${stage.sourceName}'] ??= []).add(stage);
  }
  for (final samples in bySource.values) {
    samples.sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      return byStart != 0 ? byStart : a.recordId.compareTo(b.recordId);
    });
    var cluster = <SleepStageSample>[];
    DateTime? clusterEnd;
    void flush() {
      if (cluster.isEmpty) return;
      if (cluster.any((s) => _sleepKinds.contains(s.kind))) {
        result.add(_summarize(
          recordId: cluster.first.recordId,
          start: cluster.first.start,
          end: clusterEnd!,
          sourceName: cluster.first.sourceName,
          stages: cluster,
        ));
      }
      cluster = [];
      clusterEnd = null;
    }

    for (final sample in samples) {
      if (clusterEnd != null && sample.start.isAfter(clusterEnd!.add(maxGap))) flush();
      cluster.add(sample);
      if (clusterEnd == null || sample.end.isAfter(clusterEnd!)) clusterEnd = sample.end;
    }
    flush();
  }

  result.sort((a, b) => a.end.compareTo(b.end));
  return result;
}

const _sleepKinds = {SleepStageKind.asleep, SleepStageKind.light, SleepStageKind.deep, SleepStageKind.rem};
const _detailedKinds = {SleepStageKind.light, SleepStageKind.deep, SleepStageKind.rem};

/// The stage minutes of one session. Null marks "the source does not say":
/// - asleep: null without any sleep sample;
/// - deep / light / REM: null unless the source stages sleep at all (a
///   HealthKit night with only "asleep" has no 0-minute deep sleep);
/// - awake: null unless an awake sample exists or the night is staged.
HealthSleepSession _summarize({
  required String recordId,
  required DateTime start,
  required DateTime end,
  required String sourceName,
  required List<SleepStageSample> stages,
}) {
  final seconds = <SleepStageKind, int>{};
  for (final s in stages) {
    seconds[s.kind] = (seconds[s.kind] ?? 0) + s.end.difference(s.start).inSeconds;
  }
  int minutes(SleepStageKind kind) => ((seconds[kind] ?? 0) / 60).round();

  final staged = seconds.keys.any(_detailedKinds.contains);
  final slept = seconds.keys.any(_sleepKinds.contains);
  final hasAwake = staged || seconds.containsKey(SleepStageKind.awake);
  return HealthSleepSession(
    healthRecordId: recordId,
    start: start,
    end: end,
    sourceName: sourceName,
    asleepMinutes: slept
        ? ((_sleepKinds.fold<int>(0, (sum, k) => sum + (seconds[k] ?? 0))) / 60).round()
        : null,
    deepMinutes: staged ? minutes(SleepStageKind.deep) : null,
    lightMinutes: staged ? minutes(SleepStageKind.light) : null,
    remMinutes: staged ? minutes(SleepStageKind.rem) : null,
    awakeMinutes: hasAwake ? minutes(SleepStageKind.awake) : null,
  );
}
