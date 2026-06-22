import 'package:flutter/material.dart';

import '../../core/network/error_message.dart';
import '../../l10n/app_localizations.dart';
import 'scroll_fill.dart';

/// Polished error-state placeholder with a friendly message and optional retry.
/// Scrollable so it works inside a [RefreshIndicator].
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return ScrollFill(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(l10n.somethingWentWrongTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            friendlyError(error),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: onRetry, child: Text(l10n.retryButton)),
          ],
        ],
      ),
    );
  }
}
