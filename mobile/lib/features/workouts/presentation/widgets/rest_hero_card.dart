import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_type.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ds/metric_bar.dart';

/// Where a rest countdown stands at [now] (docs/redesign/77-mobile-redesign-
/// plan.md R3.4). Pure, so the boundaries — the last five seconds, the tick
/// into overtime — are unit-tested without a widget.
class RestState {
  const RestState({required this.target, required this.elapsed});

  /// [targetSeconds] plus whatever "+15 s" taps were added.
  factory RestState.at({
    required DateTime now,
    required DateTime lastSetAt,
    required int targetSeconds,
    Duration adjustment = Duration.zero,
  }) =>
      RestState(
        target: Duration(seconds: targetSeconds) + adjustment,
        elapsed: now.difference(lastSetAt),
      );

  final Duration target;
  final Duration elapsed;

  /// How long the rest ran past its target; zero until then.
  bool get isOvertime => elapsed >= target;

  /// Time left; zero once [isOvertime].
  Duration get remaining => isOvertime ? Duration.zero : target - elapsed;

  /// How much of the rest is left, 1 → 0 — the bar drains.
  double get remainingFraction =>
      target.inMilliseconds == 0 ? 0 : (remaining.inMilliseconds / target.inMilliseconds).clamp(0.0, 1.0);

  /// The last five seconds: the number changes colour and pulses.
  bool get isFinalSeconds => !isOvertime && remaining <= const Duration(seconds: 5);

  Duration get overage => isOvertime ? elapsed - target : Duration.zero;
}

/// The rest between sets as the hero of the live strength screen: "REST" over
/// the countdown at 44 px, "+15 s" and "Skip", a bar that drains, and what
/// comes next ("Next: Bench Press · set 2 · 47.5 kg × 8") — canvas Lifey 3 ›
/// 3.2 "A pihenő a hős". The last five seconds turn the number into the
/// calorie colour and pulse it (not under reduced motion); past the target it
/// counts up as "+0:12" in the negative colour.
///
/// With the rest timer off ([enabled] false) it is the plain elapsed-since-the-
/// last-set count-up, without buttons — the feature degrades, it never
/// disappears.
class RestHeroCard extends StatelessWidget {
  const RestHeroCard({
    super.key,
    required this.lastSetAt,
    required this.now,
    required this.enabled,
    required this.targetSeconds,
    required this.adjustment,
    required this.onAddFifteen,
    required this.onSkip,
    this.nextLine,
  });

  final DateTime lastSetAt;
  final DateTime now;
  final bool enabled;

  /// The effective rest for the last set's exercise; null while [enabled] is false.
  final int? targetSeconds;

  /// Accumulated "+15 s" taps for the current rest.
  final Duration adjustment;
  final VoidCallback onAddFifteen;
  final VoidCallback onSkip;

  /// "Next: Bench Press · set 2 · 47.5 kg × 8", already localised; null when
  /// nothing is left to do.
  final String? nextLine;

  static String mmss(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = context.palette;
    final mc = context.metricColors;
    final t = Theme.of(context).textTheme;
    final primary = Theme.of(context).colorScheme.primary;

    final rest = enabled && targetSeconds != null
        ? RestState.at(now: now, lastSetAt: lastSetAt, targetSeconds: targetSeconds!, adjustment: adjustment)
        : null;
    final overtime = rest?.isOvertime ?? false;
    final finalSeconds = rest?.isFinalSeconds ?? false;

    final accent = overtime ? mc.negative : primary;
    final numberColor = overtime
        ? mc.negative
        : finalSeconds
            ? mc.calories
            : p.text;
    final text = rest == null
        ? mmss(now.difference(lastSetAt))
        : overtime
            ? '+${mmss(rest.overage)}'
            : mmss(rest.remaining);

    // One pulse per second in the last five: up on odd seconds, back on even.
    final pulse = finalSeconds && rest!.remaining.inSeconds.isOdd;
    final motion = AppMotion.of(context, const Duration(milliseconds: 300));

    return Semantics(
      container: true,
      liveRegion: false,
      label: '${l10n.restLabel} $text',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          color: p.nested,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: accent.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.restLabel.toUpperCase(), style: AppType.sectionLabel(color: accent)),
                      const SizedBox(height: 2),
                      AnimatedScale(
                        scale: pulse ? 1.06 : 1,
                        alignment: Alignment.centerLeft,
                        duration: motion,
                        curve: Curves.easeOut,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            text,
                            maxLines: 1,
                            style: TextStyle(
                              fontFamily: AppType.fontFamily,
                              fontSize: 44,
                              height: 1.05,
                              letterSpacing: -0.02 * 44,
                              fontWeight: FontWeight.w800,
                              color: numberColor,
                              fontFeatures: AppType.tabular,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (rest != null) ...[
                  const SizedBox(width: AppSpacing.s8),
                  // The two buttons never take more than 55 % of the card: at
                  // large text in Hungarian ("Kihagyás") they scale down a
                  // little instead of pushing the number out.
                  Flexible(
                    flex: 0,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.55),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!overtime) ...[
                              _RestButton(
                                label: l10n.restTimerAddSecondsButton,
                                background: p.control,
                                foreground: p.text,
                                onTap: onAddFifteen,
                              ),
                              const SizedBox(width: AppSpacing.s8),
                            ],
                            _RestButton(
                              label: l10n.restSkipLabel,
                              tooltip: l10n.restTimerSkipButton,
                              background: accent,
                              foreground: overtime ? p.card : Theme.of(context).colorScheme.onPrimary,
                              onTap: onSkip,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (rest != null) ...[
              const SizedBox(height: AppSpacing.s12),
              MetricBar(progress: overtime ? 0 : rest.remainingFraction, color: overtime ? mc.negative : primary, height: 8),
            ],
            if (nextLine != null) ...[
              const SizedBox(height: AppSpacing.s12),
              Text(nextLine!, style: t.bodyMedium!.copyWith(fontSize: 14, height: 1.3, color: p.text2)),
            ],
          ],
        ),
      ),
    );
  }
}

/// "+15 s" / "Skip": a 48 dp-tall pill button.
class _RestButton extends StatelessWidget {
  const _RestButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.tooltip,
  });

  final String label;
  final String? tooltip;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.control);
    final button = Material(
      color: background,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                style: Theme.of(context).textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w800, color: foreground),
              ),
            ),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
