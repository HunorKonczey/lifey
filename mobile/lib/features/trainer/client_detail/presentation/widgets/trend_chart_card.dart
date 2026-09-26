import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_tokens.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../shared/widgets/charts/time_series_chart.dart';
import '../../../../../shared/widgets/ds/lifey_card.dart';

/// A titled card wrapping the shared [TimeSeriesChart].
///
/// The chart itself needed no changes for the trainer view — it already takes
/// its points and its formatters as parameters rather than reading a
/// provider, which is exactly the "adatforrás-független" state §2.3 asks for.
///
/// What this card adds is the honest handling of thin data (frame C4): with
/// fewer than two readings there is no trend, and drawing a line through one
/// point would be a claim the data does not support — so it says how many
/// readings there are instead.
class TrendChartCard extends StatelessWidget {
  const TrendChartCard({
    super.key,
    required this.title,
    required this.points,
    required this.accentColor,
    required this.emptyMessage,
    this.valueLabelBuilder,
    this.goalValue,
    this.subtitle,
    this.trailing,
    this.chartHeight = 220,
    this.onTap,
  });

  final String title;
  final List<({DateTime date, double value})> points;
  final Color accentColor;

  /// Shown when there are no readings at all.
  final String emptyMessage;

  final String Function(double value)? valueLabelBuilder;
  final double? goalValue;

  /// A line under the title — "Latest: 71.4 kg · Sep 24".
  final String? subtitle;

  /// Sits at the title's right edge — the change chip ("−1.4 kg · 30 d").
  final Widget? trailing;

  final double chartHeight;

  /// Makes the whole card a door to the tab that explains it.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final dateFormat =
        DateFormat.MMMd(Localizations.localeOf(context).toString());

    Widget body;
    if (points.isEmpty) {
      body = _Note(text: emptyMessage);
    } else if (points.length < 2) {
      body = _Note(text: l10n.trainerNotEnoughDataForTrendMessage);
    } else {
      body = TimeSeriesChart(
        points: [
          for (final point in points)
            TimeSeriesPoint(date: point.date, value: point.value),
        ],
        dateLabelBuilder: (date) => dateFormat.format(date.toLocal()),
        valueLabelBuilder: valueLabelBuilder,
        accentColor: accentColor,
        goalValue: goalValue,
        height: chartHeight,
        // The v2 chart: a soft fill under one line, the latest reading marked.
        gradientFill: true,
        showPoints: false,
        highlightLast: true,
      );
    }

    return LifeyCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: AppSpacing.s8), trailing!],
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.s4),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(color: context.palette.text2),
            ),
          ],
          const SizedBox(height: AppSpacing.s12),
          body,
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 120,
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: context.palette.text2),
        ),
      ),
    );
  }
}
