import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import 'exercise_session_card.dart';

// ---------------------------------------------------------------------------
// Progress computation — pure, no widget dependencies.
// ---------------------------------------------------------------------------

/// Per-exercise improvement chips (e.g. "+2.5 kg", "+2 reps") for the
/// workout-success dialog. Only exercises with at least one positive gain
/// are included.
class WorkoutImprovement {
  const WorkoutImprovement({required this.exerciseName, required this.chips});

  final String exerciseName;
  final List<String> chips;
}

class WorkoutProgressResult {
  const WorkoutProgressResult({required this.score, required this.improvements});

  /// Net count of green up-arrows minus red down-arrows across every done
  /// set's weight and reps comparisons (mirrors [ExerciseSetRowTile]'s
  /// arrow logic in exercise_session_card.dart).
  final int score;
  final List<WorkoutImprovement> improvements;

  /// Popup only shows when the user improved in at least 2 metrics net.
  bool get isSuccess => score >= 2;
}

/// Computes the workout-success trigger score and per-exercise improvement
/// chips from the session's blocks, comparing each done row positionally
/// against [ExerciseBlock.previousSets].
WorkoutProgressResult computeWorkoutProgress(
  List<ExerciseBlock> blocks,
  AppLocalizations l10n,
) {
  final weightFormat = NumberFormat('0.#', l10n.localeName);
  int score = 0;
  final improvements = <WorkoutImprovement>[];

  for (final block in blocks) {
    double weightGain = 0;
    int repsGain = 0;
    for (var i = 0; i < block.rows.length; i++) {
      final row = block.rows[i];
      if (!row.isDone) continue;
      if (i >= block.previousSets.length) continue;
      final previous = block.previousSets[i];

      if (row.weight != null) {
        if (row.weight! > previous.weight) {
          score++;
          weightGain += row.weight! - previous.weight;
        } else if (row.weight! < previous.weight) {
          score--;
        }
      }
      if (row.reps != null) {
        if (row.reps! > previous.reps) {
          score++;
          repsGain += row.reps! - previous.reps;
        } else if (row.reps! < previous.reps) {
          score--;
        }
      }
    }

    final chips = <String>[];
    if (weightGain > 0) {
      chips.add('+${weightFormat.format(weightGain)} ${l10n.statUnitKg}');
    }
    if (repsGain > 0) {
      chips.add('+$repsGain ${l10n.workoutSuccessRepsAbbrev}');
    }
    if (chips.isNotEmpty) {
      improvements.add(
        WorkoutImprovement(exerciseName: block.exerciseName, chips: chips),
      );
    }
  }

  return WorkoutProgressResult(score: score, improvements: improvements);
}

// ---------------------------------------------------------------------------
// Confetti burst — 12-particle one-shot animation, matches the design's
// motion spec (entrance-only, ~650ms travel with 0-240ms staggered delay).
// ---------------------------------------------------------------------------

class _ConfettiPiece {
  const _ConfettiPiece(
    this.angleDeg,
    this.distance,
    this.size,
    this.shape,
    this.colorIndex,
    this.delay,
  );

  final double angleDeg;
  final double distance;
  final double size;

  /// 0 = dot, 1 = square, 2 = strip.
  final int shape;
  final int colorIndex;

  /// Seconds, matching the design's stagger spec.
  final double delay;
}

const List<_ConfettiPiece> _kConfettiPieces = [
  _ConfettiPiece(-90, 96, 9, 0, 0, 0.00),
  _ConfettiPiece(-55, 110, 7, 1, 1, 0.05),
  _ConfettiPiece(-120, 104, 8, 1, 2, 0.08),
  _ConfettiPiece(-20, 88, 6, 0, 3, 0.12),
  _ConfettiPiece(-160, 92, 7, 0, 1, 0.10),
  _ConfettiPiece(15, 76, 8, 2, 0, 0.16),
  _ConfettiPiece(165, 80, 6, 2, 1, 0.14),
  _ConfettiPiece(-75, 128, 6, 2, 3, 0.04),
  _ConfettiPiece(-105, 122, 6, 0, 1, 0.18),
  _ConfettiPiece(40, 66, 7, 1, 2, 0.20),
  _ConfettiPiece(140, 70, 7, 1, 0, 0.22),
  _ConfettiPiece(-40, 118, 5, 0, 0, 0.24),
];

