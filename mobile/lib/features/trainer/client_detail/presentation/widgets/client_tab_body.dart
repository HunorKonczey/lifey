import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../../shared/widgets/empty_view.dart';
import '../../../../../shared/widgets/error_view.dart';

/// The four states every client detail tab has to have (§2.2: skeleton /
/// empty / error / offline), in one place so the five tabs agree on them.
///
/// A tab usually reads two or three endpoints; this waits for all of them,
/// surfaces the first failure, and refreshes them together — the web page
/// does exactly the same thing with its `isLoading || isError` chains.
class ClientTabBody extends StatelessWidget {
  const ClientTabBody({
    super.key,
    required this.states,
    required this.onRefresh,
    required this.builder,
    this.offline = false,
  });

  final List<AsyncValue<Object?>> states;
  final Future<void> Function() onRefresh;
  final WidgetBuilder builder;

  /// When the device is offline *and* nothing has loaded, the tab says so
  /// instead of showing a network error — the trainer view has no local copy
  /// to fall back on, so this is the honest message.
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasEverything = states.every((state) => state.hasValue);
    final error = states.where((state) => state.hasError).firstOrNull;

    Widget child;
    if (offline && !hasEverything) {
      child = EmptyView(
        icon: Icons.cloud_off,
        title: l10n.trainerOfflineTitle,
        subtitle: l10n.trainerOfflineMessage,
        action: FilledButton.tonal(
          onPressed: onRefresh,
          child: Text(l10n.retryButton),
        ),
      );
    } else if (error != null && !hasEverything) {
      child = ErrorView(error: error.error!, onRetry: onRefresh);
    } else if (!hasEverything) {
      child = const Center(child: CircularProgressIndicator());
    } else {
      child = builder(context);
    }

    return RefreshIndicator(onRefresh: onRefresh, child: child);
  }
}
