import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/error_message.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/trainer_view_menu.dart';
import 'trainer_preferences.dart';

/// The trainer view's own settings (T7).
///
/// Kept apart from the client-side Settings screen, which is about the user's
/// own app: this is about being someone's coach. Today it holds one switch and
/// the way to the invites screen — small, but it is the whole of what a
/// trainer can configure.
class TrainerSettingsScreen extends ConsumerWidget {
  const TrainerSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final preferences = ref.watch(trainerPreferencesControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.trainerSettingsTitle)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: Text(l10n.trainerInvitesTitle),
            subtitle: Text(l10n.trainerInvitesSettingsSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(trainerInvitesLocation),
          ),
          const Divider(height: 1),
          preferences.when(
            data: (preferences) => SwitchListTile(
              secondary: const Icon(Icons.summarize_outlined),
              title: Text(l10n.trainerWeeklyReportToggleLabel),
              // Says where the report actually goes. It is an email, and it
              // stays one — there is no reader for it in the app.
              subtitle: Text(l10n.trainerWeeklyReportToggleSubtitle),
              value: preferences.weeklyReportEmailEnabled,
              onChanged: (enabled) async {
                try {
                  await ref
                      .read(trainerPreferencesControllerProvider.notifier)
                      .setWeeklyReportEmailEnabled(enabled);
                } catch (error) {
                  if (context.mounted) {
                    AppSnackbar.showError(context, title: friendlyError(error));
                  }
                }
              },
            ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: ErrorView(
                error: error,
                onRetry: () => ref.invalidate(trainerPreferencesControllerProvider),
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Text(
              l10n.trainerSettingsFootnote,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
