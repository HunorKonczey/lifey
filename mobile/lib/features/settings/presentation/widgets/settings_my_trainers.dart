import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/error_message.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/confirm_delete_dialog.dart';
import '../../../../shared/widgets/ds/list_group.dart';
import '../../../../shared/widgets/ds/section_label.dart';
import '../../../chat/data/chat_repository.dart';
import '../../../my_trainers/application/my_trainers_controller.dart';
import '../../../my_trainers/domain/my_trainer.dart';
import 'settings_kit.dart';

/// Settings › "My trainers" (docs/personal_trainer/05-mobil-terv.md §3). Hidden
/// entirely — not just empty-stated — when the user has no active trainer.
class MyTrainersSection extends ConsumerWidget {
  const MyTrainersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trainers = ref.watch(myTrainersControllerProvider).value ?? const [];
    if (trainers.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final p = context.palette;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s24),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l10n.myTrainersSectionLabel),
        const SizedBox(height: AppSpacing.s8),
        ListGroup(children: [for (final t in trainers) _MyTrainerRow(trainer: t)]),
        const SizedBox(height: AppSpacing.s8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
          child: Text(l10n.myTrainersDataSharingExplanation, style: Theme.of(context).textTheme.bodySmall!.copyWith(color: p.text2)),
        ),
      ],
    ),
    );
  }
}

class _MyTrainerRow extends ConsumerWidget {
  const _MyTrainerRow({required this.trainer});

  final MyTrainer trainer;

  /// Secondary chat entry point for the client side: the trainer they already
  /// know about is right here, so the thread is one tap away without going
  /// through the conversation list (docs/chat/40-trainer-chat-plan.md §6.1).
  /// The thread is lazy-created server-side, so this works even before either
  /// of them has written anything.
  Future<void> _message(BuildContext context, WidgetRef ref) async {
    try {
      final conversationId = await ref.read(chatRepositoryProvider).openConversationWith(trainer.trainerId);
      if (context.mounted) context.push('/chat/$conversationId');
    } catch (e) {
      if (context.mounted) AppSnackbar.showError(context, title: friendlyError(e));
    }
  }

  Future<void> _leave(BuildContext context, WidgetRef ref, AppLocalizations l10n) async {
    final confirmed = await showConfirmDeleteDialog(
      context,
      title: l10n.myTrainersLeaveConfirmTitle,
      message: l10n.myTrainersLeaveConfirmMessage(trainer.trainerEmail),
    );
    if (!confirmed) return;
    try {
      await ref.read(myTrainersControllerProvider.notifier).leave(trainer.trainerId);
    } catch (e) {
      if (context.mounted) AppSnackbar.showError(context, title: friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final dateFmt = DateFormat.yMMMd(Localizations.localeOf(context).languageCode);

    return SettingsRow(
      icon: Icons.fitness_center_rounded,
      title: trainer.displayName,
      subtitle: l10n.myTrainersActiveSinceLabel(dateFmt.format(trainer.activeSince)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => _message(context, ref),
            tooltip: l10n.chatMessageAction,
            icon: Icon(Icons.chat_bubble_outline_rounded, size: 22, color: scheme.primary),
          ),
          TextButton(
            onPressed: () => _leave(context, ref, l10n),
            style: TextButton.styleFrom(foregroundColor: context.metricColors.heart, padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8)),
            child: Text(l10n.myTrainersLeaveAction),
          ),
        ],
      ),
    );
  }
}
