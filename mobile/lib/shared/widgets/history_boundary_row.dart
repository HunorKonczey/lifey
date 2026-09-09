import 'package:flutter/material.dart';

import '../../core/entitlements/paywall_navigation.dart';
import '../../core/entitlements/paywall_trigger.dart';
import '../../core/theme/app_tokens.dart';
import '../../l10n/app_localizations.dart';

/// Marks where a history list crosses the free-tier cutoff (D-P6) — the list
/// ends here, nothing is hidden behind a fade or a blurred teaser (`69` §4.2,
/// D-DM1). Tapping opens the paywall with the `historyRange` trigger.
class HistoryBoundaryRow extends StatelessWidget {
  const HistoryBoundaryRow({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openPaywall(context, PaywallTrigger.historyRange),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.history, size: 20, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.historyBoundaryRowMessage,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, size: 20, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
