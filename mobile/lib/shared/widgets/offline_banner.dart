import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/connectivity_status_provider.dart';

/// Thin, unobtrusive strip shown above every screen while the device has no
/// connectivity at all. Collapses to nothing the moment connectivity
/// returns — local writes keep working either way, this is purely
/// informational (doc section 8: "visible but unobtrusive").
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(isOfflineProvider).value ?? false;
    final theme = Theme.of(context);

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: isOffline
          ? SafeArea(
              bottom: false,
              child: Material(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off, size: 16, color: theme.colorScheme.onErrorContainer),
                      const SizedBox(width: 8),
                      Text(
                        "Offline — changes will sync once you're back online",
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onErrorContainer),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : const SizedBox(width: double.infinity),
    );
  }
}
