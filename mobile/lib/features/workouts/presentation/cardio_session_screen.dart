import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/cardio_formatter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/activity_chip.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../application/workout_session_controller.dart';
import '../domain/activity_type.dart';
import '../domain/workout_session.dart';

/// The live cardio screen — skeleton (docs/cardio/59-cardio-implementation-plan.md
/// C2.1): the `IDLE→RUNNING⇄PAUSED→ENDING→SUMMARY` state machine, a ticker,
/// and drift persistence on every real transition. Deliberately **not**
/// family-specific yet — DISTANCE/MACHINE/GAME layouts are C2.2/C2.3/C2.4,
/// and this screen shows the same family-agnostic moving-time display for
/// all three until then.
///
/// `IDLE` never actually renders here: the screen is always constructed with
/// an already-started [session] (`startCardioSession` runs before the push —
/// today only reachable from tests, since the real entry point is C2.7's
/// quick-start flow). `ENDING` is a plain confirm dialog for now, standing in
/// for the slide-to-finish gesture C2.5 adds — accidental-tap protection
/// beyond "are you sure?" isn't this step's job.
class CardioSessionScreen extends ConsumerStatefulWidget {
  const CardioSessionScreen({super.key, required this.session});

  final WorkoutSession session;

  @override
  ConsumerState<CardioSessionScreen> createState() => _CardioSessionScreenState();
}

class _CardioSessionScreenState extends ConsumerState<CardioSessionScreen> {
  late final String _clientId;
  late final DateTime _startedAt;
  late final String _activityType;
  late int _movingSeconds;
  int? _movingSinceEpochMs;
  DateTime? _finishedAt;
  Timer? _ticker;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final s = widget.session;
    _clientId = s.clientId;
    _startedAt = s.startedAt!;
    _activityType = s.activityType!;
    _movingSeconds = s.movingSeconds ?? 0;
    _movingSinceEpochMs = s.movingSinceEpochMs;
    _finishedAt = s.finishedAt;
    if (_isRunning) _startTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  bool get _isRunning => _finishedAt == null && _movingSinceEpochMs != null;
  bool get _isPaused => _finishedAt == null && _movingSinceEpochMs == null;
  bool get _isFinished => _finishedAt != null;

  /// The number this screen actually displays — folds in the still-ticking
  /// interval while running. Mirrors `WorkoutSession.liveMovingSeconds`
  /// exactly (this screen tracks the fields locally rather than re-reading
  /// the domain object on every frame, so it's re-derived here instead of
  /// constructing a throwaway [WorkoutSession] each tick).
  int get _liveMovingSeconds {
    final since = _movingSinceEpochMs;
    if (since == null) return _movingSeconds;
    final runningSince = DateTime.fromMillisecondsSinceEpoch(since);
    return _movingSeconds + DateTime.now().difference(runningSince).inSeconds;
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _showError(AppLocalizations l10n) {
    if (!mounted) return;
    AppSnackbar.showError(context, title: l10n.couldNotUpdateWorkoutMessage);
  }

  Future<void> _pause() async {
    if (_busy || !_isRunning) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    final total = _liveMovingSeconds;
    try {
      await ref.read(workoutSessionControllerProvider.notifier).pauseCardioSession(
            _clientId,
            startedAt: _startedAt,
            movingSeconds: total,
          );
      if (!mounted) return;
      _ticker?.cancel();
      setState(() {
        _movingSeconds = total;
        _movingSinceEpochMs = null;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showError(l10n);
    }
  }

  Future<void> _resume() async {
    if (_busy || !_isPaused) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    final resumedAt = DateTime.now();
    try {
      await ref.read(workoutSessionControllerProvider.notifier).resumeCardioSession(
            _clientId,
            startedAt: _startedAt,
            resumedAt: resumedAt,
          );
      if (!mounted) return;
      setState(() {
        _movingSinceEpochMs = resumedAt.millisecondsSinceEpoch;
        _busy = false;
      });
      _startTicker();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showError(l10n);
    }
  }

  Future<void> _confirmFinish() async {
    if (_busy || _isFinished) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.finishCardioConfirmTitle),
        content: Text(l10n.finishCardioConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.finishButtonLabel),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _finish();
  }

  Future<void> _finish() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    final total = _liveMovingSeconds;
    final finishedAt = DateTime.now();
    try {
      await ref.read(workoutSessionControllerProvider.notifier).finishCardioSession(
            _clientId,
            startedAt: _startedAt,
            finishedAt: finishedAt,
            movingSeconds: total,
          );
      if (!mounted) return;
      _ticker?.cancel();
      setState(() {
        _movingSeconds = total;
        _movingSinceEpochMs = null;
        _finishedAt = finishedAt;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showError(l10n);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final statusLabel = _isFinished
        ? l10n.cardioSessionFinishedLabel
        : _isRunning
            ? l10n.inProgressLabel
            : l10n.cardioSessionPausedLabel;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(activityTypeLabel(l10n, _activityType)),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ActivityChip(activityType: _activityType, size: 56),
            const SizedBox(height: 16),
            Text(
              statusLabel,
              style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.movingTimeLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              CardioFormatter.duration(Duration(seconds: _liveMovingSeconds)),
              style: theme.textTheme.displayLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 32),
            if (!_isFinished)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isRunning)
                    FilledButton.icon(
                      onPressed: _busy ? null : _pause,
                      icon: const Icon(Icons.pause),
                      label: Text(l10n.pauseButtonLabel),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _busy ? null : _resume,
                      icon: const Icon(Icons.play_arrow),
                      label: Text(l10n.resumeButtonLabel),
                    ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _confirmFinish,
                    icon: const Icon(Icons.check),
                    label: Text(l10n.finishButtonLabel),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