const Duration _kConfettiBurstDuration = Duration(milliseconds: 650);
const double _kConfettiMaxDelaySeconds = 0.24;

class _ConfettiBurst extends StatelessWidget {
  const _ConfettiBurst({
    required this.progress,
    required this.colors,
    required this.reduceMotion,
  });

  /// 0..1 across [_kConfettiBurstDuration] + max delay.
  final double progress;
  final List<Color> colors;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final totalMs =
        _kConfettiBurstDuration.inMilliseconds + _kConfettiMaxDelaySeconds * 1000;

    return IgnorePointer(
      child: Stack(
        children: [
          for (final p in _kConfettiPieces)
            _buildPiece(p, totalMs, colors[p.colorIndex % colors.length]),
        ],
      ),
    );
  }

  Widget _buildPiece(_ConfettiPiece p, double totalMs, Color color) {
    final rad = p.angleDeg * math.pi / 180;
    final fullDx = math.cos(rad) * p.distance;
    final fullDy = math.sin(rad) * p.distance;
    final width = p.shape == 2 ? p.size * 0.5 : p.size;
    final height = p.shape == 2 ? p.size * 1.9 : p.size;
    final borderRadius = p.shape == 0 ? width / 2 : 2.0;

    double dx, dy, opacity, scale, rotationDeg;
    if (reduceMotion) {
      dx = fullDx * 0.62;
      dy = fullDy * 0.62;
      opacity = 0.9;
      scale = 1;
      rotationDeg = p.angleDeg * 2;
    } else {
      final delayFrac = (p.delay * 1000) / totalMs;
      final local = ((progress - delayFrac) / (1 - delayFrac)).clamp(0.0, 1.0);
      final eased = Curves.easeOut.transform(local);
      dx = fullDx * eased;
      dy = fullDy * eased;
      scale = 0.4 + 0.6 * Curves.easeOut.transform((local * 3.0).clamp(0.0, 1.0));
      rotationDeg = p.angleDeg * 3 * eased;
      opacity = local <= 0
          ? 0
          : local < 0.11
              ? local / 0.11
              : (1 - (local - 0.11) / 0.89).clamp(0.0, 1.0);
    }

    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      bottom: 0,
      child: Center(
        child: Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.rotate(
            angle: rotationDeg * math.pi / 180,
            child: Opacity(
              opacity: opacity,
              child: Container(
                width: width * scale,
                height: height * scale,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(borderRadius * scale),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// WorkoutSuccessDialog
// ---------------------------------------------------------------------------

/// Celebration dialog shown when [WorkoutProgressResult.isSuccess] — the
/// user improved in at least 2 metrics (weight/reps, net of regressions)
/// versus their previous session. See "Lifey Workout Success.dc.html".
class WorkoutSuccessDialog extends StatefulWidget {
  const WorkoutSuccessDialog({super.key, required this.result});

  final WorkoutProgressResult result;

  @override
  State<WorkoutSuccessDialog> createState() => _WorkoutSuccessDialogState();
}

class _WorkoutSuccessDialogState extends State<WorkoutSuccessDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _entrance;

  static const _maxRows = 5;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _entrance = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.28, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final dialogBg = isDark ? const Color(0xFF22241B) : const Color(0xFFFFFFFF);
    final iconColor = isDark ? const Color(0xFF9DAE6B) : const Color(0xFF586E38);
    final titleColor = isDark ? const Color(0xFFF1F0E4) : const Color(0xFF1C1D18);
    final subtitleColor = isDark ? const Color(0xFFA8A899) : const Color(0xFF6A6A60);
    final rowBg = isDark ? const Color(0xFF161611) : const Color(0xFFECEBDE);
    final moreColor = isDark ? const Color(0xFF777264) : const Color(0xFF8A8A7E);
    final chipBg = isDark
        ? const Color(0xFF4CAF50).withValues(alpha: 0.15)
        : const Color(0xFF4CAF50).withValues(alpha: 0.16);
    final chipText = isDark ? const Color(0xFF4CAF50) : const Color(0xFF388E3C);
    final buttonBg = isDark ? const Color(0xFF9DAE6B) : const Color(0xFF586E38);
    final buttonText = isDark ? const Color(0xFF1E1F18) : const Color(0xFFFFFFFF);
    final confettiColors = isDark
        ? const [
            Color(0xFF9DAE6B),
            Color(0xFF4CAF50),
            Color(0xFFC49A6C),
            Color(0xFFD8B35A),
          ]
        : const [
            Color(0xFF586E38),
            Color(0xFF4CAF50),
            Color(0xFF8A6A42),
            Color(0xFFB8933A),
          ];

    final rows = widget.result.improvements.take(_maxRows).toList();
    final remaining = widget.result.improvements.length - rows.length;

    final Widget dialogChild = Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 116,
              height: 116,
              child: Stack(
                children: [
                  // Positioned.fill forces both children to the full 116×116
                  // box — without it, a Stack with no sized non-positioned
                  // child shrinks to zero, which threw the icon to the
                  // top-left and the confetti's "center" off with it.
                  Positioned.fill(
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: iconColor.withValues(alpha: isDark ? 0.16 : 0.12),
                      ),
                      child: Icon(Icons.celebration_rounded, size: 54, color: iconColor),
                    ),
                  ),
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) => _ConfettiBurst(
                        progress: reduceMotion ? 1 : _controller.value,
                        colors: confettiColors,
                        reduceMotion: reduceMotion,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.workoutSuccessTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: titleColor,
                letterSpacing: -0.3,
                fontFamily: 'PlusJakartaSans',
              ),
            ),
            const SizedBox(height: 7),
            Text(
              l10n.workoutSuccessSubtitle(widget.result.improvements.length),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: subtitleColor,
                height: 1.5,
                fontFamily: 'PlusJakartaSans',
              ),
            ),
            const SizedBox(height: 20),
            Column(
              children: [
                for (final row in rows) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                    decoration: BoxDecoration(
                      color: rowBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            row.exerciseName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: titleColor,
                              fontFamily: 'PlusJakartaSans',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        for (final chip in row.chips) ...[
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: chipBg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.arrow_upward, size: 14, color: chipText),
                                const SizedBox(width: 3),
                                Text(
                                  chip,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: chipText,
                                    fontFamily: 'PlusJakartaSans',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
            if (remaining > 0) ...[
              Text(
                l10n.workoutSuccessMoreCount(remaining),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: moreColor,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(height: 18),
            ] else
              const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: buttonBg,
                  foregroundColor: buttonText,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                  textStyle: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: Text(l10n.workoutSuccessContinueButton),
              ),
            ),
          ],
        ),
      ),
    );

    if (reduceMotion) return dialogChild;

    return AnimatedBuilder(
      animation: _entrance,
      builder: (context, child) => Opacity(
        opacity: _entrance.value,
        child: Transform.scale(
          scale: 0.9 + 0.1 * _entrance.value,
          child: child,
        ),
      ),
      child: dialogChild,
    );
  }
}

/// Shows [WorkoutSuccessDialog] if [result] is a success; no-op otherwise.
/// Awaits the dialog's dismissal so callers can navigate away afterward.
Future<void> showWorkoutSuccessDialog(
  BuildContext context,
  WorkoutProgressResult result,
) async {
  if (!result.isSuccess) return;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  await showDialog<void>(
    context: context,
    barrierColor: isDark ? const Color(0xB8080906) : const Color(0x731C1D18),
    builder: (_) => WorkoutSuccessDialog(result: result),
  );
}
