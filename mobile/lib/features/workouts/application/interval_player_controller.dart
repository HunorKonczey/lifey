import '../domain/cardio_interval_plan.dart';
import '../domain/workout_session.dart';

/// One section of a plan as the player runs it: the repeat blocks are already
/// expanded, so `4× (4:00 hard + 3:00 easy)` is eight of these in a row.
class PlaybackSection {
  const PlaybackSection({
    required this.intensity,
    required this.durationSeconds,
    this.name,
  });

  final IntervalIntensity intensity;
  final int durationSeconds;
  final String? name;
}

/// What the live screen draws (docs/cardio/61 §3 M38): which section is
/// running, how much of it is left, and what comes after it.
class IntervalPlayerState {
  const IntervalPlayerState({
    required this.sectionNumber,
    required this.totalSections,
    required this.intensity,
    required this.secondsRemaining,
    required this.finished,
    this.sectionName,
    this.nextIntensity,
    this.nextDurationSeconds,
  });

  /// 1-based, for display ("3/10. SZAKASZ"). Equals [totalSections] once the
  /// plan has run out, so the last section stays on screen instead of the
  /// counter jumping past the end.
  final int sectionNumber;
  final int totalSections;
  final IntervalIntensity intensity;
  final String? sectionName;

  /// Counts down within the current section; 0 once the plan is [finished].
  final int secondsRemaining;

  /// The plan has played through. The screen keeps running — a plan running
  /// out never ends the session (docs/cardio/60 §6).
  final bool finished;

  final IntervalIntensity? nextIntensity;
  final int? nextDurationSeconds;

  /// The last three seconds of a section, which is what the 3–2–1 countdown
  /// and its haptics ride on (M38).
  bool get isCountingDown => !finished && secondsRemaining <= 3 && secondsRemaining > 0;
}

/// Plays a saved interval plan against the session's own moving time
/// (docs/cardio/60 C7.5).
///
/// **It owns no clock.** Every answer is a function of the `movingSeconds`
/// the caller feeds in — the same number `CardioSessionScreen` already shows
/// as the dominant metric, which stops accruing while the session is paused.
/// That is the whole design: a `Timer.periodic` of its own would keep
/// counting through a pause and drift away from the measurement it claims to
/// describe over a 40-minute ride (docs/cardio/60 §9's named risk for this
/// step).
///
/// A skipped section is recorded with the time it actually got, so the
/// executed sections add up to the moving time even when the rider pressed
/// "Skip" four times.
class IntervalPlayerController {
  IntervalPlayerController({required CardioIntervalPlan plan, this.onSectionChanged})
      : sections = expandPlan(plan);

  /// Fired when playback moves to a new section (never on the first one) and
  /// once more when the plan runs out. The screen turns this into haptics
  /// and, if the user left it on, a sound.
  final void Function(IntervalPlayerState state)? onSectionChanged;

  final List<PlaybackSection> sections;

  /// Moving-second offset at which the current section started. Not a
  /// wall-clock instant: pauses simply don't advance it, because they don't
  /// advance moving time either.
  int _sectionStartedAt = 0;
  int _index = 0;
  int _lastSeenMovingSeconds = 0;

  final List<CardioSplit> _executed = [];

  bool get isFinished => _index >= sections.length;

  /// Flattens a plan into the sections the player runs, expanding every
  /// repeat block into its own copies — the player counts what the rider
  /// experiences, not what the editor stores.
  static List<PlaybackSection> expandPlan(CardioIntervalPlan plan) {
    final result = <PlaybackSection>[];
    for (final step in plan.steps) {
      if (step.type == IntervalStepType.repeat) {
        for (var i = 0; i < (step.repeatCount ?? 0); i++) {
          for (final child in step.children) {
            result.add(PlaybackSection(
              intensity: child.intensity ?? IntervalIntensity.easy,
              durationSeconds: child.durationSeconds ?? 0,
              name: child.name,
            ));
          }
        }
      } else {
        result.add(PlaybackSection(
          intensity: step.intensity ?? IntervalIntensity.easy,
          durationSeconds: step.durationSeconds ?? 0,
          name: step.name,
        ));
      }
    }
    return result;
  }

  /// Feeds the session's moving time. Advances through as many sections as
  /// that time covers (a backgrounded app can come back several sections
  /// later) and returns the state to draw.
  IntervalPlayerState update(int movingSeconds) {
    _lastSeenMovingSeconds = movingSeconds;
    while (!isFinished && movingSeconds - _sectionStartedAt >= sections[_index].durationSeconds) {
      _completeCurrent(_sectionStartedAt + sections[_index].durationSeconds);
      final state = _stateAt(movingSeconds);
      onSectionChanged?.call(state);
    }
    return _stateAt(movingSeconds);
  }

  /// The "Léptet" circle on the live screen (M38): ends the current section
  /// now, at whatever length it actually got.
  IntervalPlayerState skip(int movingSeconds) {
    _lastSeenMovingSeconds = movingSeconds;
    if (isFinished) return _stateAt(movingSeconds);
    _completeCurrent(movingSeconds);
    final state = _stateAt(movingSeconds);
    onSectionChanged?.call(state);
    return state;
  }

  /// The executed sections, as splits to save with the session
  /// (docs/cardio/60 D-C7.1). Includes the section still running, cut off at
  /// [movingSeconds] — a ride that ends mid-section still logs the part that
  /// was ridden, rather than dropping it.
  List<CardioSplit> executedSplits(int movingSeconds) {
    final splits = [..._executed];
    if (!isFinished) {
      final ridden = movingSeconds - _sectionStartedAt;
      if (ridden > 0) {
        splits.add(_splitFor(sections[_index], splits.length, ridden));
      }
    }
    return splits;
  }

  void _completeCurrent(int endedAtMovingSeconds) {
    final section = sections[_index];
    final ridden = endedAtMovingSeconds - _sectionStartedAt;
    _executed.add(_splitFor(section, _executed.length, ridden));
    _sectionStartedAt = endedAtMovingSeconds;
    _index++;
  }

  CardioSplit _splitFor(PlaybackSection section, int index, int durationSeconds) {
    return CardioSplit(
      splitIndex: index,
      splitType: CardioSplitType.interval,
      // No distance: the indoor bike reports none, and a fabricated 0 would
      // read as a 0-length section in the summary.
      durationSeconds: durationSeconds,
      intensity: section.intensity,
    );
  }

  IntervalPlayerState _stateAt(int movingSeconds) {
    if (isFinished) {
      final last = sections.isEmpty ? null : sections.last;
      return IntervalPlayerState(
        sectionNumber: sections.length,
        totalSections: sections.length,
        intensity: last?.intensity ?? IntervalIntensity.easy,
        sectionName: last?.name,
        secondsRemaining: 0,
        finished: true,
      );
    }
    final section = sections[_index];
    final elapsed = movingSeconds - _sectionStartedAt;
    final next = _index + 1 < sections.length ? sections[_index + 1] : null;
    return IntervalPlayerState(
      sectionNumber: _index + 1,
      totalSections: sections.length,
      intensity: section.intensity,
      sectionName: section.name,
      secondsRemaining: (section.durationSeconds - elapsed).clamp(0, section.durationSeconds),
      finished: false,
      nextIntensity: next?.intensity,
      nextDurationSeconds: next?.durationSeconds,
    );
  }

  /// The state for the moving time last fed in — for a rebuild that isn't
  /// driven by a tick (a `setState` from something else on the screen).
  IntervalPlayerState get current => _stateAt(_lastSeenMovingSeconds);
}
