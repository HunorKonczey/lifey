import 'package:flutter/material.dart';

import '../../../../../core/theme/app_tokens.dart';

/// One headline number about the client (frame C3), optionally with the
/// change since the previous reading.
///
/// A rewrite rather than an extraction: the client-side stat cards are
/// private to their screens and read their own providers, so lifting one out
/// would cost more than these forty lines. The tokens are the shared ones,
/// which is what the plan actually requires (§2.3).
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.delta,
    this.deltaLabel,
    this.lowerIsBetter = false,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  /// Change since the previous reading; null hides the row entirely rather
  /// than showing a zero that means "we don't know".
  final double? delta;
  final String? deltaLabel;

  /// Weight going down is good news; calories going up is not. Only affects
  /// the colour, never the sign shown.
  final bool lowerIsBetter;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final metrics = context.metricColors;

    final delta = this.delta;
    final improving = delta == null || delta == 0
        ? null
        : (lowerIsBetter ? delta < 0 : delta > 0);

    return Material(
      color: scheme.surfaceContainer,
      borderRadius: AppRadius.lgAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              if (delta != null && deltaLabel != null) ...[
                const SizedBox(height: 2),
                Text(
                  deltaLabel!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: improving == null
                        ? scheme.onSurfaceVariant
                        : (improving ? metrics.positive : metrics.negative),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
