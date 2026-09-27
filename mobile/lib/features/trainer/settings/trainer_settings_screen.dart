import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/error_message.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/ds/lifey_header.dart';
import '../../../shared/widgets/ds/list_group.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/trainer_view_menu.dart';
import '../shared/trainer_layout.dart';
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
    final p = context.palette;
    final l10n = AppLocalizations.of(context)!;
    final preferences = ref.watch(trainerPreferencesControllerProvider);

    return Scaffold(
      appBar: LifeySubpageHeader(title: l10n.trainerSettingsTitle),
      body: TrainerContentWidth(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.s16,
            AppSpacing.screen,
            MediaQuery.paddingOf(context).bottom + AppSpacing.s24,
          ),
          children: [
            ListGroup(
              dividerInset: 74,
              children: [
                ListRow(
                  leading: ListIconHolder(icon: Icons.mail_outline_rounded, color: theme.colorScheme.primary),
                  title: l10n.trainerInvitesTitle,
                  subtitle: l10n.trainerInvitesSettingsSubtitle,
                  trailing: Icon(Icons.chevron_right_rounded, color: p.text3),
                  onTap: () => context.push(trainerInvitesLocation),
                ),
                preferences.when(
                  data: (preferences) => ListRow(
                    leading: ListIconHolder(icon: Icons.summarize_outlined, color: theme.colorScheme.primary),
                    title: l10n.trainerWeeklyReportToggleLabel,
                    // Says where the report actually goes. It is an email, and it
                    // stays one — there is no reader for it in the app.
                    subtitle: l10n.trainerWeeklyReportToggleSubtitle,
                    subtitleMaxLines: 4,
                    trailing: Switch(
                      value: preferences.weeklyReportEmailEnabled,
                      onChanged: (enabled) => _setWeeklyReport(context, ref, enabled),
                    ),
                    onTap: () => _setWeeklyReport(context, ref, !preferences.weeklyReportEmailEnabled),
                  ),
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.s24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, _) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
                    child: ErrorView(
                      error: error,
                      onRetry: () => ref.invalidate(trainerPreferencesControllerProvider),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.s4, AppSpacing.s16, AppSpacing.s4, 0),
              child: Text(
                l10n.trainerSettingsFootnote,
                style: theme.textTheme.labelSmall?.copyWith(color: p.text2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setWeeklyReport(BuildContext context, WidgetRef ref, bool enabled) async {
    try {
      await ref.read(trainerPreferencesControllerProvider.notifier).setWeeklyReportEmailEnabled(enabled);
    } catch (error) {
      if (context.mounted) {
        AppSnackbar.showError(context, title: friendlyError(error));
      }
    }
  }
}
