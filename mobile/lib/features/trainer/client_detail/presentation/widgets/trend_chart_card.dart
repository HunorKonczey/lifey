import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_tokens.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../shared/widgets/charts/time_series_chart.dart';

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
  });

  final String title;
  final List<({DateTime date, double value})> points;
  final Color accentColor;

  /// Shown when there are no readings at all.
  final String emptyMessage;

  final String Function(double value)? valueLabelBuilder;
  final double? goalValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: AppRadius.lgAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
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
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
